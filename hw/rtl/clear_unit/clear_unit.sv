module clear_unit (
    input  logic        clk,
    input  logic        rst_n, // active low reset signal

    input  logic        start, // one-cycle pulse
    output logic        done,  // one-cycle pulse

    input  logic [31:0] color,
    input  logic [31:0] xmin,
    input  logic [31:0] ymin,
    input  logic [31:0] xmax,
    input  logic [31:0] ymax,

    // debug/framebuffer interface
    output logic        pixel_valid,
    output logic [31:0] pixel_x,
    output logic [31:0] pixel_y,
    output logic [31:0] pixel_color
); 

    // ------------------------------------------------
    // FSM State Definition
    // ------------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_ACTIVE,
        ST_DONE
    } clear_state_t;

    clear_state_t state, next_state;

    // ------------------------------------------------
    // Latched inputs
    // ------------------------------------------------
    logic [31:0] latched_color;
    logic [31:0] latched_xmin;
    logic [31:0] latched_ymin;
    logic [31:0] latched_xmax;
    logic [31:0] latched_ymax;

    // ------------------------------------------------
    // Iteration counters
    // ------------------------------------------------
    logic [31:0] curr_x;
    logic [31:0] curr_y;

    // ------------------------------------------------
    // State Register and Datapath
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;

            // reset counters
            curr_x <= 32'd0;
            curr_y <= 32'd0;

            // reset latched inputs
            latched_color <= 32'd0;
            latched_xmin  <= 32'd0;
            latched_ymin  <= 32'd0;
            latched_xmax  <= 32'd0;
            latched_ymax  <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        // latch inputs on start pulse
                        latched_color <= color;
                        latched_xmin  <= xmin;
                        latched_ymin  <= ymin;
                        latched_xmax  <= xmax;
                        latched_ymax  <= ymax;

                        // initialize counters
                        curr_x <= xmin;
                        curr_y <= ymin;
                    end
                end

                ST_ACTIVE: begin
                    // advance counters unless this is the final pixel
                    if (!((curr_x == latched_xmax - 1) && (curr_y == latched_ymax - 1))) begin
                        if (curr_x + 1 < latched_xmax) begin
                            curr_x <= curr_x + 1;
                        end else begin
                            curr_x <= latched_xmin;
                            curr_y <= curr_y + 1;
                        end
                    end
                end

                ST_DONE: begin
                    // no datapath updates
                end
            endcase
        end
    end

    // ------------------------------------------------
    // FSM Next State Logic and Outputs
    // ------------------------------------------------
    always_comb begin
        // defaults
        next_state  = state;
        pixel_valid = 1'b0;
        pixel_x     = curr_x;
        pixel_y     = curr_y;
        pixel_color = latched_color;
        done        = 1'b0;

        case (state)
            ST_IDLE: begin
                if (start)
                    next_state = ST_ACTIVE;
            end

            ST_ACTIVE: begin
                pixel_valid = 1'b1;

                // transition after issuing final pixel
                if ((curr_x == latched_xmax - 1) && (curr_y == latched_ymax - 1)) begin
                    next_state = ST_DONE;
                end
            end

            ST_DONE: begin
                done = 1'b1;          // exactly one cycle
                next_state = ST_IDLE; // return immediately to idle
            end
        endcase
    end

endmodule