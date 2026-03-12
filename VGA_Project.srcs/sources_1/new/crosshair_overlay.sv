`timescale 1ns / 1ps
module crosshair_overlay (
    input  logic       DE,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic       manual_mode,
    input  logic [8:0] cx,           // 외부에서 받는 중심 X (QVGA)
    input  logic [7:0] cy,           // 외부에서 받는 중심 Y (QVGA)
    output logic       cross_on,
    output logic [3:0] cross_r,
    output logic [3:0] cross_g,
    output logic [3:0] cross_b
);

  localparam R_OUTER = 9'd40;
  localparam R_OUTER_THIN = 9'd38;
  localparam R_INNER = 9'd10;
  localparam R_INNER_THIN = 9'd8;
  localparam CROSS_LEN = 9'd60;
  localparam CROSS_GAP = 9'd12;

  // VGA → QVGA 변환
  wire [8:0] qx = x_pixel[9:1];
  wire [7:0] qy = y_pixel[9:1];

  // 중심으로부터 거리
  wire signed [9:0] dx = {1'b0, qx} - {1'b0, cx};
  wire signed [9:0] dy = {1'b0, qy} - {1'b0, cy};

  wire [17:0] dx2 = dx * dx;
  wire [17:0] dy2 = dy * dy;
  wire [18:0] dist2 = dx2 + dy2;

  // 원 판정
  wire on_outer_circle = (dist2 <= R_OUTER * R_OUTER) && (dist2 >= R_OUTER_THIN * R_OUTER_THIN);
  wire on_inner_circle = (dist2 <= R_INNER * R_INNER) && (dist2 >= R_INNER_THIN * R_INNER_THIN);

  // 십자선 판정
  wire [8:0] abs_dx = dx[9] ? (~dx[8:0] + 1) : dx[8:0];
  wire [7:0] abs_dy = dy[9] ? (~dy[7:0] + 1) : dy[7:0];

  wire on_h_line = (qy == cy) && (abs_dx >= CROSS_GAP) && (abs_dx <= CROSS_LEN);
  wire on_v_line = (qx == cx) && (abs_dy >= CROSS_GAP) && (abs_dy <= CROSS_LEN);

  wire on_center_dot = (abs_dx <= 1) && (abs_dy <= 1);

  wire on_any = DE && manual_mode &&
                (on_outer_circle || on_inner_circle ||
                 on_h_line || on_v_line || on_center_dot);

  assign cross_on = on_any;
  assign cross_r  = 4'h0;
  assign cross_g  = on_any ? 4'hF : 4'h0;
  assign cross_b  = 4'h0;

endmodule
