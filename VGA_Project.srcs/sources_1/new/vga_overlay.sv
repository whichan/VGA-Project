module vga_overlay (
    input  logic                       reset,
    input  logic [$clog2(320*240)-1:0] addr,
    input  logic [                9:0] x_pixel,
    input  logic [                9:0] y_pixel,
    input  logic [                9:0] obj_x_1,
    input  logic [                9:0] obj_y_1,
    input  logic                       out_valid_1,
    input  logic [                9:0] obj_x_2,
    input  logic [                9:0] obj_y_2,
    input  logic                       out_valid_2,
    output logic [               15:0] data
);
  localparam SPRITE_W = 32;
  localparam HALF = 16;

  logic [15:0] data_bg;

  logic signed [11:0] dx_1, dy_1;
  logic signed [11:0] sprite_x_1, sprite_y_1;
  logic sprite_valid_1;
  logic [15:0] data_fighter_1;
  logic [11:0] addr_fighter_1;

  assign dx_1 = $signed({2'b0, x_pixel}) - $signed({1'b0, obj_x_1, 1'b0});
  assign dy_1 = $signed({2'b0, y_pixel}) - $signed({1'b0, obj_y_1, 1'b0});
  assign sprite_x_1 = dx_1 + HALF;
  assign sprite_y_1 = dy_1 + HALF;
  assign sprite_valid_1 = (sprite_x_1 >= 0) &&(sprite_x_1 < SPRITE_W) && (sprite_y_1 >= 0) &&(sprite_y_1 < SPRITE_W);
  assign addr_fighter_1 = sprite_y_1[5:0] * SPRITE_W + sprite_x_1[5:0];

  logic signed [11:0] dx_2, dy_2;
  logic signed [11:0] sprite_x_2, sprite_y_2;
  logic sprite_valid_2;
  logic [15:0] data_fighter_2;
  logic [11:0] addr_fighter_2;

  assign dx_2 = $signed({2'b0, x_pixel}) - $signed({1'b0, obj_x_2, 1'b0});
  assign dy_2 = $signed({2'b0, y_pixel}) - $signed({1'b0, obj_y_2, 1'b0});
  assign sprite_x_2 = dx_2 + HALF;
  assign sprite_y_2 = dy_2 + HALF;
  assign sprite_valid_2 = (sprite_x_2 >= 0) &&(sprite_x_2 < SPRITE_W) && (sprite_y_2 >= 0) &&(sprite_y_2 < SPRITE_W);
  assign addr_fighter_2 = sprite_y_2[5:0] * SPRITE_W + sprite_x_2[5:0];

  background U_BACK (
      .addr(addr),
      .data(data_bg)
  );

  hostile_32 U_HOSTILE_1 (
      .addr(addr_fighter_1),
      .data(data_fighter_1)
  );

  hostile_32 U_HOSTILE_2 (
      .addr(addr_fighter_2),
      .data(data_fighter_2)
  );

  always_comb begin
    if (out_valid_1 && sprite_valid_1 && (data_fighter_1 != 16'h0000)) begin
      data = data_fighter_1;
    end else if (out_valid_2 && sprite_valid_2 && (data_fighter_2 != 16'h0000)) begin
      data = data_fighter_2;
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
