// `timescale 1ns / 1ps
// // ImgMemReader — 업스케일 보간 + 바운딩 박스 + 좌표 텍스트 표시
// //
// // 기능:
// //   1. 320×240 → 640×480 업스케일 (가로 바이리니어 보간)
// //   2. 바운딩 박스 테두리 오버레이 (빨간색)
// //   3. 중심점 크로스헤어 (노란색)
// //   4. 좌상단 좌표 텍스트 표시 (X:nnn Y:nnn)
// module ImgMemReader #(
//     parameter IMG_SIZE = 320 * 240,
//     parameter IMG_W    = 320,
//     parameter IMG_H    = 240
// ) (
//     input  logic                        clk,
//     input  logic                        DE,
//     input  logic [                 9:0] x_pixel,
//     input  logic [                 9:0] y_pixel,
//     input  logic [                15:0] imgData,
//     output logic [$clog2(IMG_SIZE)-1:0] addr,
//     output logic [                 3:0] port_red,
//     output logic [                 3:0] port_green,
//     output logic [                 3:0] port_blue,
//     input  logic [                 8:0] box_x_min,
//     input  logic [                 8:0] box_x_max,
//     input  logic [                 7:0] box_y_min,
//     input  logic [                 7:0] box_y_max,
//     input  logic                        box_valid
//     //xpixel, ypixel 추가
//     // output logic [                 9:0] out_center_x,
//     // output logic [                 9:0] out_center_y,
//     // output logic                        out_valid      //box valid 전달
// );



//   // QVGA 좌표 변환
//   wire [8:0] qvga_x = x_pixel[9:1];
//   wire [7:0] qvga_y = y_pixel[9:1];

//   // BRAM 주소 생성 (보간용)
//   wire [8:0] read_x = x_pixel[0] ? (qvga_x + 1) : qvga_x;
//   wire [8:0] clamped_x = (read_x > (IMG_W - 1)) ? (IMG_W - 1) : read_x;
//   assign addr = DE ? (IMG_W * qvga_y + clamped_x) : '0;

//   // RGB565 → RGB444
//   wire [3:0] cur_r = imgData[15:12];
//   wire [3:0] cur_g = imgData[10:7];
//   wire [3:0] cur_b = imgData[4:1];

//   // 이전 픽셀 저장 (보간용)
//   reg [3:0] prev_r, prev_g, prev_b;
//   always_ff @(posedge clk) begin
//     if (!DE) begin
//       prev_r <= 4'd0;
//       prev_g <= 4'd0;
//       prev_b <= 4'd0;
//     end else if (!x_pixel[0]) begin
//       prev_r <= cur_r;
//       prev_g <= cur_g;
//       prev_b <= cur_b;
//     end
//   end

//   // 보간 평균
//   wire [3:0] avg_r = ({1'b0, prev_r} + {1'b0, cur_r}) >> 1;
//   wire [3:0] avg_g = ({1'b0, prev_g} + {1'b0, cur_g}) >> 1;
//   wire [3:0] avg_b = ({1'b0, prev_b} + {1'b0, cur_b}) >> 1;

//   wire [3:0] img_r = x_pixel[0] ? avg_r : cur_r;
//   wire [3:0] img_g = x_pixel[0] ? avg_g : cur_g;
//   wire [3:0] img_b = x_pixel[0] ? avg_b : cur_b;

//   // 바운딩 박스 (×2 스케일)
//   wire [9:0] bx_min = {box_x_min, 1'b0};
//   wire [9:0] bx_max = {box_x_max, 1'b0} + 1;
//   wire [9:0] by_min = {box_y_min, 1'b0};
//   wire [9:0] by_max = {box_y_max, 1'b0} + 1;

//   wire on_left   = (x_pixel >= bx_min) && (x_pixel <= bx_min + 1)
//                      && (y_pixel >= by_min) && (y_pixel <= by_max);
//   wire on_right  = (x_pixel >= bx_max - 1) && (x_pixel <= bx_max)
//                      && (y_pixel >= by_min) && (y_pixel <= by_max);
//   wire on_top    = (y_pixel >= by_min) && (y_pixel <= by_min + 1)
//                      && (x_pixel >= bx_min) && (x_pixel <= bx_max);
//   wire on_bottom = (y_pixel >= by_max - 1) && (y_pixel <= by_max)
//                      && (x_pixel >= bx_min) && (x_pixel <= bx_max);

//   wire on_box = box_valid && (on_left || on_right || on_top || on_bottom);

