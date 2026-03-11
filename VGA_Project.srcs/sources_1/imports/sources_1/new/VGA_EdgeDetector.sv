`timescale 1ns / 1ps
//가우시안 블러 추가
// Gaussian Blur(3x3) → Scharr 파이프라인

module VGA_EdgeDetector #(
    parameter IMG_W       = 320,
    parameter IMG_H       = 240,
    parameter EDGE_THRESH = 13'd800
) (
    input  logic                       pclk,
    input  logic                       reset,
    input  logic                       we,
    input  logic [$clog2(320*240)-1:0] wAddr,
    input  logic [               15:0] wData,
    input  logic [                8:0] px,
    input  logic [                7:0] py,
    output logic                       is_edge,
    output logic [                8:0] edge_px,
    output logic [                7:0] edge_py
);

  // ── 1. Red 채널 추출 ─────────────────────────────────────────
  logic [3:0] r;
  logic [7:0] red_val;
  assign r       = wData[15:12];
  assign red_val = {r, r};

  // ── 2. Gaussian 입력용 라인버퍼 (3줄) ────────────────────────
  logic [7:0] blur_line0[0:IMG_W-1];
  logic [7:0] blur_line1[0:IMG_W-1];
  logic [7:0] blur_line2[0:IMG_W-1];
  logic [1:0] blur_sel;

  always_ff @(posedge pclk) begin
    if (reset) begin
      blur_sel <= 0;
    end else if (we) begin
      case (blur_sel)
        2'd0: blur_line0[px] <= red_val;
        2'd1: blur_line1[px] <= red_val;
        2'd2: blur_line2[px] <= red_val;
      endcase
      if (px == IMG_W - 1) blur_sel <= (blur_sel == 2) ? 0 : blur_sel + 1;
    end
  end

  // ── 3. Gaussian 3x3 윈도우 읽기 ──────────────────────────────
  // 커널: [1 2 1] / [2 4 2] / [1 2 1]  (합=16, >>4로 정규화)
  logic [1:0] br0_sel, br1_sel, br2_sel;
  assign br2_sel = blur_sel;
  assign br1_sel = (blur_sel == 0) ? 2 : blur_sel - 1;
  assign br0_sel = (blur_sel == 1) ? 2 : (blur_sel == 0) ? 1 : 0;

  logic [8:0] bpx_m1, bpx_p1;
  assign bpx_m1 = (px == 0) ? 9'd0 : px - 1;
  assign bpx_p1 = (px == IMG_W - 1) ? IMG_W - 1 : px + 1;

  logic [7:0] b00, b01, b02;
  logic [7:0] b10, b11, b12;
  logic [7:0] b20, b21, b22;

  always_comb begin
    case (br0_sel)
      2'd0: begin
        b00 = blur_line0[bpx_m1];
        b01 = blur_line0[px];
        b02 = blur_line0[bpx_p1];
      end
      2'd1: begin
        b00 = blur_line1[bpx_m1];
        b01 = blur_line1[px];
        b02 = blur_line1[bpx_p1];
      end
      2'd2: begin
        b00 = blur_line2[bpx_m1];
        b01 = blur_line2[px];
        b02 = blur_line2[bpx_p1];
      end
      default: begin
        b00 = 0;
        b01 = 0;
        b02 = 0;
      end
    endcase
    case (br1_sel)
      2'd0: begin
        b10 = blur_line0[bpx_m1];
        b11 = blur_line0[px];
        b12 = blur_line0[bpx_p1];
      end
      2'd1: begin
        b10 = blur_line1[bpx_m1];
        b11 = blur_line1[px];
        b12 = blur_line1[bpx_p1];
      end
      2'd2: begin
        b10 = blur_line2[bpx_m1];
        b11 = blur_line2[px];
        b12 = blur_line2[bpx_p1];
      end
      default: begin
        b10 = 0;
        b11 = 0;
        b12 = 0;
      end
    endcase
    case (br2_sel)
      2'd0: begin
        b20 = blur_line0[bpx_m1];
        b21 = blur_line0[px];
        b22 = blur_line0[bpx_p1];
      end
      2'd1: begin
        b20 = blur_line1[bpx_m1];
        b21 = blur_line1[px];
        b22 = blur_line1[bpx_p1];
      end
      2'd2: begin
        b20 = blur_line2[bpx_m1];
        b21 = blur_line2[px];
        b22 = blur_line2[bpx_p1];
      end
      default: begin
        b20 = 0;
        b21 = 0;
        b22 = 0;
      end
    endcase
  end

  // ── 4. Gaussian 연산 및 scharr_line 저장 ─────────────────────
  // G = (b00 + 2*b01 + b02 + 2*b10 + 4*b11 + 2*b12
  //      + b20 + 2*b21 + b22) >> 4
  logic [11:0] blur_sum;
  logic [ 7:0] blur_out;

  assign blur_sum = b00 + (b01 << 1) + b02
                    + (b10 << 1) + (b11 << 2) + (b12 << 1)
                    + b20 + (b21 << 1) + b22;
  assign blur_out = blur_sum[11:4];  // >>4

  // Scharr용 라인버퍼 (3줄)
  logic [7:0] scharr_line0[0:IMG_W-1];
  logic [7:0] scharr_line1[0:IMG_W-1];
  logic [7:0] scharr_line2[0:IMG_W-1];
  logic [1:0] scharr_sel;
  logic [8:0] px_d;  // 1클럭 지연된 px (blur 결과 저장 위치)
  logic [7:0] py_d;

  always_ff @(posedge pclk) begin
    if (reset) begin
      scharr_sel <= 0;
      px_d <= 0;
      py_d <= 0;
    end else if (we) begin
      px_d <= px;
      py_d <= py;
      // blur_out을 scharr_line에 저장 (1클럭 지연: px_d 위치에)
      case (scharr_sel)
        2'd0: scharr_line0[px] <= blur_out;
        2'd1: scharr_line1[px] <= blur_out;
        2'd2: scharr_line2[px] <= blur_out;
      endcase
      if (px == IMG_W - 1) scharr_sel <= (scharr_sel == 2) ? 0 : scharr_sel + 1;
    end
  end

  // ── 5. Scharr 윈도우 읽기 ────────────────────────────────────
  logic [1:0] sr0_sel, sr1_sel, sr2_sel;
  assign sr2_sel = scharr_sel;
  assign sr1_sel = (scharr_sel == 0) ? 2 : scharr_sel - 1;
  assign sr0_sel = (scharr_sel == 1) ? 2 : (scharr_sel == 0) ? 1 : 0;

  logic [8:0] spx_m1, spx_p1;
  assign spx_m1 = (px == 0) ? 9'd0 : px - 1;
  assign spx_p1 = (px == IMG_W - 1) ? IMG_W - 1 : px + 1;

  logic [7:0] p00, p01, p02;
  logic [7:0] p10, p12;
  logic [7:0] p20, p21, p22;

  always_comb begin
    case (sr0_sel)
      2'd0: begin
        p00 = scharr_line0[spx_m1];
        p01 = scharr_line0[px];
        p02 = scharr_line0[spx_p1];
      end
      2'd1: begin
        p00 = scharr_line1[spx_m1];
        p01 = scharr_line1[px];
        p02 = scharr_line1[spx_p1];
      end
      2'd2: begin
        p00 = scharr_line2[spx_m1];
        p01 = scharr_line2[px];
        p02 = scharr_line2[spx_p1];
      end
      default: begin
        p00 = 0;
        p01 = 0;
        p02 = 0;
      end
    endcase
    case (sr1_sel)
      2'd0: begin
        p10 = scharr_line0[spx_m1];
        p12 = scharr_line0[spx_p1];
      end
      2'd1: begin
        p10 = scharr_line1[spx_m1];
        p12 = scharr_line1[spx_p1];
      end
      2'd2: begin
        p10 = scharr_line2[spx_m1];
        p12 = scharr_line2[spx_p1];
      end
      default: begin
        p10 = 0;
        p12 = 0;
      end
    endcase
    case (sr2_sel)
      2'd0: begin
        p20 = scharr_line0[spx_m1];
        p21 = scharr_line0[px];
        p22 = scharr_line0[spx_p1];
      end
      2'd1: begin
        p20 = scharr_line1[spx_m1];
        p21 = scharr_line1[px];
        p22 = scharr_line1[spx_p1];
      end
      2'd2: begin
        p20 = scharr_line2[spx_m1];
        p21 = scharr_line2[px];
        p22 = scharr_line2[spx_p1];
      end
      default: begin
        p20 = 0;
        p21 = 0;
        p22 = 0;
      end
    endcase
  end

  // ── 6. Scharr 연산 ───────────────────────────────────────────
  logic signed [13:0] Gx, Gy;
  logic [13:0] Gx_abs, Gy_abs;
  logic [14:0] G_mag;

  logic signed [10:0] p02s, p00s, p12s, p10s, p22s, p20s, p21s, p01s;
  assign p00s = {1'b0, p00};
  assign p01s = {1'b0, p01};
  assign p02s = {1'b0, p02};
  assign p10s = {1'b0, p10};
  assign p12s = {1'b0, p12};
  assign p20s = {1'b0, p20};
  assign p21s = {1'b0, p21};
  assign p22s = {1'b0, p22};

  assign Gx = ($signed(
      {p02s, 1'b0}
  ) + $signed(
      {3'b0, p02}
  )) - ($signed(
      {p00s, 1'b0}
  ) + $signed(
      {3'b0, p00}
  )) + ($signed(
      {p12s, 3'b0}
  ) + $signed(
      {p12s, 1'b0}
  )) - ($signed(
      {p10s, 3'b0}
  ) + $signed(
      {p10s, 1'b0}
  )) + ($signed(
      {p22s, 1'b0}
  ) + $signed(
      {3'b0, p22}
  )) - ($signed(
      {p20s, 1'b0}
  ) + $signed(
      {3'b0, p20}
  ));

  assign Gy = ($signed(
      {p20s, 1'b0}
  ) + $signed(
      {3'b0, p20}
  )) - ($signed(
      {p00s, 1'b0}
  ) + $signed(
      {3'b0, p00}
  )) + ($signed(
      {p21s, 3'b0}
  ) + $signed(
      {p21s, 1'b0}
  )) - ($signed(
      {p01s, 3'b0}
  ) + $signed(
      {p01s, 1'b0}
  )) + ($signed(
      {p22s, 1'b0}
  ) + $signed(
      {3'b0, p22}
  )) - ($signed(
      {p02s, 1'b0}
  ) + $signed(
      {3'b0, p02}
  ));

  assign Gx_abs = Gx[13] ? -Gx : Gx;
  assign Gy_abs = Gy[13] ? -Gy : Gy;
  assign G_mag = {1'b0, Gx_abs} + {1'b0, Gy_abs};

  // ── 7. Edge 판단 및 출력 ─────────────────────────────────────
  // Gaussian으로 1줄 지연되므로 py >= 3, px >= 2 보호
  always_ff @(posedge pclk or posedge reset) begin
    if (reset) begin
      is_edge <= 0;
      edge_px <= 0;
      edge_py <= 0;
    end else begin
      if (we && py >= 3 && py < IMG_H - 1 && px >= 2 && px < IMG_W - 1) begin
        is_edge <= (G_mag > {2'b0, EDGE_THRESH});
      end else begin
        is_edge <= 1'b0;
      end
      edge_px <= px;
      edge_py <= py;
    end
  end

endmodule

// `timescale 1ns / 1ps

