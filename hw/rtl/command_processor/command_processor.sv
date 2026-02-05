module command_processor (
    input  logic        clk,
    input  logic        rst_n,

    // Command FIFO interface
    input  logic        cmd_valid,
    input  logic [31:0] cmd_data,
    output logic        cmd_ready,

    // Action block interfaces
    output logic        clear_start,
    output logic        raster_start,    
    output logic        simd_start,
    input  logic        simd_done
);

    // ------------------------------------------------
    // FSM
    // ------------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_READ_PAYLOAD,
        ST_EXECUTE
    } fsm_state_t;

    fsm_state_t state, next_state;

    // ------------------------------------------------
    // Command registers
    // ------------------------------------------------
    logic [7:0]  opcode;
    logic [15:0] payload_length;
    logic [15:0] payload_count;
    logic [31:0] payload_buf [0:5];

    // ------------------------------------------------
    // Graphics state
    // ------------------------------------------------
    logic [31:0] current_color;
    logic [31:0] viewport_xmin, viewport_ymin;
    logic [31:0] viewport_xmax, viewport_ymax;

    logic set_color_we;
    logic set_viewport_we;

    // ------------------------------------------------
    // EXECUTE entry detection
    // ------------------------------------------------
    logic exec_active_d;

    // ------------------------------------------------
    // Clear unit
    // ------------------------------------------------
    logic clear_done_int;
    logic clear_pixel_valid;
    logic [31:0] clear_pixel_x;
    logic [31:0] clear_pixel_y;
    logic [31:0] clear_pixel_color;

    clear_unit clear_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(clear_start),
        .done(clear_done_int),

        .color(current_color),
        .xmin(viewport_xmin),
        .ymin(viewport_ymin),
        .xmax(viewport_xmax),
        .ymax(viewport_ymax),

        .pixel_valid(clear_pixel_valid),
        .pixel_x(clear_pixel_x),
        .pixel_y(clear_pixel_y),
        .pixel_color(clear_pixel_color)
    );

    // ------------------------------------------------
    // Rasterizer
    // ------------------------------------------------
    logic raster_done_int;
    logic raster_pixel_valid;
    logic [31:0] raster_pixel_x;
    logic [31:0] raster_pixel_y;
    logic [31:0] raster_pixel_color;

    rasterizer raster_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(raster_start),
        .done(raster_done_int),

        .x0(payload_buf[0]),
        .y0(payload_buf[1]),
        .x1(payload_buf[2]),
        .y1(payload_buf[3]),
        .x2(payload_buf[4]),
        .y2(payload_buf[5]),

        .color(current_color),
        .viewport_xmin(viewport_xmin),
        .viewport_ymin(viewport_ymin),
        .viewport_xmax(viewport_xmax),
        .viewport_ymax(viewport_ymax),

        .pixel_valid(raster_pixel_valid),
        .pixel_x(raster_pixel_x),
        .pixel_y(raster_pixel_y),
        .pixel_color(raster_pixel_color)
    );

    // ------------------------------------------------
    // Pixel arbiter
    // ------------------------------------------------
    logic arbiter_pixel_valid;
    logic [31:0] arbiter_pixel_x;
    logic [31:0] arbiter_pixel_y;
    logic [31:0] arbiter_pixel_color;

    pixel_arbiter arb (
        // CLEAR source
        .clear_valid (clear_pixel_valid),
        .clear_x     (clear_pixel_x),
        .clear_y     (clear_pixel_y),
        .clear_color (clear_pixel_color),

        // RASTER source
        .raster_valid (raster_pixel_valid),
        .raster_x     (raster_pixel_x),
        .raster_y     (raster_pixel_y),
        .raster_color (raster_pixel_color),

        // SIMD source (stub)
        .simd_valid (1'b0),
        .simd_x     (32'd0),
        .simd_y     (32'd0),
        .simd_color (32'd0),

        // Unified output
        .pixel_valid (arbiter_pixel_valid),
        .pixel_x     (arbiter_pixel_x),
        .pixel_y     (arbiter_pixel_y),
        .pixel_color (arbiter_pixel_color)
    );

    // ------------------------------------------------
    // Sequential logic
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            exec_active_d <= 1'b0;

            opcode <= 8'h00;
            payload_length <= 16'd0;
            payload_count <= 16'd0;

            current_color <= 32'd0;
            viewport_xmin <= 32'd0;
            viewport_ymin <= 32'd0;
            viewport_xmax <= 32'd0;
            viewport_ymax <= 32'd0;

            clear_start <= 1'b0;
            raster_start <= 1'b0;
        end else begin
            exec_active_d <= (state == ST_EXECUTE);
            state <= next_state;

            clear_start <= 1'b0;
            raster_start <= 1'b0;

            // Capture header (IDLE only)
            if (state == ST_IDLE && cmd_valid && cmd_ready) begin
                $display("%0t HEADER %h len=%0d", $time, cmd_data, cmd_data[15:0]);
                opcode         <= cmd_data[31:24];
                payload_length <= cmd_data[15:0];
                payload_count  <= 16'd0;
            end

            // Capture payload words
            if (state == ST_READ_PAYLOAD && cmd_valid && cmd_ready && payload_count < payload_length) begin
                payload_buf[payload_count] <= cmd_data;
                payload_count <= payload_count + 1;
            end

            // Apply state updates
            if (set_color_we)
                current_color <= payload_buf[0];

            if (set_viewport_we) begin
                viewport_xmin <= payload_buf[0];
                viewport_ymin <= payload_buf[1];
                viewport_xmax <= payload_buf[2];
                viewport_ymax <= payload_buf[3];
            end

            // Pulse CLEAR start on entry to EXECUTE
            if (state == ST_EXECUTE && !exec_active_d && opcode == 8'h01)
                clear_start <= 1'b1;

            // Pulse RASTER start on entry to EXECUTE
            if (state == ST_EXECUTE && !exec_active_d && opcode == 8'h02)
                raster_start <= 1'b1;
        end
    end

    // ------------------------------------------------
    // Assertions (simulation only)
    // ------------------------------------------------
    `ifndef SYNTHESIS

        // A command word may only be accepted in IDLE or READ_PAYLOAD
        always_ff @(posedge clk) begin
            if (rst_n && cmd_valid && cmd_ready) begin
                assert (state == ST_IDLE || state == ST_READ_PAYLOAD)
                    else $fatal("Command accepted in illegal state %0d", state);
            end
        end

        // No command word may be accepted during EXECUTE
        always_ff @(posedge clk) begin
            if (rst_n && state == ST_EXECUTE) begin
                assert (!(cmd_valid && cmd_ready))
                    else $fatal("Command accepted during EXECUTE");
            end
        end

        // Payload count must never exceed payload length
        always_ff @(posedge clk) begin
            if (rst_n) begin
                assert (payload_count <= payload_length)
                    else $fatal("payload_count exceeded payload_length");
            end
        end

        // Zero-length payload commands must never enter READ_PAYLOAD
        always_comb begin
            if (state == ST_READ_PAYLOAD) begin
                assert (payload_length != 16'd0)
                    else $fatal("Entered ST_READ_PAYLOAD with payload_length == 0");
            end
        end

    `endif

    // ------------------------------------------------
    // Combinational FSM
    // ------------------------------------------------
    always_comb begin
        next_state = state;

        // Phase-accurate ready/valid
        cmd_ready = 1'b0;

        simd_start      = 1'b0;
        set_color_we    = 1'b0;
        set_viewport_we = 1'b0;

        case (state)
            ST_IDLE: begin
                cmd_ready = 1'b1;
                if (cmd_valid) begin
                    if (cmd_data[15:0] == 16'd0)
                        next_state = ST_EXECUTE;
                    else
                        next_state = ST_READ_PAYLOAD;
                end
            end

            ST_READ_PAYLOAD: begin
                cmd_ready = (payload_count < payload_length);
                if (payload_count >= payload_length)
                    next_state = ST_EXECUTE;
            end

            ST_EXECUTE: begin
                case (opcode)
                    8'h01: begin
                        if (clear_done_int)
                            next_state = ST_IDLE;
                    end

                    8'h02: begin
                        if (raster_done_int)
                            next_state = ST_IDLE;
                    end

                    8'h03: begin
                        simd_start = 1'b1;
                        if (simd_done)
                            next_state = ST_IDLE;
                    end

                    8'h10: begin
                        set_color_we = 1'b1;
                        next_state = ST_IDLE;
                    end

                    8'h11: begin
                        set_viewport_we = 1'b1;
                        next_state = ST_IDLE;
                    end

                    default: next_state = ST_IDLE;
                endcase
            end
        endcase
    end

endmodule