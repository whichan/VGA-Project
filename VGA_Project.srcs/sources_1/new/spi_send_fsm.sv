// `timescale 1ns / 1ps

// module spi_send_fsm (
//     input  logic        clk,
//     input  logic        reset,
//     // input  logic [ 8:0] box_x_min,
//     // input  logic [ 8:0] box_x_max,
//     // input  logic [ 7:0] box_y_min,
//     // input  logic [ 7:0] box_y_max,
//     input  logic [ 8:0] center_x,
//     input  logic [ 7:0] center_y,
//     input  logic        box_valid,
//     input  logic        vsync,
//     input  logic        mode,
//     input  logic        btn_left,
//     input  logic        btn_right,
//     input  logic        btn_up,
//     input  logic        btn_down,
//     input  logic        fire,
//     output logic        spi_start,
//     output logic [15:0] spi_tx_data,
//     input  logic        spi_done,
//     input  logic        spi_tx_ready
// );

//   // wire [9:0] cx_sum = {1'b0, box_x_min} + {1'b0, box_x_max};
//   // wire [8:0] cy_sum = {1'b0, box_y_min} + {1'b0, box_y_max};
//   // wire [8:0] center_x = cx_sum[9:1];
//   // wire [7:0] center_y = cy_sum[8:1];

//   logic vsync_sync1, vsync_sync2, vsync_sync3;
//   always_ff @(posedge clk or posedge reset) begin
//     if (reset) begin
//       vsync_sync1 <= 0;
//       vsync_sync2 <= 0;
//       vsync_sync3 <= 0;
//     end else begin
//       vsync_sync1 <= vsync;
//       vsync_sync2 <= vsync_sync1;
//       vsync_sync3 <= vsync_sync2;
//     end
//   end

//   wire vsync_rising = vsync_sync2 && !vsync_sync3;
//   wire in_vblank = vsync_sync2;

//   logic [15:0] latched_word1, latched_word2;

//   typedef enum logic [3:0] {
//     TX_IDLE,
//     TX_LATCH,
//     TX_SEND1,
//     TX_WAIT1,
//     TX_GAP,
//     TX_SEND2,
//     TX_WAIT2,
//     TX_DONE
//   } tx_state_t;

//   tx_state_t state;
//   logic [9:0] gap_cnt;

//   always_ff @(posedge clk or posedge reset) begin
//     if (reset) begin
//       state <= TX_IDLE;
//       spi_start <= 0;
//       spi_tx_data <= 0;
//       latched_word1 <= 0;
//       latched_word2 <= 0;
//       gap_cnt <= 0;
//     end else begin
//       spi_start <= 0;
//       case (state)
//         TX_IDLE: if (vsync_rising) state <= TX_LATCH;

//         TX_LATCH: begin
//           latched_word1 <= {mode, btn_left, btn_right, btn_up, btn_down, fire, 1'b0, center_x};
//           latched_word2 <= {7'b0, box_valid, center_y};
//           state <= TX_SEND1;
//         end

//         TX_SEND1: begin
//           if (!in_vblank) state <= TX_DONE;
//           else if (spi_tx_ready) begin
//             spi_tx_data <= latched_word1;
//             spi_start <= 1;
//             state <= TX_WAIT1;
//           end
//         end

//         TX_WAIT1: begin
//           if (!in_vblank) state <= TX_DONE;
//           else if (spi_done) begin
//             gap_cnt <= 0;
//             state   <= TX_GAP;
//           end
//         end

//         TX_GAP: begin
//           if (!in_vblank) state <= TX_DONE;
//           else if (gap_cnt == 10'd500) state <= TX_SEND2;
//           else gap_cnt <= gap_cnt + 1;
//         end

//         TX_SEND2: begin
//           if (!in_vblank) state <= TX_DONE;
//           else if (spi_tx_ready) begin
//             spi_tx_data <= latched_word2;
//             spi_start <= 1;
//             state <= TX_WAIT2;
//           end
//         end

//         TX_WAIT2: if (spi_done) state <= TX_DONE;
//         TX_DONE:  state <= TX_IDLE;
//         default:  state <= TX_IDLE;
//       endcase
//     end
//   end

// endmodule

`timescale 1ns / 1ps
//=============================================================================
// spi_send_fsm
// - VSYNC 하강 엣지마다 2회 × 16비트 SPI 전송
// - 1회차: {7'b0, center_x[8:0]}        → X좌표
// - 2회차: {7'b0, valid, center_y[7:0]} → valid + Y좌표
// - 기존 spi_master(16비트 단위)를 그대로 사용
// - vsync에 대해 2단 CDC 동기화 포함
//=============================================================================
module spi_send_fsm (
    input  logic        clk,          // 100MHz (spi_master와 같은 클럭)
    input  logic        reset,
    // ColorDetector 출력
    // input  logic [ 8:0] box_x_min,
    // input  logic [ 8:0] box_x_max,
    // input  logic [ 7:0] box_y_min,
    // input  logic [ 7:0] box_y_max,
    // input  logic        box_valid,
    input  logic [ 8:0] center_x,
    input  logic [ 7:0] center_y,
    input  logic        box_valid,
    // VSYNC (pclk 도메인 — CDC 필요)
    input  logic        vsync,
    // spi_master 인터페이스
    output logic        spi_start,
    output logic [15:0] spi_tx_data,
    input  logic        spi_done,
    input  logic        spi_tx_ready
);

  // =========================================================================
  // VSYNC 2단 CDC 동기화 (pclk → clk_100M)
  // =========================================================================
  logic vsync_sync1, vsync_sync2, vsync_sync3;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      vsync_sync1 <= 1'b0;
      vsync_sync2 <= 1'b0;
      vsync_sync3 <= 1'b0;
    end else begin
      vsync_sync1 <= vsync;
      vsync_sync2 <= vsync_sync1;
      vsync_sync3 <= vsync_sync2;
    end
  end

  wire vsync_falling = vsync_sync3 && !vsync_sync2;

  // =========================================================================
  // 전송 FSM
  // =========================================================================
  typedef enum logic [2:0] {
    TX_IDLE,
    TX_SEND1,  // 1회차: center_x
    TX_WAIT1,  // 완료 대기
    TX_SEND2,  // 2회차: valid + center_y
    TX_WAIT2,  // 완료 대기
    TX_DONE    // 다음 VSYNC 대기
  } tx_state_t;

  tx_state_t state;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state       <= TX_IDLE;
      spi_start   <= 1'b0;
      spi_tx_data <= 16'd0;
    end else begin
      spi_start <= 1'b0;  // 기본: start 펄스 해제

      case (state)
        TX_IDLE: begin
          if (vsync_falling) state <= TX_SEND1;
        end

        TX_SEND1: begin
          if (spi_tx_ready) begin
            spi_tx_data <= {7'b0, center_x};
            spi_start   <= 1'b1;
            state       <= TX_WAIT1;
          end
        end

        TX_WAIT1: begin
          if (spi_done) state <= TX_SEND2;
        end

        TX_SEND2: begin
          if (spi_tx_ready) begin
            spi_tx_data <= {7'b0, box_valid, center_y};
            spi_start   <= 1'b1;
            state       <= TX_WAIT2;
          end
        end

        TX_WAIT2: begin
          if (spi_done) state <= TX_DONE;
        end

        TX_DONE: begin
          state <= TX_IDLE;
        end

        default: state <= TX_IDLE;
      endcase
    end
  end

endmodule
