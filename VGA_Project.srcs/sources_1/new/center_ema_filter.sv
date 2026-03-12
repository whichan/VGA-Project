module center_ema_filter #(
    parameter SHIFT = 3  // alpha = 1/8, 클수록 더 부드러움
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       valid,     // ColorDetector의 box_valid
    input  logic [8:0] raw_x,
    input  logic [7:0] raw_y,
    output logic [8:0] smooth_x,
    output logic [7:0] smooth_y
);
  // 정밀도 확보를 위해 내부는 확장 비트로 계산
  // smooth_x_fp = smooth_x * 8 (3비트 소수점)
  logic [11:0] smooth_x_fp;  // 9+3 = 12bit
  logic [10:0] smooth_y_fp;  // 8+3 = 11bit

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      smooth_x_fp <= 12'd0;
      smooth_y_fp <= 11'd0;
      smooth_x    <= 9'd0;
      smooth_y    <= 8'd0;
    end else if (valid) begin
      // smooth_fp = smooth_fp - (smooth_fp >> SHIFT) + raw
      smooth_x_fp <= smooth_x_fp - (smooth_x_fp >> SHIFT) + {3'b0, raw_x};
      smooth_y_fp <= smooth_y_fp - (smooth_y_fp >> SHIFT) + {3'b0, raw_y};

      // 출력은 정수 부분만
      smooth_x <= smooth_x_fp[11:3];
      smooth_y <= smooth_y_fp[10:3];
    end
  end
endmodule
