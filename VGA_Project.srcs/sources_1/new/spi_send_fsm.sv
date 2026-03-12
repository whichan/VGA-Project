`timescale 1ns / 1ps

module spi_send_fsm (
    input  logic        clk,
    input  logic        reset,
    input  logic [ 8:0] box_x_min,
    input  logic [ 8:0] box_x_max,
    input  logic [ 7:0] box_y_min,
    input  logic [ 7:0] box_y_max,
    input  logic        box_valid,
    input  logic        vsync,
    input  logic        mode,
    input  logic        btn_left,
    input  logic        btn_right,
    input  logic        btn_up,
    input  logic        btn_down,
    input  logic        fire,
    output logic        spi_start,
    output logic [15:0] spi_tx_data,
    input  logic        spi_done,
    input  logic        spi_tx_ready
);

  wire [9:0] cx_sum = {1'b0, box_x_min} + {1'b0, box_x_max};
  wire [8:0] cy_sum = {1'b0, box_y_min} + {1'b0, box_y_max};
  wire [8:0] center_x = cx_sum[9:1];
  wire [7:0] center_y = cy_sum[8:1];

  logic vsync_sync1, vsync_sync2, vsync_sync3;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      vsync_sync1 <= 0;
      vsync_sync2 <= 0;
      vsync_sync3 <= 0;
    end else begin
      vsync_sync1 <= vsync;
      vsync_sync2 <= vsync_sync1;
      vsync_sync3 <= vsync_sync2;
    end
  end

  wire vsync_rising = vsync_sync2 && !vsync_sync3;
  wire in_vblank = vsync_sync2;

  logic [15:0] latched_word1, latched_word2;

  typedef enum logic [3:0] {
    TX_IDLE,
    TX_LATCH,
    TX_SEND1,
    TX_WAIT1,
    TX_GAP,
    TX_SEND2,
    TX_WAIT2,
    TX_DONE
  } tx_state_t;

  tx_state_t state;
  logic [9:0] gap_cnt;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= TX_IDLE;
      spi_start <= 0;
      spi_tx_data <= 0;
      latched_word1 <= 0;
      latched_word2 <= 0;
      gap_cnt <= 0;
    end else begin
      spi_start <= 0;
      case (state)
        TX_IDLE: if (vsync_rising) state <= TX_LATCH;

        TX_LATCH: begin
          latched_word1 <= {mode, btn_left, btn_right, btn_up, btn_down, fire, 1'b0, center_x};
          latched_word2 <= {7'b0, box_valid, center_y};
          state <= TX_SEND1;
        end

        TX_SEND1: begin
          if (!in_vblank) state <= TX_DONE;
          else if (spi_tx_ready) begin
            spi_tx_data <= latched_word1;
            spi_start <= 1;
            state <= TX_WAIT1;
          end
        end

        TX_WAIT1: begin
          if (!in_vblank) state <= TX_DONE;
          else if (spi_done) begin
            gap_cnt <= 0;
            state   <= TX_GAP;
          end
        end

        TX_GAP: begin
          if (!in_vblank) state <= TX_DONE;
          else if (gap_cnt == 10'd500) state <= TX_SEND2;
          else gap_cnt <= gap_cnt + 1;
        end

        TX_SEND2: begin
          if (!in_vblank) state <= TX_DONE;
          else if (spi_tx_ready) begin
            spi_tx_data <= latched_word2;
            spi_start <= 1;
            state <= TX_WAIT2;
          end
        end

        TX_WAIT2: if (spi_done) state <= TX_DONE;
        TX_DONE:  state <= TX_IDLE;
        default:  state <= TX_IDLE;
      endcase
    end
  end

endmodule
