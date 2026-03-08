// ColorDetector.sv
`timescale 1ns / 1ps

module ColorDetector #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    // RGB565 타겟 색상 임계값 (비행기 색에 맞게 조정)
    parameter R_MIN = 4'd10,  // Red 4bit (imgData[15:12])
    parameter R_MAX = 4'd15,
    parameter G_MIN = 4'd0,
    parameter G_MAX = 4'd5,
    parameter B_MIN = 4'd0,
    parameter B_MAX = 4'd5,
    // 노이즈 필터: 최소 픽셀 수
    parameter PIX_THRESHOLD = 100
) (
    input  logic                       pclk,
    input  logic                       reset,
    // OV7670_MemController 신호 감시
    input  logic                       we,
    input  logic [$clog2(320*240)-1:0] wAddr,
    input  logic [               15:0] wData,
    input  logic                       vsync,      // 프레임 끝 감지용
    // Bounding Box 출력 (rclk 도메인에서 사용)
    output logic [                8:0] box_x_min,  // 0~319
    output logic [                8:0] box_x_max,
    output logic [                7:0] box_y_min,  // 0~239
    output logic [                7:0] box_y_max,
    output logic                       box_valid,  // 충분한 픽셀 감지됐을 때만 1
    input  logic                       is_edge,
    input  logic [                8:0] edge_px,
    input  logic [                7:0] edge_py
);

  // wAddr → (px, py) 변환
  logic [8:0] px;
  logic [7:0] py;
  logic [3:0] r, g, b;
  logic is_target;
  assign px = wAddr % IMG_W;
  assign py = wAddr / IMG_W;

  // 색상 추출 (RGB565에서 4bit씩)
  assign r = wData[15:12];
  assign g = wData[10:7];
  assign b = wData[4:1];

  // 색상 매칭
  assign is_target = we &&
                       (r >= R_MIN) && (r <= R_MAX) &&
                       (g >= G_MIN) && (g <= G_MAX) &&
                       (b >= B_MIN) && (b <= B_MAX);

  // 프레임 내 누적 레지스터
  logic [8:0] cur_x_min, cur_x_max;
  logic [7:0] cur_y_min, cur_y_max;
  logic [16:0] pix_count;  // 최대 320*240=76800 → 17bit

  logic vsync_prev;

  logic is_candidate;
  assign is_candidate = is_target && is_edge;

  always_ff @(posedge pclk or posedge reset) begin
    if (reset) begin
      cur_x_min  <= 9'd319;
      cur_x_max  <= 9'd0;
      cur_y_min  <= 8'd239;
      cur_y_max  <= 8'd0;
      pix_count  <= 0;
      box_x_min  <= 0;
      box_x_max  <= 0;
      box_y_min  <= 0;
      box_y_max  <= 0;
      box_valid  <= 0;
      vsync_prev <= 0;
    end else begin
      vsync_prev <= vsync;

      // vsync 상승 엣지 = 프레임 끝 → 결과 래치 후 초기화
      if (vsync && !vsync_prev) begin
        if (pix_count > PIX_THRESHOLD) begin
          box_x_min <= cur_x_min;
          box_x_max <= cur_x_max;
          box_y_min <= cur_y_min;
          box_y_max <= cur_y_max;
          box_valid <= 1;
        end else begin
          box_valid <= 0;
        end
        // 초기화
        cur_x_min <= 9'd319;
        cur_x_max <= 9'd0;
        cur_y_min <= 8'd239;
        cur_y_max <= 8'd0;
        pix_count <= 0;
      end

      // 픽셀 처리
      if (is_target) begin
        pix_count <= pix_count + 1;
        if (px < cur_x_min) cur_x_min <= px;
        if (px > cur_x_max) cur_x_max <= px;
        if (py < cur_y_min) cur_y_min <= py;
        if (py > cur_y_max) cur_y_max <= py;
      end
    end
  end

endmodule
