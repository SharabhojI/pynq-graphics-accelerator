module command_processor (
    input  logic        clk,
    input  logic        rst_n, // active low reset signal

    // conceptual command FIFO interface
    input  logic        cmd_valid,
    input  logic [31:0] cmd_data,
    output logic        cmd_ready,

    // conceptual action block interfaces
    output logic        clear_start,
    input  logic        clear_done,

    output logic        raster_start,
    input  logic        raster_done,
    
    output logic        simd_start,
    input  logic        simd_done
);
    // ------------------------------------------------
    // FSM State Definition
    // ------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_READ_HEADER,
        ST_READ_PAYLOAD,
        ST_EXECUTE
    } fsm_state_t;

    fsm_state_t state, next_state; 

    // Write enable signals
    logic set_color_we;
    logic set_viewport_we;

    // ------------------------------------------------
    // Registers
    // ------------------------------------------------
    logic [7:0] opcode;
    logic [15:0] payload_length;
    logic [15:0] payload_count;
    logic [31:0] draw_payload [0:5]; // buffer for DRAW_TRIANGLE payload

    // ------------------------------------------------
    // Graphics state registers
    // ------------------------------------------------
    logic [31:0] current_color;
    logic [31:0] viewport_xmin, viewport_ymin;
    logic [31:0] viewport_xmax, viewport_ymax;

    // ------------------------------------------------
    // State Register
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin // flip-flop
        if (!rst_n) begin // if low reset
            state <= ST_IDLE; // reset to initial/idle state
            opcode <= 8'h00;
            payload_length <= 16'd0;
            payload_count <= 16'd0;

            // reset graphics state
            current_color <= 32'h00000000; // default black
            viewport_xmin <= 32'd0;
            viewport_ymin <= 32'd0;
            viewport_xmax <= 32'd0;
            viewport_ymax <= 32'd0;
        end else begin
            state <= next_state; // advance to next state

            // header capture logic
            if (state == ST_IDLE && cmd_valid && cmd_ready) begin
                opcode <= cmd_data[31:24];
                payload_length <= cmd_data[15:0];
                payload_count <= 16'd0;
            end

            // payload capture logic
            if (state == ST_READ_PAYLOAD && cmd_valid && cmd_ready) begin
                if (opcode == 8'h02) begin // DRAW_TRIANGLE
                    draw_payload[payload_count] <= cmd_data;
                end
                payload_count <= payload_count + 1;
            end

            // set color update
            if (set_color_we) begin
                current_color <= draw_payload[0];
            end
            
            // set viewport update
            if (set_viewport_we) begin
                viewport_xmin <= draw_payload[0];
                viewport_ymin <= draw_payload[1];
                viewport_xmax <= draw_payload[2];
                viewport_ymax <= draw_payload[3];
            end
        end
    end

    // ------------------------------------------------
    // FSM Next State Logic
    // ------------------------------------------------
    always_comb begin // combinational
        // default assignments
        next_state = state;
        cmd_ready = 1'b0;

        clear_start = 1'b0;
        raster_start = 1'b0;
        simd_start = 1'b0;

        set_color_we = 1'b0;
        set_viewport_we = 1'b0;

        // switch case for state
        case (state)
            ST_IDLE: begin
                if (cmd_valid) begin
                    cmd_ready = 1'b1;
                    next_state = ST_READ_HEADER;
                end
            end
            
            ST_READ_HEADER: begin
                cmd_ready = 1'b1;
                next_state = ST_READ_PAYLOAD;
            end

            ST_READ_PAYLOAD: begin
                cmd_ready = 1'b1;

                // zero-length payloads skip immediately
                if (payload_length == 0) begin
                    next_state = ST_EXECUTE;
                end
                // advance when last payload word is accepted
                else if (cmd_valid && (payload_count + 1 == payload_length)) begin
                    next_state = ST_EXECUTE;
                end
            end

            ST_EXECUTE: begin
                // TODO: Implement actual logic
                case (opcode)
                    // CLEAR
                    8'h01: begin
                        clear_start = 1'b1;
                        if (clear_done)
                            next_state = ST_IDLE;
                    end

                    // DRAW_TRIANGLE
                    8'h02: begin
                        raster_start = 1'b1;
                        if (raster_done)
                            next_state = ST_IDLE;
                    end

                    // DISPATCH_SIMD
                    8'h03: begin
                        simd_start = 1'b1;
                        if (simd_done)
                            next_state = ST_IDLE;
                    end

                    // SET_COLOR
                    8'h10: begin
                        set_color_we = 1'b1;
                        next_state = ST_IDLE;
                    end

                    // SET_VIEWPORT
                    8'h11: begin
                        set_viewport_we = 1'b1;
                        next_state = ST_IDLE;
                    end

                    // unknown opcode
                    default: begin
                        next_state = ST_IDLE;
                    end
                endcase
            end

            default: begin // default case
                next_state = ST_IDLE;
            end
        endcase        
    end

endmodule