//   // 중심점 십자가
//   wire [9:0] cx = (bx_min + bx_max) >> 1;
//   wire [9:0] cy = (by_min + by_max) >> 1;

//   wire on_cross = box_valid && (
//         ((x_pixel == cx) && (y_pixel >= cy - 5) && (y_pixel <= cy + 5)) ||
//         ((y_pixel == cy) && (x_pixel >= cx - 5) && (x_pixel <= cx + 5))
//     );

//   // 중심점 QVGA 좌표 (텍스트 표시용)
//   wire [9:0] center_x_val = (box_x_min + box_x_max) >> 1;
//   wire [8:0] center_y_val = (box_y_min + box_y_max) >> 1;

//   // 텍스트 오버레이 인스턴스
//   logic text_on;
//   logic [3:0] text_r, text_g, text_b;
//   logic bg_on;

//   //spi master로 현재 좌표 중심값 전달
//   //   assign out_center_x = center_x_val;
//   //   assign out_center_y = center_y_val;
//   //   assign out_valid = box_valid;

//   text_overlay u_text_overlay (
//       .x_pixel    (x_pixel),
//       .y_pixel    (y_pixel),
//       .DE         (DE),
//       .center_x   (center_x_val),
//       .center_y   (center_y_val),
//       .coord_valid(box_valid),
//       .text_on    (text_on),
//       .text_r     (text_r),
//       .text_g     (text_g),
//       .text_b     (text_b),
//       .bg_on      (bg_on)
//   );

//   // 최종 출력
//   // 우선순위: 텍스트 > 텍스트배경 > 크로스헤어 > 박스 > 보간영상
//   always_comb begin
//     if (!DE) begin
//       port_red   = 4'd0;
//       port_green = 4'd0;
//       port_blue  = 4'd0;
//     end else if (text_on) begin
//       port_red   = text_r;
//       port_green = text_g;
//       port_blue  = text_b;
//     end else if (bg_on) begin
//       port_red   = img_r >> 1;
//       port_green = img_g >> 1;
//       port_blue  = img_b >> 1;
//     end else if (on_cross) begin
//       port_red   = 4'hF;
//       port_green = 4'hD;
//       port_blue  = 4'h0;
//     end else if (on_box) begin
//       port_red   = 4'hF;
//       port_green = 4'h0;
//       port_blue  = 4'h0;
//     end else begin
//       port_red   = img_r;
//       port_green = img_g;
//       port_blue  = img_b;
//     end
//   end

// endmodule


