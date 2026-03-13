`timescale 1ns / 1ps

module VGA_Decoder (
    input  logic       clk,
    input  logic       reset,
    output logic       pclk,
    output logic       h_sync,
    output logic       v_sync,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel,
    output logic       DE        //display enable
);

  logic [9:0] h_count;
  logic [9:0] v_count;
  // logic w_pclk;
  // assign pclk = w_pclk;

  pclk_gen u_pclk_gen (
      .*
      // .pclk(w_pclk)
  );
  pxl_counter u_pxl_counter (
      .*
      // .pclk(w_pclk)
  );
  vga_decoder u_vga_decoder (.*);

endmodule

module pclk_gen (
    input  logic clk,
    input  logic reset,
    output logic pclk
);
  logic [1:0] p_count;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      p_count <= 0;
      pclk    <= 0;
    end else begin
      if (p_count == 2'b11) begin
        p_count <= 0;
        pclk    <= 1'b1;
      end else begin
        p_count <= p_count + 1;
        pclk    <= 1'b0;
      end
    end
  end

endmodule

module pxl_counter (
    input logic clk,
    input logic reset,
    input logic pclk,
    output logic [9:0] h_count,
    output logic [9:0] v_count
);

  localparam H_MAX = 800, V_MAX = 525;

  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      h_count <= 0;
    end else begin
      if (pclk) begin
        if (h_count == H_MAX - 1) begin
          h_count <= 0;
        end else begin
          h_count <= h_count + 1;
        end
      end
    end
  end

  always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
      v_count <= 0;
    end else begin
      if (pclk) begin  //match the sync
        if (h_count == H_MAX - 1) begin
          if (v_count == V_MAX - 1) begin
            v_count <= 0;
          end else begin
            v_count <= v_count + 1;
          end
        end
      end
    end
  end

endmodule

//comparator, there is no clk
module vga_decoder (
    input  logic [9:0] h_count,
    input  logic [9:0] v_count,
    output logic       h_sync,
    output logic       v_sync,
    output logic       DE,       //display enable
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);

  localparam H_Visible_area = 640;
  localparam H_Front_porch = 16;
  localparam H_Sync_pulse = 96;
  localparam H_Back_porch = 48;
  localparam H_Whole_line = 800;

  localparam V_Visible_area = 480;
  localparam V_Front_porch = 10;
  localparam V_Sync_pulse = 2;
  localparam V_Back_porch = 22;
  localparam V_Whole_line = 525;

  assign h_sync = !((h_count >= (H_Visible_area + H_Front_porch)) &&
                    (h_count< (H_Visible_area + H_Front_porch+H_Sync_pulse)));

  assign v_sync = !((v_count >= (V_Visible_area + V_Front_porch)) &&
                    (v_count< (V_Visible_area + V_Front_porch+V_Sync_pulse)));

  assign DE = (h_count < H_Visible_area) && (v_count < V_Visible_area);
  assign x_pixel = h_count;
  assign y_pixel = v_count;

endmodule
