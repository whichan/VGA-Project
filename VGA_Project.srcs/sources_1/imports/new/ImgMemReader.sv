`timescale 1ns / 1ps
// ImgMemReader — 업스케일 보간 + 바운딩 박스 + 좌표 텍스트 표시
//
// 기능:
//   1. 320×240 → 640×480 업스케일 (가로 바이리니어 보간)
//   2. 바운딩 박스 테두리 오버레이 (빨간색)
//   3. 중심점 크로스헤어 (노란색)
//   4. 좌상단 좌표 텍스트 표시 (X:nnn Y:nnn)
module ImgMemReader #(
    parameter IMG_SIZE = 320 * 240,
    parameter IMG_W    = 320,
    parameter IMG_H    = 240
) (
    input  logic                        clk,
    input  logic                        DE,
    input  logic [                 9:0] x_pixel,
    input  logic [                 9:0] y_pixel,
    input  logic [                15:0] imgData,
    output logic [$clog2(IMG_SIZE)-1:0] addr,
    output logic [                 3:0] port_red,
    output logic [                 3:0] port_green,
    output logic [                 3:0] port_blue,
    input  logic [                 8:0] box_x_min,
    input  logic [                 8:0] box_x_max,
    input  logic [                 7:0] box_y_min,
    input  logic [                 7:0] box_y_max,
    input  logic                        box_valid
    //xpixel, ypixel 추가
    // output logic [                 9:0] out_center_x,
    // output logic [                 9:0] out_center_y,
    // output logic                        out_valid      //box valid 전달
);



  // QVGA 좌표 변환
  wire [8:0] qvga_x = x_pixel[9:1];
  wire [7:0] qvga_y = y_pixel[9:1];

  // BRAM 주소 생성 (보간용)
  wire [8:0] read_x = x_pixel[0] ? (qvga_x + 1) : qvga_x;
  wire [8:0] clamped_x = (read_x > (IMG_W - 1)) ? (IMG_W - 1) : read_x;
  assign addr = DE ? (IMG_W * qvga_y + clamped_x) : '0;

  // RGB565 → RGB444
  wire [3:0] cur_r = imgData[15:12];
  wire [3:0] cur_g = imgData[10:7];
  wire [3:0] cur_b = imgData[4:1];

  // 이전 픽셀 저장 (보간용)
  reg [3:0] prev_r, prev_g, prev_b;
  always_ff @(posedge clk) begin
    if (!DE) begin
      prev_r <= 4'd0;
      prev_g <= 4'd0;
      prev_b <= 4'd0;
    end else if (!x_pixel[0]) begin
      prev_r <= cur_r;
      prev_g <= cur_g;
      prev_b <= cur_b;
    end
  end

  // 보간 평균
  wire [3:0] avg_r = ({1'b0, prev_r} + {1'b0, cur_r}) >> 1;
  wire [3:0] avg_g = ({1'b0, prev_g} + {1'b0, cur_g}) >> 1;
  wire [3:0] avg_b = ({1'b0, prev_b} + {1'b0, cur_b}) >> 1;

  wire [3:0] img_r = x_pixel[0] ? avg_r : cur_r;
  wire [3:0] img_g = x_pixel[0] ? avg_g : cur_g;
  wire [3:0] img_b = x_pixel[0] ? avg_b : cur_b;

  // 바운딩 박스 (×2 스케일)
  wire [9:0] bx_min = {box_x_min, 1'b0};
  wire [9:0] bx_max = {box_x_max, 1'b0} + 1;
  wire [9:0] by_min = {box_y_min, 1'b0};
  wire [9:0] by_max = {box_y_max, 1'b0} + 1;

  wire on_left   = (x_pixel >= bx_min) && (x_pixel <= bx_min + 1)
                     && (y_pixel >= by_min) && (y_pixel <= by_max);
  wire on_right  = (x_pixel >= bx_max - 1) && (x_pixel <= bx_max)
                     && (y_pixel >= by_min) && (y_pixel <= by_max);
  wire on_top    = (y_pixel >= by_min) && (y_pixel <= by_min + 1)
                     && (x_pixel >= bx_min) && (x_pixel <= bx_max);
  wire on_bottom = (y_pixel >= by_max - 1) && (y_pixel <= by_max)
                     && (x_pixel >= bx_min) && (x_pixel <= bx_max);

  wire on_box = box_valid && (on_left || on_right || on_top || on_bottom);

  // 중심점 십자가
  wire [9:0] cx = (bx_min + bx_max) >> 1;
  wire [9:0] cy = (by_min + by_max) >> 1;

  wire on_cross = box_valid && (
        ((x_pixel == cx) && (y_pixel >= cy - 5) && (y_pixel <= cy + 5)) ||
        ((y_pixel == cy) && (x_pixel >= cx - 5) && (x_pixel <= cx + 5))
    );

  // 중심점 QVGA 좌표 (텍스트 표시용)
  wire [9:0] center_x_val = (box_x_min + box_x_max) >> 1;
  wire [8:0] center_y_val = (box_y_min + box_y_max) >> 1;

  // 텍스트 오버레이 인스턴스
  logic text_on;
  logic [3:0] text_r, text_g, text_b;
  logic bg_on;

  //spi master로 현재 좌표 중심값 전달
  //   assign out_center_x = center_x_val;
  //   assign out_center_y = center_y_val;
  //   assign out_valid = box_valid;

  text_overlay u_text_overlay (
      .x_pixel    (x_pixel),
      .y_pixel    (y_pixel),
      .DE         (DE),
      .center_x   (center_x_val),
      .center_y   (center_y_val),
      .coord_valid(box_valid),
      .text_on    (text_on),
      .text_r     (text_r),
      .text_g     (text_g),
      .text_b     (text_b),
      .bg_on      (bg_on)
  );

  // 최종 출력
  // 우선순위: 텍스트 > 텍스트배경 > 크로스헤어 > 박스 > 보간영상
  always_comb begin
    if (!DE) begin
      port_red   = 4'd0;
      port_green = 4'd0;
      port_blue  = 4'd0;
    end else if (text_on) begin
      port_red   = text_r;
      port_green = text_g;
      port_blue  = text_b;
    end else if (bg_on) begin
      port_red   = img_r >> 1;
      port_green = img_g >> 1;
      port_blue  = img_b >> 1;
    end else if (on_cross) begin
      port_red   = 4'hF;
      port_green = 4'hD;
      port_blue  = 4'h0;
    end else if (on_box) begin
      port_red   = 4'hF;
      port_green = 4'h0;
      port_blue  = 4'h0;
    end else begin
      port_red   = img_r;
      port_green = img_g;
      port_blue  = img_b;
    end
  end

endmodule
