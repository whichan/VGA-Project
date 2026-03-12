`timescale 1ns / 1ps
//=============================================================================
// crosshair_controller
// - 버튼 입력에 따라 crosshair 중심 좌표 업데이트
// - 누르는 동안 계속 이동 (이동 속도: MOVE_INTERVAL 클럭마다 1픽셀)
// - 화면 경계 클램핑
//=============================================================================
module crosshair_controller #(
    parameter MOVE_INTERVAL = 1_000_000  // 100MHz 기준 10ms마다 1픽셀 이동
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       manual_mode,
    // 버튼 입력 (active high, 디바운스 필요)
    input  logic       btn_up,
    input  logic       btn_down,
    input  logic       btn_left,
    input  logic       btn_right,
    // crosshair 중심 좌표 출력 (QVGA 기준)
    output logic [8:0] cx,           // 0~319
    output logic [7:0] cy            // 0~239
);

  // =========================================================================
  // 이동 속도 타이머
  // =========================================================================
  logic [$clog2(MOVE_INTERVAL)-1:0] timer;
  logic move_tick;  // 이 신호가 1일 때 1픽셀 이동

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      timer <= 0;
      move_tick <= 0;
    end else if (manual_mode) begin
      if (timer >= MOVE_INTERVAL - 1) begin
        timer     <= 0;
        move_tick <= 1;
      end else begin
        timer     <= timer + 1;
        move_tick <= 0;
      end
    end else begin
      timer     <= 0;
      move_tick <= 0;
    end
  end

  // =========================================================================
  // 좌표 업데이트
  // =========================================================================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      cx <= 9'd160;  // 초기값: 화면 중앙
      cy <= 8'd120;
    end else if (!manual_mode) begin
      cx <= 9'd160;  // 수동 모드 아닐 때 중앙으로 리셋
      cy <= 8'd120;
    end else if (move_tick) begin
      // 상하 이동 (경계 클램핑)
      if (btn_up) cy <= (cy > 8'd5) ? cy - 1 : 8'd5;
      if (btn_down) cy <= (cy < 8'd234) ? cy + 1 : 8'd234;
      // 좌우 이동
      if (btn_left) cx <= (cx > 9'd5) ? cx - 1 : 9'd5;
      if (btn_right) cx <= (cx < 9'd314) ? cx + 1 : 9'd314;
    end
  end

endmodule
