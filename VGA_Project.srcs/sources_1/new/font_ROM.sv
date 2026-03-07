`timescale 1ns / 1ps
//=============================================================================
// font_rom — 8×16 비트맵 폰트 (숫자 0~9, 문자 X Y : 공백)
//
// 사용법: font_rom에 {문자코드, 행번호}를 주면 8비트 패턴 반환
//   char_code: 0~9 = 숫자, 10='X', 11='Y', 12=':', 13=' '
//   row: 0~15 (16행)
//   pattern: 8비트, MSB=왼쪽, 1=픽셀ON, 0=OFF
//=============================================================================
module font_rom (
    input  logic [3:0] char_code,  // 0~13
    input  logic [3:0] row,        // 0~15
    output logic [7:0] pattern
);

  always_comb begin
    pattern = 8'h00;
    case (char_code)
      // ── 0 ──
      4'd0:
      case (row)
        4'd2: pattern = 8'b00111100;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b01100110;
        4'd5: pattern = 8'b01101110;
        4'd6: pattern = 8'b01110110;
        4'd7: pattern = 8'b01100110;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b00111100;
        default: pattern = 8'h00;
      endcase
      // ── 1 ──
      4'd1:
      case (row)
        4'd2: pattern = 8'b00011000;
        4'd3: pattern = 8'b00111000;
        4'd4: pattern = 8'b00011000;
        4'd5: pattern = 8'b00011000;
        4'd6: pattern = 8'b00011000;
        4'd7: pattern = 8'b00011000;
        4'd8: pattern = 8'b00011000;
        4'd9: pattern = 8'b01111110;
        default: pattern = 8'h00;
      endcase
      // ── 2 ──
      4'd2:
      case (row)
        4'd2: pattern = 8'b00111100;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b00000110;
        4'd5: pattern = 8'b00001100;
        4'd6: pattern = 8'b00011000;
        4'd7: pattern = 8'b00110000;
        4'd8: pattern = 8'b01100000;
        4'd9: pattern = 8'b01111110;
        default: pattern = 8'h00;
      endcase
      // ── 3 ──
      4'd3:
      case (row)
        4'd2: pattern = 8'b00111100;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b00000110;
        4'd5: pattern = 8'b00011100;
        4'd6: pattern = 8'b00000110;
        4'd7: pattern = 8'b00000110;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b00111100;
        default: pattern = 8'h00;
      endcase
      // ── 4 ──
      4'd4:
      case (row)
        4'd2: pattern = 8'b00001100;
        4'd3: pattern = 8'b00011100;
        4'd4: pattern = 8'b00101100;
        4'd5: pattern = 8'b01001100;
        4'd6: pattern = 8'b01111110;
        4'd7: pattern = 8'b00001100;
        4'd8: pattern = 8'b00001100;
        4'd9: pattern = 8'b00001100;
        default: pattern = 8'h00;
      endcase
      // ── 5 ──
      4'd5:
      case (row)
        4'd2: pattern = 8'b01111110;
        4'd3: pattern = 8'b01100000;
        4'd4: pattern = 8'b01100000;
        4'd5: pattern = 8'b01111100;
        4'd6: pattern = 8'b00000110;
        4'd7: pattern = 8'b00000110;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b00111100;
        default: pattern = 8'h00;
      endcase
      // ── 6 ──
      4'd6:
      case (row)
        4'd2: pattern = 8'b00111100;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b01100000;
        4'd5: pattern = 8'b01111100;
        4'd6: pattern = 8'b01100110;
        4'd7: pattern = 8'b01100110;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b00111100;
        default: pattern = 8'h00;
      endcase
      // ── 7 ──
      4'd7:
      case (row)
        4'd2: pattern = 8'b01111110;
        4'd3: pattern = 8'b00000110;
        4'd4: pattern = 8'b00001100;
        4'd5: pattern = 8'b00011000;
        4'd6: pattern = 8'b00011000;
        4'd7: pattern = 8'b00011000;
        4'd8: pattern = 8'b00011000;
        4'd9: pattern = 8'b00011000;
        default: pattern = 8'h00;
      endcase
      // ── 8 ──
      4'd8:
      case (row)
        4'd2: pattern = 8'b00111100;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b01100110;
        4'd5: pattern = 8'b00111100;
        4'd6: pattern = 8'b01100110;
        4'd7: pattern = 8'b01100110;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b00111100;
        default: pattern = 8'h00;
      endcase
      // ── 9 ──
      4'd9:
      case (row)
        4'd2: pattern = 8'b00111100;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b01100110;
        4'd5: pattern = 8'b00111110;
        4'd6: pattern = 8'b00000110;
        4'd7: pattern = 8'b00000110;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b00111100;
        default: pattern = 8'h00;
      endcase
      // ── X ──
      4'd10:
      case (row)
        4'd2: pattern = 8'b01100110;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b00111100;
        4'd5: pattern = 8'b00011000;
        4'd6: pattern = 8'b00011000;
        4'd7: pattern = 8'b00111100;
        4'd8: pattern = 8'b01100110;
        4'd9: pattern = 8'b01100110;
        default: pattern = 8'h00;
      endcase
      // ── Y ──
      4'd11:
      case (row)
        4'd2: pattern = 8'b01100110;
        4'd3: pattern = 8'b01100110;
        4'd4: pattern = 8'b01100110;
        4'd5: pattern = 8'b00111100;
        4'd6: pattern = 8'b00011000;
        4'd7: pattern = 8'b00011000;
        4'd8: pattern = 8'b00011000;
        4'd9: pattern = 8'b00011000;
        default: pattern = 8'h00;
      endcase
      // ── : ──
      4'd12:
      case (row)
        4'd4: pattern = 8'b00011000;
        4'd5: pattern = 8'b00011000;
        4'd7: pattern = 8'b00011000;
        4'd8: pattern = 8'b00011000;
        default: pattern = 8'h00;
      endcase
      // ── 공백 ──
      4'd13: pattern = 8'h00;

      default: pattern = 8'h00;
    endcase
  end
endmodule
