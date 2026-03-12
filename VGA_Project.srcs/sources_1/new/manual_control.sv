`timescale 1ns / 1ps

module manual_control (
    input  logic clk,
    input  logic reset,
    input  logic sw_mode,
    input  logic btn_left,
    input  logic btn_right,
    input  logic btn_up,
    input  logic btn_down,
    input  logic btn_center,
    output logic mode,
    output logic left,
    output logic right,
    output logic up,
    output logic down,
    output logic fire
);

  localparam DEBOUNCE_MAX = 20'd999_999;

  logic [19:0] sw_cnt;
  logic sw_stable, sw_sync1, sw_sync2;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      sw_sync1 <= 1'b1;
      sw_sync2 <= 1'b1;
      sw_cnt <= 0;
      sw_stable <= 1'b1;
    end else begin
      sw_sync1 <= sw_mode;
      sw_sync2 <= sw_sync1;
      if (sw_sync2 != sw_stable) begin
        if (sw_cnt == DEBOUNCE_MAX) begin
          sw_stable <= sw_sync2;
          sw_cnt <= 0;
        end else sw_cnt <= sw_cnt + 1;
      end else sw_cnt <= 0;
    end
  end
  assign mode = sw_stable;

  logic [19:0] cnt_L;
  logic btn_L_s1, btn_L_s2, btn_L_st;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      btn_L_s1 <= 0;
      btn_L_s2 <= 0;
      cnt_L <= 0;
      btn_L_st <= 0;
    end else begin
      btn_L_s1 <= btn_left;
      btn_L_s2 <= btn_L_s1;
      if (btn_L_s2 != btn_L_st) begin
        if (cnt_L == DEBOUNCE_MAX) begin
          btn_L_st <= btn_L_s2;
          cnt_L <= 0;
        end else cnt_L <= cnt_L + 1;
      end else cnt_L <= 0;
    end
  end

  logic [19:0] cnt_R;
  logic btn_R_s1, btn_R_s2, btn_R_st;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      btn_R_s1 <= 0;
      btn_R_s2 <= 0;
      cnt_R <= 0;
      btn_R_st <= 0;
    end else begin
      btn_R_s1 <= btn_right;
      btn_R_s2 <= btn_R_s1;
      if (btn_R_s2 != btn_R_st) begin
        if (cnt_R == DEBOUNCE_MAX) begin
          btn_R_st <= btn_R_s2;
          cnt_R <= 0;
        end else cnt_R <= cnt_R + 1;
      end else cnt_R <= 0;
    end
  end

  logic [19:0] cnt_U;
  logic btn_U_s1, btn_U_s2, btn_U_st;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      btn_U_s1 <= 0;
      btn_U_s2 <= 0;
      cnt_U <= 0;
      btn_U_st <= 0;
    end else begin
      btn_U_s1 <= btn_up;
      btn_U_s2 <= btn_U_s1;
      if (btn_U_s2 != btn_U_st) begin
        if (cnt_U == DEBOUNCE_MAX) begin
          btn_U_st <= btn_U_s2;
          cnt_U <= 0;
        end else cnt_U <= cnt_U + 1;
      end else cnt_U <= 0;
    end
  end

  logic [19:0] cnt_D;
  logic btn_D_s1, btn_D_s2, btn_D_st;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      btn_D_s1 <= 0;
      btn_D_s2 <= 0;
      cnt_D <= 0;
      btn_D_st <= 0;
    end else begin
      btn_D_s1 <= btn_down;
      btn_D_s2 <= btn_D_s1;
      if (btn_D_s2 != btn_D_st) begin
        if (cnt_D == DEBOUNCE_MAX) begin
          btn_D_st <= btn_D_s2;
          cnt_D <= 0;
        end else cnt_D <= cnt_D + 1;
      end else cnt_D <= 0;
    end
  end

  logic [19:0] cnt_C;
  logic btn_C_s1, btn_C_s2, btn_C_st;
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      btn_C_s1 <= 0;
      btn_C_s2 <= 0;
      cnt_C <= 0;
      btn_C_st <= 0;
    end else begin
      btn_C_s1 <= btn_center;
      btn_C_s2 <= btn_C_s1;
      if (btn_C_s2 != btn_C_st) begin
        if (cnt_C == DEBOUNCE_MAX) begin
          btn_C_st <= btn_C_s2;
          cnt_C <= 0;
        end else cnt_C <= cnt_C + 1;
      end else cnt_C <= 0;
    end
  end

  assign left  = ~mode & btn_L_st;
  assign right = ~mode & btn_R_st;
  assign up    = ~mode & btn_U_st;
  assign down  = ~mode & btn_D_st;
  assign fire  = btn_C_st;

endmodule
