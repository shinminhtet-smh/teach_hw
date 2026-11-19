`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // Always 1 when powered
  input  wire       clk,      // Clock
  input  wire       rst_n     // Active-low reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD pinout
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in, pix_x};

  // VGA sync generator (640x480)
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );


  reg [5:0] color;
  reg shape1, shape2, shape3;

  always @(posedge clk) begin
    if (rst_n == 0) begin
      color  <= 6'b000000;
      shape1 <= 1'b0;
      shape2 <= 1'b0;
      shape3 <= 1'b0;
    end else begin
      shape1 <= (pix_y < 10'd160) ? 1'b1 : 1'b0;
      shape2 <= (pix_y >= 10'd160 && pix_y < 10'd320) ? 1'b1 : 1'b0;
      shape3 <= (pix_y >= 10'd320) ? 1'b1 : 1'b0;
      color <= (shape1 | shape3) ? 6'b110000 : (shape2 ? 6'b111111 : 6'b000000);
    end
  end

  assign R = (video_active) ? color[5:4] : 2'b00;
  assign G = (video_active) ? color[3:2] : 2'b00;
  assign B = (video_active) ? color[1:0] : 2'b00;

endmodule