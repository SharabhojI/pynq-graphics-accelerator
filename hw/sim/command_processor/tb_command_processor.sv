module tb_command_processor;
    
    // ------------------------------------------------
    // Clock and Reset
    // ------------------------------------------------
    logic clk;
    logic rst_n;

    always #5 clk = ~clk; // 10 time unit clock period (100MHz)

    // ------------------------------------------------
    // DUT Signals
    // ------------------------------------------------
    logic        cmd_valid;
    logic [31:0] cmd_data;
    logic        cmd_ready;

    logic        clear_start;
    logic        clear_done;

    logic        raster_start;
    logic        raster_done;

    logic        simd_start;
    logic        simd_done;

    // ------------------------------------------------
    // Instantiate DUT
    // ------------------------------------------------
    command_processor dut (
        .clk(clk),
        .rst_n(rst_n),

        .cmd_valid(cmd_valid),
        .cmd_data(cmd_data),
        .cmd_ready(cmd_ready),

        .clear_start(clear_start),
        .clear_done(clear_done),

        .raster_start(raster_start),
        .raster_done(raster_done),

        .simd_start(simd_start),
        .simd_done(simd_done)
    );
    
    // ------------------------------------------------
    // Test Sequence
    // ------------------------------------------------
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;

        cmd_valid = 0;
        cmd_data = 32'b0;

        clear_done = 0;
        raster_done = 0;
        simd_done = 0;

        // Apply reset
        #20;
        rst_n = 1;

        // ------------------------------------------------
        // Issue fake CLEAR command
        // ------------------------------------------------

        #20;
        cmd_valid = 1;
        cmd_data = {8'h01, 8'h00, 16'd0}; // CLEAR command with 0 payload length

        // Wait until command is accepted
        wait (cmd_ready);
        #10;
        cmd_valid = 0;

        // ------------------------------------------------
        // Simulate CLEAR operation completion
        // ------------------------------------------------
        wait (clear_start);
        #30;
        clear_done = 1;
        #10;
        clear_done = 0;

        // ------------------------------------------------
        // Issue DRAW_TRIANGLE command
        // ------------------------------------------------
        #40;

        // Send DRAW header
        cmd_valid = 1;
        cmd_data  = {8'h02, 8'h00, 16'd6}; // DRAW_TRIANGLE, payload_length = 6

        wait (cmd_ready);
        #10;
        cmd_valid = 0;

        // ------------------------------------------------
        // Send DRAW payload (6 words)
        // ------------------------------------------------

        // Vertex 0
        #10; cmd_valid = 1; cmd_data = 32'd10; // x0
        wait (cmd_ready);
        #10; cmd_valid = 0;

        #10; cmd_valid = 1; cmd_data = 32'd10; // y0
        wait (cmd_ready);
        #10; cmd_valid = 0;

        // Vertex 1
        #10; cmd_valid = 1; cmd_data = 32'd50; // x1
        wait (cmd_ready);
        #10; cmd_valid = 0;

        #10; cmd_valid = 1; cmd_data = 32'd10; // y1
        wait (cmd_ready);
        #10; cmd_valid = 0;

        // Vertex 2
        #10; cmd_valid = 1; cmd_data = 32'd30; // x2
        wait (cmd_ready);
        #10; cmd_valid = 0;

        #10; cmd_valid = 1; cmd_data = 32'd40; // y2
        wait (cmd_ready);
        #10; cmd_valid = 0;

        // ------------------------------------------------
        // Simulate rasterizer completion
        // ------------------------------------------------
        wait (raster_start);
        #50;
        raster_done = 1;
        #10;
        raster_done = 0;

        // ------------------------------------------------
        // Finish
        // ------------------------------------------------
        #100;
        $finish;
    end

endmodule