module tb_clear_unit;
    
    // ------------------------------------------------
    // Clock and Reset
    // ------------------------------------------------
    logic clk;
    logic rst_n;

    always #5 clk = ~clk; // 10 time unit clock period (100MHz)

    // ------------------------------------------------
    // DUT Signals
    // ------------------------------------------------
    logic       start;
    logic       done;

    logic [31:0] color;
    logic [31:0] xmin;
    logic [31:0] ymin;
    logic [31:0] xmax;
    logic [31:0] ymax;

    logic        pixel_valid;
    logic [31:0] pixel_x;
    logic [31:0] pixel_y;
    logic [31:0] pixel_color;

    // ------------------------------------------------
    // Instantiate DUT
    // ------------------------------------------------
    clear_unit dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .done(done),

        .color(color),
        .xmin(xmin),
        .ymin(ymin),
        .xmax(xmax),
        .ymax(ymax),

        .pixel_valid(pixel_valid),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_color(pixel_color)
    );
    
    // ------------------------------------------------
    // Test Sequence
    // ------------------------------------------------
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        start = 0;

        color = 32'hA5A5A5A5; // test color
        xmin  = 32'd0;
        ymin  = 32'd0;
        xmax  = 32'd3;
        ymax  = 32'd2;

        // Apply reset pulse
        #20;
        rst_n = 1;

        // Wait couple cycles
        #20;

        // ------------------------------------------------
        // Start clear operation
        // ------------------------------------------------
        start = 1;
        #10;
        start = 0;

        // ------------------------------------------------
        // Wait for done signal
        // ------------------------------------------------
        wait (done);

        // ------------------------------------------------
        // Finish
        // ------------------------------------------------
        #20;
        $finish;
    end

endmodule