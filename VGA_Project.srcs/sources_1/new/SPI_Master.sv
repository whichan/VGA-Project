`timescale 1ns / 1ps

module spi_master (
    //global signals
    input  logic        clk,
    input  logic        reset,
    //external interface signals
    input  logic        start,
    input  logic [15:0] tx_data,
    output logic        tx_ready,
    output logic [15:0] rx_data,
    output logic        done,
    //spi interface signals
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs
);

  typedef enum logic [1:0] {
    IDLE,
    CP0,
    CP1
  } state_t;
  state_t state, state_next;

  logic [15:0] tx_data_reg, tx_data_next;
  logic [15:0] rx_data_reg, rx_data_next;
  logic [$clog2(50)-1:0] clk_counter_reg, clk_counter_next;
  logic [3:0] bit_counter_reg, bit_counter_next;
  logic p_clk;

  assign mosi = tx_data_reg[15];  //tx_data 레지스터의 MSB
  assign p_clk = (state_next == CP1) ? 1'b1 : 1'b0;  //mode0에 대한 설정. CP1 상태일 때 clk은 1
  assign sclk = p_clk;

  assign rx_data = rx_data_reg; //슬레이브로부터 받은 데이터를 내부 레지스터에 저장
  assign cs = (state_next == IDLE) ? 1'b1 : 1'b0;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state           <= IDLE;
      tx_data_reg     <= 0;
      rx_data_reg     <= 0;
      bit_counter_reg <= 4'b0;
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
    state_next       = state;
    tx_data_next     = tx_data_reg;
    rx_data_next     = rx_data_reg;
    bit_counter_next = bit_counter_reg;
    clk_counter_next = clk_counter_reg;
    done             = 1'b0;
    tx_ready         = 1'b0;
    case (state)
      IDLE: begin
        done     = 1'b0;
        tx_ready = 1'b1;
        if (start) begin
          state_next = CP0;
          tx_data_next = tx_data;
          clk_counter_next = 0;
          bit_counter_next = 0;
        end
      end

      CP0: begin
        if (clk_counter_reg == 49) begin
          state_next       = CP1;
          rx_data_next     = {rx_data_reg[14:0], miso};
          clk_counter_next = 0;
        end else begin
          clk_counter_next = clk_counter_reg + 1;
        end
      end

      CP1: begin
        if (clk_counter_reg == 49) begin
          clk_counter_next = 0;
          if (bit_counter_reg == 15) begin
            done             = 1'b1;
            bit_counter_next = 0;
            state_next       = IDLE;
          end else begin
            bit_counter_next = bit_counter_reg + 1;

            tx_data_next     = {tx_data_reg[14:0], 1'b0};
            state_next       = CP0;
          end
        end else begin
          clk_counter_next = clk_counter_reg + 1;
        end
      end
    endcase
  end
endmodule
