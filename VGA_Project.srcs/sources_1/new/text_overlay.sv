`timescale 1ns / 1ps
//=============================================================================
// text_overlay — 좌표값을 화면 좌상단에 텍스트로 표시
//
// 표시 형식:
//   Line 0: "X:123"   (center_x, 최대 3자리)
//   Line 1: "Y:089"   (center_y, 최대 3자리)
//
// 위치: VGA 좌표 (8, 8) 부터 시작
// 글자 크기: 8×16 픽셀 (×2 스케일 = 16×32)
// 배경: 반투명 검정 박스
//=============================================================================
module text_overlay (
    input logic [9:0] x_pixel,  // VGA 좌표 0~639
    input logic [9:0] y_pixel,  // VGA 좌표 0~479
    input logic       DE,

    // 표시할 좌표 (QVGA 기준 0~319, 0~239)
    input logic [8:0] center_x,
    input logic [7:0] center_y,
    input logic       coord_valid,

    // 텍스트 픽셀 출력
    output logic       text_on,  // 1=이 픽셀에 텍스트 있음
    output logic [3:0] text_r,
    output logic [3:0] text_g,
    output logic [3:0] text_b,
    output logic       bg_on     // 1=배경 영역 안
);

  // =========================================================================
  // 텍스트 영역 정의
  // =========================================================================
  // 2배 스케일: 글자 1개 = 16×32 VGA 픽셀
  // 5글자 × 2줄 = 가로 80픽셀, 세로 64픽셀
  localparam X_START = 10'd8;
  localparam Y_START = 10'd8;
  localparam CHAR_W = 10'd16;  // 8 × 2(스케일)
  localparam CHAR_H = 10'd32;  // 16 × 2(스케일)
  localparam NUM_COL = 5;  // "X:123" = 5글자
  localparam NUM_ROW = 2;  // 2줄
  localparam TEXT_W = CHAR_W * NUM_COL;  // 80
  localparam TEXT_H = CHAR_H * NUM_ROW;  // 64
  localparam BG_PAD = 10'd4;  // 배경 패딩

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
  // 좌표 → 3자리 십진수 분해
  // =========================================================================
  // center_x: 0~319
  wire [3:0] x_hundreds = center_x / 100;
  wire [3:0] x_tens = (center_x / 10) % 10;
  wire [3:0] x_ones = center_x % 10;

  // center_y: 0~239
  wire [3:0] y_hundreds = center_y / 100;
  wire [3:0] y_tens = (center_y / 10) % 10;
  wire [3:0] y_ones = center_y % 10;

  // =========================================================================
  // 현재 스캔 위치에서 문자/행/열 결정
  // =========================================================================
  wire [9:0] local_x = x_pixel - X_START;  // 텍스트 영역 내 상대 좌표
  wire [9:0] local_y = y_pixel - Y_START;

  // 2배 스케일 → 실제 폰트 좌표
  wire [2:0] font_col = local_x[3:1];  // 0~7 (16÷2=8 → [3:1])
  wire [3:0] font_row = local_y[4:1];  // 0~15 (32÷2=16 → [4:1])

  // 몇 번째 글자인가
  wire [2:0] char_col_idx = local_x[6:4];  // 0~4 (80÷16=5)
  wire char_row_idx = local_y[5];  // 0 또는 1 (64÷32=2)

  // =========================================================================
  // 문자 코드 결정
  // char_code: 0~9=숫자, 10=X, 11=Y, 12=:, 13=공백
  // =========================================================================
  logic [3:0] char_code;

  always_comb begin
    char_code = 4'd13;  // 기본: 공백

    if (!coord_valid) begin
      // valid=0이면 모두 0 표시
      case ({
        char_row_idx, char_col_idx
      })
        {1'b0, 3'd0} : char_code = 4'd10;  // X
        {1'b0, 3'd1} : char_code = 4'd12;  // :
        {1'b0, 3'd2} : char_code = 4'd0;  // 0
        {1'b0, 3'd3} : char_code = 4'd0;  // 0
        {1'b0, 3'd4} : char_code = 4'd0;  // 0
        {1'b1, 3'd0} : char_code = 4'd11;  // Y
        {1'b1, 3'd1} : char_code = 4'd12;  // :
        {1'b1, 3'd2} : char_code = 4'd0;  // 0
        {1'b1, 3'd3} : char_code = 4'd0;  // 0
        {1'b1, 3'd4} : char_code = 4'd0;  // 0
        default:       char_code = 4'd13;
      endcase
    end else begin
      case ({
        char_row_idx, char_col_idx
      })
        // Line 0: X:nnn
        {1'b0, 3'd0} : char_code = 4'd10;  // X
        {1'b0, 3'd1} : char_code = 4'd12;  // :
        {1'b0, 3'd2} : char_code = x_hundreds;  // 백의 자리
        {1'b0, 3'd3} : char_code = x_tens;  // 십의 자리
        {1'b0, 3'd4} : char_code = x_ones;  // 일의 자리
        // Line 1: Y:nnn
        {1'b1, 3'd0} : char_code = 4'd11;  // Y
        {1'b1, 3'd1} : char_code = 4'd12;  // :
        {1'b1, 3'd2} : char_code = y_hundreds;
        {1'b1, 3'd3} : char_code = y_tens;
        {1'b1, 3'd4} : char_code = y_ones;
        default:       char_code = 4'd13;
      endcase
    end
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
  // 현재 픽셀이 글자 위인지 판별
  // font_pattern의 MSB부터: bit[7]=왼쪽 끝, bit[0]=오른쪽 끝
  // font_col=0 → bit[7], font_col=7 → bit[0]
  // =========================================================================
  wire pixel_on = in_text && font_pattern[7-font_col];

  assign text_on = pixel_on;

  // 텍스트 색상: 흰색 (valid), 회색 (invalid)
  assign text_r  = coord_valid ? 4'hF : 4'h8;
  assign text_g  = coord_valid ? 4'hF : 4'h8;
  assign text_b  = coord_valid ? 4'hF : 4'h8;

endmodule
