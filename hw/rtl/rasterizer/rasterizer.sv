module rasterizer (
    input  logic        clk,
    input  logic        rst_n,

    // Control
    input  logic        start,
    output logic        done,

    // Geometry (from command payload)
    input  logic [31:0] x0,
    input  logic [31:0] y0,
    input  logic [31:0] x1,
    input  logic [31:0] y1,
    input  logic [31:0] x2,
    input  logic [31:0] y2,

    // State
    input  logic [31:0] color,
    input  logic [31:0] viewport_xmin,
    input  logic [31:0] viewport_ymin,
    input  logic [31:0] viewport_xmax,
    input  logic [31:0] viewport_ymax,

    // Pixel output
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
    } rast_state_t;

    rast_state_t state, next_state;

    // ------------------------------------------------
    // Latched inputs
    // ------------------------------------------------
    logic [31:0] latched_color;
    logic [31:0] latched_x0;
    logic [31:0] latched_y0;
    logic [31:0] latched_x1;
    logic [31:0] latched_y1;
    logic [31:0] latched_x2;
    logic [31:0] latched_y2;
    logic [31:0] latched_draw_xmin;
    logic [31:0] latched_draw_ymin;
    logic [31:0] latched_draw_xmax;
    logic [31:0] latched_draw_ymax;

    // ------------------------------------------------
    // Iteration counters
    // ------------------------------------------------
    logic [31:0] curr_x;
    logic [31:0] curr_y;

    // ------------------------------------------------
    // Bounding box 
    // ------------------------------------------------
    logic [31:0] bb_xmin;
    logic [31:0] bb_ymin;
    logic [31:0] bb_xmax;
    logic [31:0] bb_ymax;    

    // ------------------------------------------------
    // Clipping rectangle
    // ------------------------------------------------
    logic [31:0] draw_xmin;
    logic [31:0] draw_ymin;
    logic [31:0] draw_xmax;
    logic [31:0] draw_ymax;

    // ------------------------------------------------
    // Sequential logic
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;

            // reset counters
            curr_x <= 32'd0;
            curr_y <= 32'd0;

            // Clear latched inputs
            latched_color <= 32'd0;
            latched_x0        <= 32'd0;
            latched_y0        <= 32'd0;
            latched_x1        <= 32'd0;
            latched_y1        <= 32'd0;
            latched_x2        <= 32'd0;
            latched_y2        <= 32'd0;
            latched_draw_xmin <= 32'd0;
            latched_draw_ymin <= 32'd0;
            latched_draw_xmax <= 32'd0;
            latched_draw_ymax <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        // Latch inputs on start
                        latched_color     <= color;
                        latched_x0        <= x0;
                        latched_y0        <= y0;
                        latched_x1        <= x1;
                        latched_y1        <= y1;
                        latched_x2        <= x2;
                        latched_y2        <= y2;
                        latched_draw_xmin <= draw_xmin;
                        latched_draw_ymin <= draw_ymin;
                        latched_draw_xmax <= draw_xmax;
                        latched_draw_ymax <= draw_ymax;

                        // Initialize counters
                        curr_x <= latched_draw_xmin;
                        curr_y <= latched_draw_ymin;
                    end
                end

                ST_ACTIVE: begin
                    if (!((curr_x == latched_draw_xmax) && (curr_y == latched_draw_ymax))) begin
                        // Advance pixel coordinates
                        if (curr_x < latched_draw_xmax) begin
                            curr_x <= curr_x + 1;
                        end else begin
                            curr_x <= latched_draw_xmin;
                            curr_y <= curr_y + 1;
                        end
                    end
                end

                ST_DONE: begin
                    // No stateful work
                end
            endcase
        end
    end

    // ------------------------------------------------
    // Combinational FSM and outputs
    // ------------------------------------------------
    always_comb begin
        next_state  = state;

        pixel_valid = 1'b0;
        pixel_x     = 32'd0;
        pixel_y     = 32'd0;
        pixel_color = 32'd0;
        bb_xmin     = 32'd0;
        bb_ymin     = 32'd0;
        bb_xmax     = 32'd0;
        bb_ymax     = 32'd0;
        draw_xmin   = 32'd0;
        draw_ymin   = 32'd0;
        draw_xmax   = 32'd0;
        draw_ymax   = 32'd0;
        done        = 1'b0;

        // Compute bounding box
        bb_xmin = (latched_x0 < latched_x1) ? ((latched_x0 < latched_x2) ? latched_x0 : latched_x2) : ((latched_x1 < latched_x2) ? latched_x1 : latched_x2);
        bb_ymin = (latched_y0 < latched_y1) ? ((latched_y0 < latched_y2) ? latched_y0 : latched_y2) : ((latched_y1 < latched_y2) ? latched_y1 : latched_y2);
        bb_xmax = (latched_x0 > latched_x1) ? ((latched_x0 > latched_x2) ? latched_x0 : latched_x2) : ((latched_x1 > latched_x2) ? latched_x1 : latched_x2);
        bb_ymax = (latched_y0 > latched_y1) ? ((latched_y0 > latched_y2) ? latched_y0 : latched_y2) : ((latched_y1 > latched_y2) ? latched_y1 : latched_y2);

        // Compute clipping rectangle
        draw_xmin = (bb_xmin > viewport_xmin) ? bb_xmin : viewport_xmin;
        draw_ymin = (bb_ymin > viewport_ymin) ? bb_ymin : viewport_ymin;
        draw_xmax = (bb_xmax < viewport_xmax) ? bb_xmax : viewport_xmax;
        draw_ymax = (bb_ymax < viewport_ymax) ? bb_ymax : viewport_ymax;

        case (state)
            ST_IDLE: begin
                if (start) begin
                    // Degenerate case: no pixels to draw
                    if (draw_xmin > draw_xmax || draw_ymin > draw_ymax) begin
                        next_state = ST_DONE;
                    end else begin
                        next_state = ST_ACTIVE;
                    end
                end
            end

            ST_ACTIVE: begin
                pixel_valid = 1'b1;
                pixel_x     = curr_x;
                pixel_y     = curr_y;
                pixel_color = latched_color;

                if ((curr_x == latched_draw_xmax) && (curr_y == latched_draw_ymax)) begin
                    next_state = ST_DONE;
                end
            end

            ST_DONE: begin
                done = 1'b1;
                next_state = ST_IDLE;
            end
        endcase
    end

endmodule