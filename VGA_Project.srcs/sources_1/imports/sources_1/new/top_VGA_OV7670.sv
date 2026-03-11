`timescale 1ns / 1ps

module top_VGA_OV7670 (
    input  logic       clk,
    input  logic       reset,
    //ov7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input        [7:0] data,
    //vga port side
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue,
    //ov7670
    output logic       sioc,
    inout  wire        siod,
    //spi interface
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs
);

  logic                       clk_100M;
  logic [                9:0] x_pixel;
  logic [                9:0] y_pixel;
  logic                       DE;
  logic                       we;
  logic [$clog2(320*240)-1:0] wAddr;
  logic [               15:0] wData;
  logic                       rclk;
  logic [$clog2(320*240)-1:0] rAddr;
  logic [               15:0] rData;
  logic [                7:0] sccb_reg_addr;
  logic [                7:0] sccb_reg_data;

  //color detect / edge detect
  logic [8:0] box_x_min, box_x_max;
  logic [7:0] box_y_min, box_y_max;
  logic       box_valid;
  logic [8:0] px;
  logic [7:0] py;
  logic       is_edge;
  logic [8:0] edge_px;
  logic [7:0] edge_py;
  logic sccb_start, sccb_busy, sccb_done, ov_reset, ov_pwdn, init_done;

  logic        spi_start;
  logic [15:0] spi_tx_data;
  logic [15:0] spi_rx_data;
  logic        spi_done;
  logic        spi_tx_ready;

  logic [ 8:0] box_r_x_min;
  logic [ 8:0] box_r_x_max;
  logic [ 7:0] box_r_y_min;
  logic [ 7:0] box_r_y_max;
  logic        box_r_valid;
  logic [ 8:0] box_g_x_min;
  logic [ 8:0] box_g_x_max;
  logic [ 7:0] box_g_y_min;
  logic [ 7:0] box_g_y_max;
  logic        box_g_valid;
  logic [ 8:0] box_b_x_min;
  logic [ 8:0] box_b_x_max;
  logic [ 7:0] box_b_y_min;
  logic [ 7:0] box_b_y_max;
  logic        box_b_valid;

  assign px = wAddr % 320;
  assign py = wAddr / 320;


  clk_wiz_0 U_CLK_WIZ (
      // Clock out ports
      .clk_out1(clk_100M),  // output clk_out1 100MHz
      .clk_out2(xclk),  // output clk_out2 25MHz
      // Status and control signals
      .reset   (reset),     // input reset
      .locked  (locked),    // output locked
      // Clock in ports
      .clk_in1 (clk) //input clk_in1 sys_clock
  );  // input clk_in1

  VGA_Decoder_Top U_VGA_DECODER (
      .clk    (clk_100M),
      .reset  (reset),
      .pclk   (rclk),
      .h_sync (h_sync),
      .v_sync (v_sync),
      .x_pixel(x_pixel),
      .y_pixel(y_pixel),
      .DE     (DE)
  );


  ImgMemReader #(
      .IMG_SIZE(360 * 240),
      .IMG_W(320),
      .IMG_H(240)
      // .NUM_BOXES(NUM_BOXES)
  ) U_ImgMemReader (
      .DE         (DE),
      .x_pixel    (x_pixel),
      .y_pixel    (y_pixel),
      .imgData    (rData),
      .addr       (rAddr),
      .port_red   (port_red),
      .port_green (port_green),
      .port_blue  (port_blue),
      .box_r_x_min(box_r_x_min),
      .box_r_x_max(box_r_x_max),
      .box_r_y_min(box_r_y_min),
      .box_r_y_max(box_r_y_max),
      .box_r_valid(box_r_valid),
      .box_g_x_min(box_g_x_min),
      .box_g_x_max(box_g_x_max),
      .box_g_y_min(box_g_y_min),
      .box_g_y_max(box_g_y_max),
      .box_g_valid(box_g_valid),
      .box_b_x_min(box_b_x_min),
      .box_b_x_max(box_b_x_max),
      .box_b_y_min(box_b_y_min),
      .box_b_y_max(box_b_y_max),
      .box_b_valid(box_b_valid)
  );

  //   ImgMemReader_upscaler U_FrameBufferReader_Upscale (
  //       .DE(DE),
  //       .x_pixel(x_pixel),
  //       .y_pixel(y_pixel),
  //       .addr(rAddr),
  //       .imgData(rData),
  //       .port_red(port_red),
  //       .port_green(port_green),
  //       .port_blue(port_blue)
  //   );

  FrameBuffer U_FRAMEBUFFER (
      .wclk (pclk),
      .we   (we),
      .wAddr(wAddr),
      .wData(wData),
      .rclk (rclk),
      .rAddr(rAddr),
      .rData(rData)
  );

  OV7670_MemController U_OV7670_MemController (
      .pclk (pclk),
      .reset(reset),
      .href (href),
      .vsync(vsync),
      .data (data),
      .we   (we),
      .wAddr(wAddr),
      .wData(wData)
  );

  sccb_master #(
      .CLK_FREQ (100_000_000),
      .SCCB_FREQ(100_000)
  ) U_SCCB_MASTER (
      .clk     (clk_100M),
      .reset   (reset),
      .start   (sccb_start),
      .reg_addr(sccb_reg_addr),
      .reg_data(sccb_reg_data),
      .busy    (sccb_busy),
      .done    (sccb_done),
      .sioc    (sioc),
      .siod    (siod)
  );

  sccb_init_fsm U_SCCB_INIT (
      .clk          (clk_100M),
      .reset        (reset),
      .sccb_start   (sccb_start),
      .sccb_reg_addr(sccb_reg_addr),
      .sccb_reg_data(sccb_reg_data),
      .sccb_done    (sccb_done),
      .ov_reset     (ov_reset),
      .ov_pwdn      (ov_pwdn),
      .init_done    (init_done)
  );

  VGA_EdgeDetector #(
      .IMG_W      (320),
      .IMG_H      (240),
      .EDGE_THRESH(13'd800)  //민감도 조정
  ) u_VGA_EdgeDetector (
      .pclk   (pclk),
      .reset  (reset),
      .we     (we),
      .wAddr  (wAddr),
      .wData  (wData),
      .px     (px),
      .py     (py),
      .is_edge(is_edge),
      .edge_px(edge_px),
      .edge_py(edge_py)
  );

  // RED -------------------------------------------------
  ColorDetector #(
      .IMG_W            (320),
      .IMG_H            (240),
      .R_MIN            (4'd10),
      .R_MAX            (4'd15),  // ← 비행기 색에 맞게 조정
      .G_MIN            (4'd0),
      .G_MAX            (4'd5),
      .B_MIN            (4'd0),
      .B_MAX            (4'd5),
      .PIX_THRESHOLD_MIN(20),
      .PIX_THRESHOLD_MAX(200)
  ) u_ColorDetector_RED (
      .pclk     (pclk),
      .reset    (reset),
      .we       (we),
      .wAddr    (wAddr),
      .wData    (wData),
      .vsync    (vsync),
      .box_x_min(box_r_x_min),
      .box_x_max(box_r_x_max),
      .box_y_min(box_r_y_min),
      .box_y_max(box_r_y_max),
      .box_valid(box_r_valid),
      .is_edge  (is_edge),
      .edge_px  (edge_px),
      .edge_py  (edge_py)
  );

  // GREEN -------------------------------------------------
  ColorDetector #(
      .IMG_W            (320),
      .IMG_H            (240),
      .R_MIN            (4'd0),
      .R_MAX            (4'd5),
      .G_MIN            (4'd10),
      .G_MAX            (4'd15),
      .B_MIN            (4'd0),
      .B_MAX            (4'd5),
      .PIX_THRESHOLD_MIN(20),
      .PIX_THRESHOLD_MAX(200)
  ) u_ColorDetector_GREEN (
      .pclk     (pclk),
      .reset    (reset),
      .we       (we),
      .wAddr    (wAddr),
      .wData    (wData),
      .vsync    (vsync),
      .box_x_min(box_g_x_min),
      .box_x_max(box_g_x_max),
      .box_y_min(box_g_y_min),
      .box_y_max(box_g_y_max),
      .box_valid(box_g_valid),
      .is_edge  (is_edge),
      .edge_px  (edge_px),
      .edge_py  (edge_py)
  );

  // BLUE -------------------------------------------------
  //   ColorDetector #(
  //       .IMG_W            (320),
  //       .IMG_H            (240),
  //       .R_MIN            (4'd0),
  //       .R_MAX            (4'd5),
  //       .G_MIN            (4'd0),
  //       .G_MAX            (4'd5),
  //       .B_MIN            (4'd10),
  //       .B_MAX            (4'd15),
  //       .PIX_THRESHOLD_MIN(20),
  //       .PIX_THRESHOLD_MAX(200)
  //   ) u_ColorDetector_BLUE (
  //       .pclk     (pclk),
  //       .reset    (reset),
  //       .we       (we),
  //       .wAddr    (wAddr),
  //       .wData    (wData),
  //       .vsync    (vsync),
  //       .box_x_min(box_b_x_min),
  //       .box_x_max(box_b_x_max),
  //       .box_y_min(box_b_y_min),
  //       .box_y_max(box_b_y_max),
  //       .box_valid(box_b_valid),
  //       .is_edge  (is_edge),
  //       .edge_px  (edge_px),
  //       .edge_py  (edge_py)
  //   );

  spi_send_fsm U_SPI_SEND_FSM (
      .clk         (clk_100M),     // 100MHz (spi_master와 같은 클럭)
      .reset       (reset),
      .box_x_min   (box_r_x_min),
      .box_x_max   (box_r_x_max),
      .box_y_min   (box_r_y_min),
      .box_y_max   (box_r_y_max),
      .box_valid   (box_r_valid),
      .vsync       (vsync),
      .spi_start   (spi_start),
      .spi_tx_data (spi_tx_data),
      .spi_done    (spi_done),
      .spi_tx_ready(spi_tx_ready)
  );

  spi_master U_SPI_MASTER (
      .clk     (clk_100M),
      .reset   (reset),
      .start   (spi_start),
      .tx_data (spi_tx_data),
      .tx_ready(spi_tx_ready),
      .rx_data (spi_rx_data),
      .done    (spi_done),
      .sclk    (sclk),
      .mosi    (mosi),
      .miso    (miso),
      .cs      (cs)
  );
endmodule