// module VGA_EdgeDetector #(
//     parameter IMG_W       = 320,
//     parameter IMG_H       = 240,
//     parameter EDGE_THRESH = 13'd800  // Scharr는 계수가 크므로 임계값도 크게
// ) (
//     input  logic                       pclk,
//     input  logic                       reset,
//     input  logic                       we,
//     input  logic [$clog2(320*240)-1:0] wAddr,
//     input  logic [               15:0] wData,
//     input  logic [                8:0] px,
//     input  logic [                7:0] py,
//     output logic                       is_edge,
//     output logic [                8:0] edge_px,
//     output logic [                7:0] edge_py
// );

//     // ── 1. Red 채널 추출 (8bit) ───────────────────────────────────
//     logic [3:0] r;
//     logic [7:0] red_val;
//     assign r       = wData[15:12];
//     assign red_val = {r, r};  // 4bit → 8bit

//     // ── 2. 라인버퍼 (3줄) ────────────────────────────────────────
//     logic [7:0] line0[0:IMG_W-1];
//     logic [7:0] line1[0:IMG_W-1];
//     logic [7:0] line2[0:IMG_W-1];
//     logic [1:0] line_sel;

//     always_ff @(posedge pclk) begin
//         if (reset) begin
//             line_sel <= 0;
//         end else if (we) begin
//             case (line_sel)
//                 2'd0: line0[px] <= red_val;
//                 2'd1: line1[px] <= red_val;
//                 2'd2: line2[px] <= red_val;
//             endcase
//             if (px == IMG_W - 1)
//                 line_sel <= (line_sel == 2) ? 0 : line_sel + 1;
//         end
//     end

