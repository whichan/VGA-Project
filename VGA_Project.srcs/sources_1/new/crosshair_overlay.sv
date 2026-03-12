`timescale 1ns / 1ps
//=============================================================================
// crosshair_overlay
// - 수동 모드일 때 화면 중앙에 저격 조준경 표시
// - 320×240 QVGA 좌표 기준 (업스케일 후 VGA 640×480에서 입력받음)
// - 외부 원(r=40), 내부 원(r=10), 십자선
// - 색상: 초록 (R=0, G=F, B=0)
//=============================================================================
module crosshair_overlay (
    input  logic       DE,
    input  logic [9:0] x_pixel,      // VGA 0~639
    input  logic [9:0] y_pixel,      // VGA 0~479
    input  logic       manual_mode,  // 1=수동, 0=자동
    output logic       cross_on,
    output logic [3:0] cross_r,
    output logic [3:0] cross_g,
    output logic [3:0] cross_b
);

  // =========================================================================
  // QVGA 좌표로 변환 (업스케일 역변환)
  // =========================================================================
  wire [8:0] qx = x_pixel[9:1];  // 0~319
  wire [7:0] qy = y_pixel[9:1];  // 0~239

  // =========================================================================
  // 중심점 (QVGA 기준)
  // =========================================================================
  localparam CX = 9'd160;
  localparam CY = 8'd120;

  localparam R_OUTER = 9'd40;  // 외부 원 반지름
  localparam R_OUTER_THIN = 9'd38;  // 외부 원 두께 (40-2)
  localparam R_INNER = 9'd10;  // 내부 원 반지름
  localparam R_INNER_THIN = 9'd8;  // 내부 원 두께 (10-2)
  localparam CROSS_LEN = 9'd60;  // 십자선 길이 (중심에서 양쪽으로)
  localparam CROSS_GAP = 9'd12;  // 십자선 내부 빈 공간 (내부 원 안쪽)

  // =========================================================================
  // 중심으로부터 거리 계산 (dx², dy², dx²+dy²)
  // =========================================================================
  wire signed [9:0] dx = {1'b0, qx} - {1'b0, CX};
  wire signed [9:0] dy = {1'b0, qy} - {1'b0, CY};

  wire [17:0] dx2 = dx * dx;
  wire [17:0] dy2 = dy * dy;
  wire [18:0] dist2 = dx2 + dy2;

  // =========================================================================
  // 원 판정 (r²으로 비교, 나눗셈 없음)
  // =========================================================================
  // 외부 원 테두리: R_OUTER_THIN² <= dist² <= R_OUTER²
  wire on_outer_circle = (dist2 <= R_OUTER * R_OUTER) && (dist2 >= R_OUTER_THIN * R_OUTER_THIN);

  // 내부 원 테두리: R_INNER_THIN² <= dist² <= R_INNER²
  wire on_inner_circle = (dist2 <= R_INNER * R_INNER) && (dist2 >= R_INNER_THIN * R_INNER_THIN);

  // =========================================================================
  // 십자선 판정
  // 가로선: y == CY, x 범위 [CX-CROSS_LEN, CX-CROSS_GAP] | [CX+CROSS_GAP, CX+CROSS_LEN]
  // 세로선: x == CX, y 범위 동일
  // =========================================================================
  wire [8:0] abs_dx = dx[9] ? (~dx[8:0] + 1) : dx[8:0];
  wire [7:0] abs_dy = dy[9] ? (~dy[7:0] + 1) : dy[7:0];

  wire on_h_line = (qy == CY) && (abs_dx >= CROSS_GAP) && (abs_dx <= CROSS_LEN);

  wire on_v_line = (qx == CX) && (abs_dy >= CROSS_GAP) && (abs_dy <= CROSS_LEN);

  wire on_cross_line = on_h_line || on_v_line;

  // =========================================================================
  // 작은 중심 도트 (중심점 정확히 표시)
  // =========================================================================
  wire on_center_dot = (abs_dx <= 1) && (abs_dy <= 1);

  // =========================================================================
  // 최종 출력
  // =========================================================================
  wire on_any = DE && manual_mode &&
                (on_outer_circle || on_inner_circle || on_cross_line || on_center_dot);

  assign cross_on = on_any;
  assign cross_r  = on_any ? 4'h0 : 4'h0;
  assign cross_g  = on_any ? 4'hF : 4'h0;
  assign cross_b  = on_any ? 4'h0 : 4'h0;

endmodule
