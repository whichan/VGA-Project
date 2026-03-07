`timescale 1ns / 1ps

module spi_master (
    //global signals
    input  logic       clk,
    input  logic       reset,
    //external interface signals
    input  logic       start,
    input  logic [7:0] tx_data,
    output logic       tx_ready,
    output logic [7:0] rx_data,
    output logic       done,
    input  logic       cpha,
    input  logic       cpol,
    //spi interface signals
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs
);

  typedef enum logic [1:0] {
    IDLE,
    CP0,
    CP1,
    CP_DELAY
  } state_t;
  state_t state, state_next;

  logic [7:0] tx_data_reg, tx_data_next;
  logic [7:0] rx_data_reg, rx_data_next;
  logic [$clog2(50)-1:0] clk_counter_reg, clk_counter_next;
  logic [2:0] bit_counter_reg, bit_counter_next;
  logic p_clk;

  assign mosi = tx_data_reg[7];  //tx_data 레지스터의 MSB



  assign rx_data = rx_data_reg; //슬레이브로부터 받은 데이터를 내부 레지스터에 저장
  assign p_clk = ((state_next == CP0) && (cpha == 1) || (state_next == CP1) && (cpha == 0));
  assign sclk = cpol ? ~p_clk : p_clk;
  assign cs = (state_next == IDLE) ? 1'b1 : 1'b0;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state           <= IDLE;
      tx_data_reg     <= 0;
      rx_data_reg     <= 0;
      bit_counter_reg <= 3'b0;
      clk_counter_reg <= 0;
    end else begin
      state           <= state_next;
      tx_data_reg     <= tx_data_next;
      rx_data_reg     <= rx_data_next;
      bit_counter_reg <= bit_counter_next;
      clk_counter_reg <= clk_counter_next;
    end
  end

  always_comb begin
    state_next = state;
    tx_data_next = tx_data_reg;
    rx_data_next = rx_data_reg;
    bit_counter_next = bit_counter_reg;
    clk_counter_next = clk_counter_reg;
    done = 1'b0;
    tx_ready = 1'b0;
    case (state)
      IDLE: begin
        done     = 1'b0;
        tx_ready = 1'b1;
        if (start) begin
          state_next = cpha ? CP_DELAY : CP0;
          tx_data_next = tx_data;
          clk_counter_next = 0;
          bit_counter_next = 0;
        end
      end

      CP0: begin
        if (clk_counter_reg == 49) begin
          state_next       = CP1;
          rx_data_next     = {rx_data_reg[6:0], miso};
          clk_counter_next = 0;
        end else begin
          clk_counter_next = clk_counter_reg + 1;
        end
      end

      CP1: begin
        if (clk_counter_reg == 49) begin
          clk_counter_next = 0;
          if (bit_counter_reg == 7) begin
            // done             = cpha ? 1'b0 : 1'b1;
            done             = 1'b1;
            bit_counter_next = 0;
            state_next       = cpha ? IDLE : CP_DELAY;
          end else begin
            bit_counter_next = bit_counter_reg + 1;

            tx_data_next     = {tx_data_reg[6:0], 1'b0};
            state_next       = CP0;
          end
        end else begin
          clk_counter_next = clk_counter_reg + 1;
        end
      end

      CP_DELAY: begin
        if (clk_counter_reg == 49) begin
          clk_counter_next = 0;
          done             = cpha ? 1'b0 : 1'b1;
          //cpha=1이면 done=0(아직 데이터 8비트 다 보낸거 아님)
          state_next       = cpha ? CP0 : IDLE;
          //cpha=1이면 CP0으로, cpha=0이면 IDLE로
        end else begin
          clk_counter_next = clk_counter_reg + 1;
        end
      end
    endcase
  end
endmodule
