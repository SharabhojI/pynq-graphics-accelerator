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

    // ------------------------------------------------
    // Registers (TODO: Implement)
    // ------------------------------------------------
    logic [7:0] opcode;
    logic [15:0] payload_length;
    logic [15:0] payload_count;

    // ------------------------------------------------
    // State Register
    // ------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin // flip-flop
        if (!rst_n) begin // if low reset
            state <= ST_IDLE; // reset to initial/idle state
            opcode <= 8'h00;
            payload_length <= 16'd0;
            payload_count <= 16'd0;
        end else begin
            state <= next_state; // advance to next state
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

                opcode = 8'h01;
                payload_length = 16'd0;

                next_state = ST_READ_PAYLOAD;
            end

            ST_READ_PAYLOAD: begin
                // if there is no payload, go to execute
                if (payload_length == 0) begin
                    next_state = ST_EXECUTE;
                end else begin
                    cmd_ready = 1'b1;
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