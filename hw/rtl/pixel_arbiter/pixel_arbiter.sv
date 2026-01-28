module pixel_arbiter (
    input  logic        clear_valid,
    input  logic [31:0] clear_x,
    input  logic [31:0] clear_y,
    input  logic [31:0] clear_color,

    input  logic        raster_valid,
    input  logic [31:0] raster_x,
    input  logic [31:0] raster_y,
    input  logic [31:0] raster_color,

    input  logic        simd_valid,
    input  logic [31:0] simd_x,
    input  logic [31:0] simd_y,
    input  logic [31:0] simd_color,

    output logic        pixel_valid,
    output logic [31:0] pixel_x,
    output logic [31:0] pixel_y,
    output logic [31:0] pixel_color
);

always_comb begin
    pixel_valid = 1'b0;
    pixel_x     = 32'd0;
    pixel_y     = 32'd0;
    pixel_color = 32'd0;

    if (clear_valid) begin
        pixel_valid = 1'b1;
        pixel_x     = clear_x;
        pixel_y     = clear_y;
        pixel_color = clear_color;
    end
    else if (raster_valid) begin
        pixel_valid = 1'b1;
        pixel_x     = raster_x;
        pixel_y     = raster_y;
        pixel_color = raster_color;
    end
    else if (simd_valid) begin
        pixel_valid = 1'b1;
        pixel_x     = simd_x;
        pixel_y     = simd_y;
        pixel_color = simd_color;
    end
end
    
endmodule