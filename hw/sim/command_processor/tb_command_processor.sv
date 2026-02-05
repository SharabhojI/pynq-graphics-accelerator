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

        .simd_start(simd_start),
        .simd_done(simd_done)
    );

    // ------------------------------------------------
    // Helper: wait until DUT is idle
    // ------------------------------------------------
    task wait_idle;
        wait (dut.state == dut.ST_IDLE);
        @(posedge clk);
    endtask

    // ------------------------------------------------
    // Helper: send one command word
    // ------------------------------------------------
    task send_word(input [31:0] word);
        cmd_valid <= 1'b1;
        cmd_data  <= word;

        // Wait for acceptance
        @(posedge clk iff cmd_ready);

        // Drop valid immediately after acceptance
        cmd_valid <= 1'b0;
    endtask

    // ------------------------------------------------
    // Test Sequence
    // ------------------------------------------------
    initial begin
        clk = 0;
        rst_n = 0;

        cmd_valid = 0;
        cmd_data  = 32'b0;
        
        simd_done   = 0;

        // Reset
        #20;
        rst_n = 1;
        wait_idle();

        // ========================================================
        // SET_VIEWPORT (opcode 0x11, 4 payloads)
        // ========================================================
        send_word({8'h11, 8'h00, 16'd4});
        send_word(32'd0);
        send_word(32'd0);
        send_word(32'd4);
        send_word(32'd3);
        wait_idle();

        // ========================================================
        // CLEAR (opcode 0x01, no payload)
        // ========================================================
        send_word({8'h01, 8'h00, 16'd0});
        wait_idle(); // clear_unit finishes internally

        // ========================================================
        // DRAW_TRIANGLE (opcode 0x02, 6 payloads)
        // ========================================================
        send_word({8'h02, 8'h00, 16'd6});
        send_word(32'd10);
        send_word(32'd10);
        send_word(32'd50);
        send_word(32'd10);
        send_word(32'd30);
        send_word(32'd40);
        wait_idle(); // rasterizer finishes internally

        // ========================================================
        // SET_COLOR (opcode 0x10, 1 payload)
        // ========================================================
        send_word({8'h10, 8'h00, 16'd1});
        send_word(32'hFF0000);
        wait_idle();

        // ========================================================
        // Finish
        // ========================================================
        #100;
        $finish;
    end

endmodule