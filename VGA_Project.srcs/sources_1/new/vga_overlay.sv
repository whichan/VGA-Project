module vga_overlay (
    input  logic                       clk,
    input  logic                       reset,
    input  logic [$clog2(320*240)-1:0] addr,
    input  logic                       out_valid,
    input  logic [                9:0] x_pixel,
    input  logic [                9:0] y_pixel,
    input  logic [                9:0] obj_x,
    input  logic [                9:0] obj_y,
    output logic [               15:0] data
);
  localparam SPRITE_W = 32;
  localparam HALF = 16;

  logic signed [11:0] dx, dy;
  logic signed [11:0] sprite_x, sprite_y;
  logic sprite_valid;
  logic [15:0] data_bg, data_fighter;
  logic [11:0] addr_fighter;

  assign dx = $signed({2'b0, x_pixel}) - $signed({1'b0, obj_x, 1'b0});
  assign dy = $signed({2'b0, y_pixel}) - $signed({1'b0, obj_y, 1'b0});
  assign sprite_x = dx + HALF;
  assign sprite_y = dy + HALF;
  assign sprite_valid = (sprite_x >= 0) &&(sprite_x < SPRITE_W) && (sprite_y >= 0) &&(sprite_y < SPRITE_W);
  assign addr_fighter = sprite_y[5:0] * SPRITE_W + sprite_x[5:0];

  background U_BACK (
      .addr(addr),
      .data(data_bg)
  );

  hostile_32 U_HOSTILE_1 (
      .addr(addr_fighter),
      .data(data_fighter)
  );

  always_comb begin
    if (out_valid && sprite_valid && (data_fighter != 16'h0000)) begin
      data = data_fighter;
    end else begin
      data = data_bg;
    end
  end
endmodule


module hostile_32 (
    input  logic [$clog2(32*32)-1:0] addr,
    output logic [             15:0] data
);
  logic [15:0] mem[0:32*32-1];
  initial begin
    $readmemh("hostile_32.mem", mem);
  end
  assign data = mem[addr];
endmodule

module background (
    input  logic [$clog2(320*240)-1:0] addr,
    output logic [               15:0] data
);
  logic [15:0] mem[0:320*240-1];
  initial begin
    $readmemh("background.mem", mem);
  end
  assign data = mem[addr];
endmodule
