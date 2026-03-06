`timescale 1ns / 1ps

module VGA_EdgeDetector #(
    parameter IMG_W       = 320,
    parameter IMG_H       = 240,
    parameter EDGE_THRESH = 8'd20  // Sobel 크기 임계값 (조정 가능)
) (
    input  logic                       pclk,
    input  logic                       reset,
    // OV7670_MemController 신호 감시 (ColorDetector와 동일 신호)
    input  logic                       we,
    input  logic [$clog2(320*240)-1:0] wAddr,
    input  logic [               15:0] wData,
    // 현재 픽셀 좌표 (ColorDetector와 공유)
    input  logic [                8:0] px,
    input  logic [                7:0] py,
    // Edge 픽셀 여부 출력
    output logic                       is_edge,
    output logic [                8:0] edge_px,  // edge 픽셀의 x (1클럭 지연)
    output logic [                7:0] edge_py   // edge 픽셀의 y
);

  // ── 1. Grayscale 변환 (RGB565 → 8bit gray) ──────────────────
  // gray ≈ (R*3 + G*6 + B*1) / 10  (shift로 근사)
  logic [3:0] r, g, b;
  logic [7:0] gray;
  assign r = wData[15:12];
  assign g = wData[10:7];
  assign b = wData[4:1];
  // 4bit → 8bit 스케일 후 가중 평균
  assign gray = (({r, r} * 3) + ({g, g} * 6) + ({b, b})) >> 3;

  // ── 2. 라인버퍼 (3줄) ────────────────────────────────────────
  // BRAM으로 추론되도록 2D 배열 사용
  logic [7:0] line0[0:IMG_W-1];
  logic [7:0] line1[0:IMG_W-1];
  logic [7:0] line2[0:IMG_W-1];

  logic [1:0] line_sel;  // 현재 write 중인 줄 (0,1,2 순환)

  always_ff @(posedge pclk) begin
    if (reset) begin
      line_sel <= 0;
    end else if (we) begin
      // 어느 줄에 쓸지 결정
      case (line_sel)
        2'd0: line0[px] <= gray;
        2'd1: line1[px] <= gray;
        2'd2: line2[px] <= gray;
      endcase
      // 줄 끝에서 line_sel 증가
      if (px == IMG_W - 1) line_sel <= (line_sel == 2) ? 0 : line_sel + 1;
    end
  end

  // ── 3. 3x3 윈도우 픽셀 읽기 ──────────────────────────────────
  // 현재 픽셀 (px, py) 기준으로 이전 2줄 + 현재 줄에서 읽음
  // line_sel:     현재 줄 (row2)
  // line_sel-1:   한 줄 위 (row1)
  // line_sel-2:   두 줄 위 (row0)

  logic [1:0] row0_sel, row1_sel, row2_sel;
  assign row2_sel = line_sel;
  assign row1_sel = (line_sel == 0) ? 2 : line_sel - 1;
  assign row0_sel = (line_sel == 1) ? 2 : (line_sel == 0) ? 1 : 0;

  // px-1, px, px+1 (경계 클램핑)
  logic [8:0] px_m1, px_p1;
  assign px_m1 = (px == 0) ? 9'd0 : px - 1;
  assign px_p1 = (px == IMG_W - 1) ? IMG_W - 1 : px + 1;

  // 3x3 윈도우
  logic [7:0] p00, p01, p02;
  logic [7:0] p10, p11, p12;
  logic [7:0] p20, p21, p22;

  always_comb begin
    case (row0_sel)
      2'd0: begin
        p00 = line0[px_m1];
        p01 = line0[px];
        p02 = line0[px_p1];
      end
      2'd1: begin
        p00 = line1[px_m1];
        p01 = line1[px];
        p02 = line1[px_p1];
      end
      2'd2: begin
        p00 = line2[px_m1];
        p01 = line2[px];
        p02 = line2[px_p1];
      end
      default: begin
        p00 = 0;
        p01 = 0;
        p02 = 0;
      end
    endcase
    case (row1_sel)
      2'd0: begin
        p10 = line0[px_m1];
        p11 = line0[px];
        p12 = line0[px_p1];
      end
      2'd1: begin
        p10 = line1[px_m1];
        p11 = line1[px];
        p12 = line1[px_p1];
      end
      2'd2: begin
        p10 = line2[px_m1];
        p11 = line2[px];
        p12 = line2[px_p1];
      end
      default: begin
        p10 = 0;
        p11 = 0;
        p12 = 0;
      end
    endcase
    case (row2_sel)
      2'd0: begin
        p20 = line0[px_m1];
        p21 = line0[px];
        p22 = line0[px_p1];
      end
      2'd1: begin
        p20 = line1[px_m1];
        p21 = line1[px];
        p22 = line1[px_p1];
      end
      2'd2: begin
        p20 = line2[px_m1];
        p21 = line2[px];
        p22 = line2[px_p1];
      end
      default: begin
        p20 = 0;
        p21 = 0;
        p22 = 0;
      end
    endcase
  end

  // ── 4. Sobel 연산 ─────────────────────────────────────────────
  // Gx = (p02+2*p12+p22) - (p00+2*p10+p20)
  // Gy = (p20+2*p21+p22) - (p00+2*p01+p02)
  logic signed [10:0] Gx, Gy;
  logic [10:0] Gx_abs, Gy_abs;
  logic [11:0] G_mag;

  assign Gx = ($signed(
      {1'b0, p02}
  ) + $signed(
      {1'b0, p12, 1'b0}
  ) + $signed(
      {1'b0, p22}
  )) - ($signed(
      {1'b0, p00}
  ) + $signed(
      {1'b0, p10, 1'b0}
  ) + $signed(
      {1'b0, p20}
  ));
  assign Gy = ($signed(
      {1'b0, p20}
  ) + $signed(
      {1'b0, p21, 1'b0}
  ) + $signed(
      {1'b0, p22}
  )) - ($signed(
      {1'b0, p00}
  ) + $signed(
      {1'b0, p01, 1'b0}
  ) + $signed(
      {1'b0, p02}
  ));

  assign Gx_abs = Gx[10] ? -Gx : Gx;
  assign Gy_abs = Gy[10] ? -Gy : Gy;
  assign G_mag = Gx_abs + Gy_abs;  // |Gx| + |Gy| (sqrt 근사)

  // ── 5. Edge 판단 및 출력 (1클럭 레지스터) ─────────────────────
  always_ff @(posedge pclk or posedge reset) begin
    if (reset) begin
      is_edge <= 0;
      edge_px <= 0;
      edge_py <= 0;
    end else begin
      if (we && py >= 2 && py < IMG_H - 1 && px >= 1 && px < IMG_W - 1) begin
        is_edge <= (G_mag > {4'b0, EDGE_THRESH});
      end

      is_edge <= (we && py >= 2) ? (G_mag > {4'b0, EDGE_THRESH}) : 1'b0;
      edge_px <= px;
      edge_py <= py;
    end
  end

endmodule
