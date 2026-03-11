`timescale 1ns / 1ps
//=============================================================================
// text_overlay — 좌표값을 화면 좌상단에 텍스트로 표시 (QVGA 320×240 기준)
//
// 표시 형식:
//   Line 0: "X:123"
//   Line 1: "Y:089"
//
// 합성 가능 BCD 변환 (나눗셈 제거 → 뺄셈 반복)
//=============================================================================
module text_overlay #(
    parameter X_START = 10'd8,
    parameter Y_START = 10'd8
) (
    input logic [9:0] x_pixel,  // QVGA 좌표 0~319
    input logic [9:0] y_pixel,  // QVGA 좌표 0~239
    input logic       DE,

    input logic [8:0] center_x,    // 0~319
    input logic [7:0] center_y,    // 0~239
    input logic       coord_valid,

    output logic       text_on,
    output logic [3:0] text_r,
    output logic [3:0] text_g,
    output logic [3:0] text_b,
    output logic       bg_on
);

  // =========================================================================
  // 텍스트 영역 정의 (QVGA 기준, 1× 스케일: 글자 8×16)
  // =========================================================================
  localparam CHAR_W = 10'd8;
  localparam CHAR_H = 10'd16;
  localparam NUM_COL = 5;  // "X:123" = 5글자
  localparam NUM_ROW = 2;  // 2줄
  localparam TEXT_W = CHAR_W * NUM_COL;  // 40
  localparam TEXT_H = CHAR_H * NUM_ROW;  // 32
  localparam BG_PAD = 10'd2;

  // 배경 영역
  wire in_bg = DE &&
      (x_pixel >= X_START - BG_PAD) && (x_pixel < X_START + TEXT_W + BG_PAD) &&
      (y_pixel >= Y_START - BG_PAD) && (y_pixel < Y_START + TEXT_H + BG_PAD);
  assign bg_on = in_bg;

  // 텍스트 영역
  wire in_text = DE &&
      (x_pixel >= X_START) && (x_pixel < X_START + TEXT_W) &&
      (y_pixel >= Y_START) && (y_pixel < Y_START + TEXT_H);

  // =========================================================================
  // BCD 변환 — 뺄셈 반복 (나눗셈 없음, 합성 가능)
  // center_x: 0~319 → hundreds(0~3), tens(0~9), ones(0~9)
  // center_y: 0~239 → hundreds(0~2), tens(0~9), ones(0~9)
  // =========================================================================
  logic [3:0] x_hundreds, x_tens, x_ones;
  logic [3:0] y_hundreds, y_tens, y_ones;

  always_comb begin : bcd_x
    logic [8:0] tmp;
    tmp = center_x;

    // 백의 자리
    if (tmp >= 9'd300) begin
      x_hundreds = 4'd3;
      tmp = tmp - 9'd300;
    end else if (tmp >= 9'd200) begin
      x_hundreds = 4'd2;
      tmp = tmp - 9'd200;
    end else if (tmp >= 9'd100) begin
      x_hundreds = 4'd1;
      tmp = tmp - 9'd100;
    end else begin
      x_hundreds = 4'd0;
    end

    // 십의 자리
    if (tmp >= 9'd90) begin
      x_tens = 4'd9;
      tmp = tmp - 9'd90;
    end else if (tmp >= 9'd80) begin
      x_tens = 4'd8;
      tmp = tmp - 9'd80;
    end else if (tmp >= 9'd70) begin
      x_tens = 4'd7;
      tmp = tmp - 9'd70;
    end else if (tmp >= 9'd60) begin
      x_tens = 4'd6;
      tmp = tmp - 9'd60;
    end else if (tmp >= 9'd50) begin
      x_tens = 4'd5;
      tmp = tmp - 9'd50;
    end else if (tmp >= 9'd40) begin
      x_tens = 4'd4;
      tmp = tmp - 9'd40;
    end else if (tmp >= 9'd30) begin
      x_tens = 4'd3;
      tmp = tmp - 9'd30;
    end else if (tmp >= 9'd20) begin
      x_tens = 4'd2;
      tmp = tmp - 9'd20;
    end else if (tmp >= 9'd10) begin
      x_tens = 4'd1;
      tmp = tmp - 9'd10;
    end else begin
      x_tens = 4'd0;
    end

    // 일의 자리
    x_ones = tmp[3:0];
  end

  always_comb begin : bcd_y
    logic [7:0] tmp;
    tmp = center_y;

    // 백의 자리
    if (tmp >= 8'd200) begin
      y_hundreds = 4'd2;
      tmp = tmp - 8'd200;
    end else if (tmp >= 8'd100) begin
      y_hundreds = 4'd1;
      tmp = tmp - 8'd100;
    end else begin
      y_hundreds = 4'd0;
    end

    // 십의 자리
    if (tmp >= 8'd90) begin
      y_tens = 4'd9;
      tmp = tmp - 8'd90;
    end else if (tmp >= 8'd80) begin
      y_tens = 4'd8;
      tmp = tmp - 8'd80;
    end else if (tmp >= 8'd70) begin
      y_tens = 4'd7;
      tmp = tmp - 8'd70;
    end else if (tmp >= 8'd60) begin
      y_tens = 4'd6;
      tmp = tmp - 8'd60;
    end else if (tmp >= 8'd50) begin
      y_tens = 4'd5;
      tmp = tmp - 8'd50;
    end else if (tmp >= 8'd40) begin
      y_tens = 4'd4;
      tmp = tmp - 8'd40;
    end else if (tmp >= 8'd30) begin
      y_tens = 4'd3;
      tmp = tmp - 8'd30;
    end else if (tmp >= 8'd20) begin
      y_tens = 4'd2;
      tmp = tmp - 8'd20;
    end else if (tmp >= 8'd10) begin
      y_tens = 4'd1;
      tmp = tmp - 8'd10;
    end else begin
      y_tens = 4'd0;
    end

    // 일의 자리
    y_ones = tmp[3:0];
  end

  // =========================================================================
  // 현재 스캔 위치에서 문자/행/열 결정
  // =========================================================================
  wire  [9:0] local_x = x_pixel - X_START;
  wire  [9:0] local_y = y_pixel - Y_START;

  wire  [2:0] font_col = local_x[2:0];  // 0~7  (CHAR_W=8)
  wire  [3:0] font_row = local_y[3:0];  // 0~15 (CHAR_H=16)
  wire  [2:0] char_col_idx = local_x[5:3];  // 0~4  (40÷8=5)
  wire        char_row_idx = local_y[4];  // 0~1  (32÷16=2)

  // =========================================================================
  // 문자 코드 결정
  // =========================================================================
  logic [3:0] char_code;

  always_comb begin
    char_code = 4'd13;  // 기본: 공백

    case ({
      char_row_idx, char_col_idx
    })
      // Line 0: X:nnn
      {1'b0, 3'd0} : char_code = 4'd10;  // X
      {1'b0, 3'd1} : char_code = 4'd12;  // :
      {1'b0, 3'd2} : char_code = coord_valid ? x_hundreds : 4'd0;
      {1'b0, 3'd3} : char_code = coord_valid ? x_tens : 4'd0;
      {1'b0, 3'd4} : char_code = coord_valid ? x_ones : 4'd0;
      // Line 1: Y:nnn
      {1'b1, 3'd0} : char_code = 4'd11;  // Y
      {1'b1, 3'd1} : char_code = 4'd12;  // :
      {1'b1, 3'd2} : char_code = coord_valid ? y_hundreds : 4'd0;
      {1'b1, 3'd3} : char_code = coord_valid ? y_tens : 4'd0;
      {1'b1, 3'd4} : char_code = coord_valid ? y_ones : 4'd0;
      default:       char_code = 4'd13;
    endcase
  end

  // =========================================================================
  // 폰트 ROM 인스턴스
  // =========================================================================
  logic [7:0] font_pattern;

  font_rom u_font (
      .char_code(char_code),
      .row      (font_row),
      .pattern  (font_pattern)
  );

  // =========================================================================
  // 픽셀 판별 및 출력
  // =========================================================================
  wire pixel_on = in_text && font_pattern[7-font_col];

  assign text_on = pixel_on;
  assign text_r  = coord_valid ? 4'hF : 4'h8;
  assign text_g  = coord_valid ? 4'hF : 4'h8;
  assign text_b  = coord_valid ? 4'hF : 4'h8;

endmodule