`timescale 1ns / 1ps
// ImgMemReader — 3색 바운딩 박스 + 크로스헤어 + 좌표 텍스트
//
// 기능:
//   1. 320×240 → 640×480 nearest-neighbor 업스케일
//   2. R/G/B 3색 바운딩 박스 오버레이 (QVGA 좌표 기준)
//   3. 각 박스 중심점 크로스헤어 (같은 색, QVGA 좌표 기준)
//   4. 좌상단 좌표 텍스트 3줄 (R/G/B 각각, QVGA 좌표 기준)
//
// 우선순위: 텍스트(R>G>B) > 텍스트배경 > 크로스헤어(R>G>B) > 박스(R>G>B) > 원본
module ImgMemReader #(
    parameter IMG_SIZE = 360 * 240,
    parameter IMG_W    = 320,
    parameter IMG_H    = 240
) (
    input  logic                        clk,
    input  logic                        DE,
    input  logic [                 9:0] x_pixel,       // VGA 0~639
    input  logic [                 9:0] y_pixel,       // VGA 0~479
    input  logic [                15:0] imgData,
    output logic [$clog2(IMG_SIZE)-1:0] addr,
    output logic [                 3:0] port_red,
    output logic [                 3:0] port_green,
    output logic [                 3:0] port_blue,
    // Red 박스 (QVGA 좌표)
    input  logic [                 8:0] box_r_x_min,
    input  logic [                 8:0] box_r_x_max,
    input  logic [                 7:0] box_r_y_min,
    input  logic [                 7:0] box_r_y_max,
    input  logic                        box_r_valid,
    // Green 박스 (QVGA 좌표)
    input  logic [                 8:0] box_g_x_min,
    input  logic [                 8:0] box_g_x_max,
    input  logic [                 7:0] box_g_y_min,
    input  logic [                 7:0] box_g_y_max,
    input  logic                        box_g_valid,
    // Blue 박스 (QVGA 좌표)
    input  logic [                 8:0] box_b_x_min,
    input  logic [                 8:0] box_b_x_max,
    input  logic [                 7:0] box_b_y_min,
    input  logic [                 7:0] box_b_y_max,
    input  logic                        box_b_valid,
    //중심점
    output logic [                 9:0] out_center_x,  // Red 박스 중심 X (QVGA 0~319)
    output logic [                 9:0] out_center_y   // Red 박스 중심 Y (QVGA 0~239)
);

  // =========================================================================
  // QVGA 좌표 변환 및 BRAM 주소 생성 (nearest-neighbor 업스케일)
  // =========================================================================
  wire [8:0] qvga_x = x_pixel[9:1];  // VGA x → QVGA x (÷2)
  wire [7:0] qvga_y = y_pixel[9:1];  // VGA y → QVGA y (÷2)

  assign addr = DE ? (IMG_W * qvga_y + qvga_x) : '0;

  // =========================================================================
  // RGB565 → RGB444
  // =========================================================================
  wire [3:0] img_r = imgData[15:12];
  wire [3:0] img_g = imgData[10:7];
  wire [3:0] img_b = imgData[4:1];

  // =========================================================================
  // QVGA 좌표로 오버레이 판정
  // x_pixel[9:1] = qvga_x, y_pixel[9:1] = qvga_y 사용
  // =========================================================================

  // --- 바운딩 박스 테두리 ---
  wire on_box_r = box_r_valid && DE && (
      ((qvga_y == box_r_y_min || qvga_y == box_r_y_max) &&
        qvga_x >= box_r_x_min && qvga_x <= box_r_x_max) ||
      ((qvga_x == box_r_x_min || qvga_x == box_r_x_max) &&
        qvga_y >= box_r_y_min && qvga_y <= box_r_y_max)
  );

  wire on_box_g = box_g_valid && DE && (
      ((qvga_y == box_g_y_min || qvga_y == box_g_y_max) &&
        qvga_x >= box_g_x_min && qvga_x <= box_g_x_max) ||
      ((qvga_x == box_g_x_min || qvga_x == box_g_x_max) &&
        qvga_y >= box_g_y_min && qvga_y <= box_g_y_max)
  );

  wire on_box_b = box_b_valid && DE && (
      ((qvga_y == box_b_y_min || qvga_y == box_b_y_max) &&
        qvga_x >= box_b_x_min && qvga_x <= box_b_x_max) ||
      ((qvga_x == box_b_x_min || qvga_x == box_b_x_max) &&
        qvga_y >= box_b_y_min && qvga_y <= box_b_y_max)
  );

  // --- 중심점 계산 (QVGA 기준) ---
  wire [8:0] cx_r = ({1'b0, box_r_x_min} + {1'b0, box_r_x_max}) >> 1;
  wire [7:0] cy_r = ({1'b0, box_r_y_min} + {1'b0, box_r_y_max}) >> 1;

  wire [8:0] cx_g = ({1'b0, box_g_x_min} + {1'b0, box_g_x_max}) >> 1;
  wire [7:0] cy_g = ({1'b0, box_g_y_min} + {1'b0, box_g_y_max}) >> 1;

  wire [8:0] cx_b = ({1'b0, box_b_x_min} + {1'b0, box_b_x_max}) >> 1;
  wire [7:0] cy_b = ({1'b0, box_b_y_min} + {1'b0, box_b_y_max}) >> 1;


  assign out_center_x = cx_r;
  assign out_center_y = cy_r;

  // --- 크로스헤어 (QVGA 좌표 기준, ±5픽셀) ---
  localparam CROSS_HALF = 5;

  wire on_cross_r = box_r_valid && DE && (
      ((qvga_x == cx_r) && (qvga_y + CROSS_HALF >= cy_r) && (qvga_y <= cy_r + CROSS_HALF)) ||
      ((qvga_y == cy_r) && (qvga_x + CROSS_HALF >= cx_r) && (qvga_x <= cx_r + CROSS_HALF))
  );

  wire on_cross_g = box_g_valid && DE && (
      ((qvga_x == cx_g) && (qvga_y + CROSS_HALF >= cy_g) && (qvga_y <= cy_g + CROSS_HALF)) ||
      ((qvga_y == cy_g) && (qvga_x + CROSS_HALF >= cx_g) && (qvga_x <= cx_g + CROSS_HALF))
  );

  wire on_cross_b = box_b_valid && DE && (
      ((qvga_x == cx_b) && (qvga_y + CROSS_HALF >= cy_b) && (qvga_y <= cy_b + CROSS_HALF)) ||
      ((qvga_y == cy_b) && (qvga_x + CROSS_HALF >= cx_b) && (qvga_x <= cx_b + CROSS_HALF))
  );

  // =========================================================================
  // text_overlay 3개 인스턴스 (QVGA 좌표 기준)
  // 각 텍스트 블록 높이 = CHAR_H(16) × NUM_ROW(2) + 여백(4) = 36픽셀
  // Y_START: R=4, G=44, B=84
  // =========================================================================
  logic text_on_r, bg_on_r;
  logic [3:0] tR_r, tR_g, tR_b;

  text_overlay #(
      .X_START(10'd4),
      .Y_START(10'd4)
  ) u_text_r (
      .x_pixel    (qvga_x),           // QVGA 좌표 직접 입력
      .y_pixel    ({2'b00, qvga_y}),
      .DE         (DE),
      .center_x   (cx_r),
      .center_y   (cy_r),
      .coord_valid(box_r_valid),
      .text_on    (text_on_r),
      .text_r     (tR_r),
      .text_g     (tR_g),
      .text_b     (tR_b),
      .bg_on      (bg_on_r)
  );

  logic text_on_g, bg_on_g;
  logic [3:0] tG_r, tG_g, tG_b;

  //   text_overlay #(
  //       .X_START(10'd4),
  //       .Y_START(10'd44)
  //   ) u_text_g (
  //       .x_pixel    (qvga_x),
  //       .y_pixel    ({2'b00, qvga_y}),
  //       .DE         (DE),
  //       .center_x   (cx_g),
  //       .center_y   (cy_g),
  //       .coord_valid(box_g_valid),
  //       .text_on    (text_on_g),
  //       .text_r     (tG_r),
  //       .text_g     (tG_g),
  //       .text_b     (tG_b),
  //       .bg_on      (bg_on_g)
  //   );

  logic text_on_b, bg_on_b;
  logic [3:0] tB_r, tB_g, tB_b;

  //   text_overlay #(
  //       .X_START(10'd4),
  //       .Y_START(10'd84)
  //   ) u_text_b (
  //       .x_pixel    (qvga_x),
  //       .y_pixel    ({2'b00, qvga_y}),
  //       .DE         (DE),
  //       .center_x   (cx_b),
  //       .center_y   (cy_b),
  //       .coord_valid(box_b_valid),
  //       .text_on    (text_on_b),
  //       .text_r     (tB_r),
  //       .text_g     (tB_g),
  //       .text_b     (tB_b),
  //       .bg_on      (bg_on_b)
  //   );

  // =========================================================================
  // 최종 출력
  // =========================================================================
  wire any_bg = bg_on_r || bg_on_g || bg_on_b;

  always_comb begin
    if (!DE) begin
      port_red   = 4'h0;
      port_green = 4'h0;
      port_blue  = 4'h0;
    end else if (text_on_r) begin  // R 텍스트: 빨간색
      port_red   = 4'hF;
      port_green = 4'h0;
      port_blue  = 4'h0;
    end else if (text_on_g) begin  // G 텍스트: 초록색
      port_red   = 4'h0;
      port_green = 4'hF;
      port_blue  = 4'h0;
    end else if (text_on_b) begin  // B 텍스트: 파란색
      port_red   = 4'h0;
      port_green = 4'h0;
      port_blue  = 4'hF;
    end else if (any_bg) begin  // 텍스트 배경: 어둡게
      port_red   = img_r >> 2;
      port_green = img_g >> 2;
      port_blue  = img_b >> 2;
    end else if (on_cross_r) begin
      port_red   = 4'hF;
      port_green = 4'h0;
      port_blue  = 4'h0;
    end else if (on_cross_g) begin
      port_red   = 4'h0;
      port_green = 4'hF;
      port_blue  = 4'h0;
    end else if (on_cross_b) begin
      port_red   = 4'h0;
      port_green = 4'h0;
      port_blue  = 4'hF;
    end else if (on_box_r) begin
      port_red   = 4'hF;
      port_green = 4'h0;
      port_blue  = 4'h0;
    end else if (on_box_g) begin
      port_red   = 4'h0;
      port_green = 4'hF;
      port_blue  = 4'h0;
    end else if (on_box_b) begin
      port_red   = 4'h0;
      port_green = 4'h0;
      port_blue  = 4'hF;
    end else begin
      port_red   = img_r;
      port_green = img_g;
      port_blue  = img_b;
    end
  end

endmodule
