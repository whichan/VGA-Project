`timescale 1ns / 1ps

module spi_master #(
    parameter HALF_PERIOD = 100
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        start,
    input  logic [15:0] tx_data,
    output logic        tx_ready,
    output logic [15:0] rx_data,
    output logic        done,
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs
);

  localparam CNT_MAX = HALF_PERIOD - 1;
  localparam CNT_W = $clog2(HALF_PERIOD);

  typedef enum logic [1:0] {
    IDLE,
    CP0,
    CP1
  } state_t;
  state_t state, state_next;

  logic [15:0] tx_data_reg, tx_data_next;
  logic [15:0] rx_data_reg, rx_data_next;
  logic [CNT_W-1:0] clk_counter_reg, clk_counter_next;
  logic [3:0] bit_counter_reg, bit_counter_next;

  assign mosi = tx_data_reg[15];
  assign sclk = (state_next == CP1) ? 1'b1 : 1'b0;
  assign rx_data = rx_data_reg;
  assign cs = (state_next == IDLE) ? 1'b1 : 1'b0;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      tx_data_reg <= 0;
      rx_data_reg <= 0;
      bit_counter_reg <= 0;
      clk_counter_reg <= 0;
    end else begin
      state <= state_next;
      tx_data_reg <= tx_data_next;
      rx_data_reg <= rx_data_next;
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
    done = 0;
    tx_ready = 0;
    case (state)
      IDLE: begin
        tx_ready = 1;
        if (start) begin
          state_next = CP0;
          tx_data_next = tx_data;
          clk_counter_next = 0;
          bit_counter_next = 0;
        end
      end
      CP0: begin
        if (clk_counter_reg == CNT_MAX[CNT_W-1:0]) begin
          state_next = CP1;
          rx_data_next = {rx_data_reg[14:0], miso};
          clk_counter_next = 0;
        end else clk_counter_next = clk_counter_reg + 1;
      end
      CP1: begin
        if (clk_counter_reg == CNT_MAX[CNT_W-1:0]) begin
          clk_counter_next = 0;
          if (bit_counter_reg == 15) begin
            done = 1;
            bit_counter_next = 0;
            state_next = IDLE;
          end else begin
            bit_counter_next = bit_counter_reg + 1;
            tx_data_next = {tx_data_reg[14:0], 1'b0};
            state_next = CP0;
          end
        end else clk_counter_next = clk_counter_reg + 1;
      end
    endcase
  end

endmodule