//     // ── 3. 3x3 윈도우 읽기 ───────────────────────────────────────
//     logic [1:0] row0_sel, row1_sel, row2_sel;
//     assign row2_sel = line_sel;
//     assign row1_sel = (line_sel == 0) ? 2 : line_sel - 1;
//     assign row0_sel = (line_sel == 1) ? 2 : (line_sel == 0) ? 1 : 0;

//     logic [8:0] px_m1, px_p1;
//     assign px_m1 = (px == 0)          ? 9'd0        : px - 1;
//     assign px_p1 = (px == IMG_W - 1)  ? IMG_W - 1   : px + 1;

//     logic [7:0] p00, p01, p02;
//     logic [7:0] p10,      p12;
//     logic [7:0] p20, p21, p22;

//     // Scharr는 중앙(p11) 사용 안 함
//     always_comb begin
//         case (row0_sel)
//             2'd0: begin p00=line0[px_m1]; p01=line0[px]; p02=line0[px_p1]; end
//             2'd1: begin p00=line1[px_m1]; p01=line1[px]; p02=line1[px_p1]; end
//             2'd2: begin p00=line2[px_m1]; p01=line2[px]; p02=line2[px_p1]; end
//             default: begin p00=0; p01=0; p02=0; end
//         endcase
//         case (row1_sel)
//             2'd0: begin p10=line0[px_m1]; p12=line0[px_p1]; end
//             2'd1: begin p10=line1[px_m1]; p12=line1[px_p1]; end
//             2'd2: begin p10=line2[px_m1]; p12=line2[px_p1]; end
//             default: begin p10=0; p12=0; end
//         endcase
//         case (row2_sel)
//             2'd0: begin p20=line0[px_m1]; p21=line0[px]; p22=line0[px_p1]; end
//             2'd1: begin p20=line1[px_m1]; p21=line1[px]; p22=line1[px_p1]; end
//             2'd2: begin p20=line2[px_m1]; p21=line2[px]; p22=line2[px_p1]; end
//             default: begin p20=0; p21=0; p22=0; end
//         endcase
//     end

