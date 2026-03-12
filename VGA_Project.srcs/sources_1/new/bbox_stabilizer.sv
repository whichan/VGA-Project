`timescale 1ns / 1ps
//=============================================================================
// bbox_stabilizer
// - ColorDetector의 bbox 출력을 안정화
// - 이전 프레임과 변화량이 STABLE_THRESH 이내일 때만 업데이트
// - 변화량이 크면 노이즈로 판단, 이전 값 유지
//=============================================================================
module bbox_stabilizer #(
    parameter STABLE_THRESH = 50  // 픽셀 단위, 줄이면 민감 / 늘리면 안정
) (
    input  logic       clk,
    input  logic       reset,
    // ColorDetector 원본 출력
    input  logic [8:0] raw_x_min,
    input  logic [8:0] raw_x_max,
    input  logic [7:0] raw_y_min,
    input  logic [7:0] raw_y_max,
    input  logic       raw_valid,
    // 안정화된 출력
    output logic [8:0] stab_x_min,
    output logic [8:0] stab_x_max,
    output logic [7:0] stab_y_min,
    output logic [7:0] stab_y_max,
    output logic       stab_valid
);

  // valid 상승엣지 감지 (새 프레임 결과가 들어올 때마다 처리)
  logic raw_valid_prev;
  wire  new_frame = raw_valid && !raw_valid_prev;

  // 첫 획득 여부
  logic acquired;

  // 차이 계산용
  logic [8:0] diff_x_min, diff_x_max;
  logic [8:0] diff_y_min, diff_y_max;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      stab_x_min     <= 9'd0;
      stab_x_max     <= 9'd0;
      stab_y_min     <= 8'd0;
      stab_y_max     <= 8'd0;
      stab_valid     <= 1'b0;
      acquired       <= 1'b0;
      raw_valid_prev <= 1'b0;
    end else begin
      raw_valid_prev <= raw_valid;

      if (!raw_valid) begin
        // ColorDetector가 valid를 내리면 → 안정화 출력도 내림
        stab_valid <= 1'b0;
        acquired   <= 1'b0;

      end else if (new_frame) begin
        // 새 bbox 결과 도착
        diff_x_min = (raw_x_min > stab_x_min) ? (raw_x_min - stab_x_min) : (stab_x_min - raw_x_min);
        diff_x_max = (raw_x_max > stab_x_max) ? (raw_x_max - stab_x_max) : (stab_x_max - raw_x_max);
        diff_y_min = (raw_y_min > stab_y_min) ? (raw_y_min - stab_y_min) : (stab_y_min - raw_y_min);
        diff_y_max = (raw_y_max > stab_y_max) ? (raw_y_max - stab_y_max) : (stab_y_max - raw_y_max);

        if (!acquired) begin
          // 처음 획득 → 무조건 업데이트
          stab_x_min <= raw_x_min;
          stab_x_max <= raw_x_max;
          stab_y_min <= raw_y_min;
          stab_y_max <= raw_y_max;
          stab_valid <= 1'b1;
          acquired   <= 1'b1;
        end else if ((diff_x_min <= STABLE_THRESH) &&
                     (diff_x_max <= STABLE_THRESH) &&
                     (diff_y_min <= STABLE_THRESH) &&
                     (diff_y_max <= STABLE_THRESH)) begin
          // 변화량 이내 → 업데이트
          stab_x_min <= raw_x_min;
          stab_x_max <= raw_x_max;
          stab_y_min <= raw_y_min;
          stab_y_max <= raw_y_max;
          stab_valid <= 1'b1;
        end
        // 변화량 초과 → 아무것도 안 함 (이전 값 유지)
      end
    end
  end

endmodule
