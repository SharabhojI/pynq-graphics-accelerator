module tb_command_processor;

    // ------------------------------------------------
    // Clock and Reset
    // ------------------------------------------------
    logic clk;
    logic rst_n;

    always #5 clk = ~clk;

    // ------------------------------------------------
    // DUT Signals
    // ------------------------------------------------
    logic        cmd_valid;
    logic [31:0] cmd_data;
    logic        cmd_ready;

    logic        clear_start;

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

        .raster_start(raster_start),
        .raster_done(raster_done),

        .simd_start(simd_start),
        .simd_done(simd_done)
    );

    // ------------------------------------------------
    // Pixel Monitor
    // ------------------------------------------------
    always @(posedge clk) begin
        if (dut.arbiter_pixel_valid) begin
            $display(
                "PIXEL @ %0t : (%0d, %0d) = %h",
                $time,
                dut.arbiter_pixel_x,
                dut.arbiter_pixel_y,
                dut.arbiter_pixel_color
            );
        end
    end

    // ------------------------------------------------
    // Helper: wait until DUT is idle
    // ------------------------------------------------
    task wait_idle;
        wait (dut.state == dut.ST_IDLE);
        @(posedge clk);
    endtask

    // ------------------------------------------------
    // Test Sequence
    // ------------------------------------------------
    initial begin
        clk = 0;
        rst_n = 0;

        cmd_valid = 0;
        cmd_data  = 32'b0;

        raster_done = 0;
        simd_done   = 0;

        // Reset
        #20;
        rst_n = 1;
        wait_idle();

        // ========================================================
        // SET_VIEWPORT
        // ========================================================
        cmd_valid = 1;
        cmd_data  = {8'h11, 8'h00, 16'd4};
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd0;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd0;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd4;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd3;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        wait_idle();

        // ========================================================
        // CLEAR
        // ========================================================
        cmd_valid = 1;
        cmd_data  = {8'h01, 8'h00, 16'd0};
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        // clear_unit runs internally
        wait_idle();

        // ========================================================
        // DRAW_TRIANGLE
        // ========================================================
        cmd_valid = 1;
        cmd_data  = {8'h02, 8'h00, 16'd6};
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd10;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd10;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd50;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd10;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd30;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk); cmd_valid = 1; cmd_data = 32'd40;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        // wait for raster start pulse
        @(posedge clk iff raster_start);

        // simulate raster execution latency
        repeat (5) @(posedge clk);
        raster_done <= 1'b1;
        @(posedge clk);
        raster_done <= 1'b0;

        wait_idle();

        // ========================================================
        // SET_COLOR
        // ========================================================
        cmd_valid = 1;
        cmd_data  = {8'h10, 8'h00, 16'd1};
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        @(posedge clk);
        cmd_valid = 1;
        cmd_data  = 32'hFF0000;
        wait (cmd_ready);
        @(posedge clk);
        cmd_valid = 0;

        wait_idle();

        // ========================================================
        // Finish
        // ========================================================
        #100;
        $finish;
    end

endmodule