//     // ── 4. Scharr 연산 ───────────────────────────────────────────
//     // Scharr Gx:         Scharr Gy:
//     // -3   0   3         -3  -10  -3
//     // -10  0   10         0    0   0
//     // -3   0   3          3   10   3
//     //
//     // Gx = 3*(p02-p00) + 10*(p12-p10) + 3*(p22-p20)
//     // Gy = 3*(p20-p00) + 10*(p21-p01) + 3*(p22-p02)
//     //
//     // 최대값: (3+10+3)*255*2 = 8160 → 14bit signed 필요

//     logic signed [13:0] Gx, Gy;
//     logic        [13:0] Gx_abs, Gy_abs;
//     logic        [14:0] G_mag;

//     // *3 = <<1 + 값,  *10 = <<3 + <<1
//     logic signed [10:0] p02s, p00s, p12s, p10s, p22s, p20s;
//     logic signed [10:0] p21s, p01s;

//     assign p00s = {1'b0, p00};
//     assign p01s = {1'b0, p01};
//     assign p02s = {1'b0, p02};
//     assign p10s = {1'b0, p10};
//     assign p12s = {1'b0, p12};
//     assign p20s = {1'b0, p20};
//     assign p21s = {1'b0, p21};
//     assign p22s = {1'b0, p22};

//     assign Gx = ($signed({p02s, 1'b0}) + $signed({3'b0, p02}))   // *3
//               - ($signed({p00s, 1'b0}) + $signed({3'b0, p00}))   // *3
//               + ($signed({p12s, 3'b0}) + $signed({p12s, 1'b0}))  // *10
//               - ($signed({p10s, 3'b0}) + $signed({p10s, 1'b0}))  // *10
//               + ($signed({p22s, 1'b0}) + $signed({3'b0, p22}))   // *3
//               - ($signed({p20s, 1'b0}) + $signed({3'b0, p20}));  // *3

//     assign Gy = ($signed({p20s, 1'b0}) + $signed({3'b0, p20}))   // *3
//               - ($signed({p00s, 1'b0}) + $signed({3'b0, p00}))   // *3
//               + ($signed({p21s, 3'b0}) + $signed({p21s, 1'b0}))  // *10
//               - ($signed({p01s, 3'b0}) + $signed({p01s, 1'b0}))  // *10
//               + ($signed({p22s, 1'b0}) + $signed({3'b0, p22}))   // *3
//               - ($signed({p02s, 1'b0}) + $signed({3'b0, p02}));  // *3

//     assign Gx_abs = Gx[13] ? -Gx : Gx;
//     assign Gy_abs = Gy[13] ? -Gy : Gy;
//     assign G_mag  = {1'b0, Gx_abs} + {1'b0, Gy_abs};

//     // ── 5. Edge 판단 및 출력 ─────────────────────────────────────
//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             is_edge <= 0;
//             edge_px <= 0;
//             edge_py <= 0;
//         end else begin
//             if (we && py >= 2 && py < IMG_H-1 && px >= 1 && px < IMG_W-1) begin
//                 is_edge <= (G_mag > {2'b0, EDGE_THRESH});
//             end else begin
//                 is_edge <= 1'b0;
//             end
//             edge_px <= px;
//             edge_py <= py;
//         end
//     end

// endmodule
