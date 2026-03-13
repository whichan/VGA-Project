`timescale 1ns / 1ps

module top_VGA_OV7670 (
    input  logic       clk,
    input  logic       reset,
    //ov7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    //vga port side
    output logic       v_sync,
    output logic       h_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue,
    output logic       sioc,
    inout  logic       siod,
    //spi
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs,
    //btn
    input  logic       btn_center,
    input  logic       btn_down,
    input  logic       btn_right,
    input  logic       btn_left,
    input  logic       btn_up,
    //switch
    input  logic       sw_img,
    input  logic       sw_mode
);
  localparam NUM_BOXES = 2;

  logic [                7:0] sccb_reg_addr;
  logic [                7:0] sccb_reg_data;
  logic                       sccb_start;
  logic                       sccb_busy;
  logic                       sccb_done;
  logic                       ov_reset;
  logic                       ov_pwdn;
  logic                       init_done;

  logic                       clk_100m;
  logic [                9:0] x_pixel;
  logic [                9:0] y_pixel;
  logic                       DE;  //display enable
  logic                       rclk;
  logic [$clog2(320*240)-1:0] rAddr;
  logic [               15:0] rData;
  logic                       we;
  logic [$clog2(320*240)-1:0] wAddr;
  logic [               15:0] wData;

  logic [                3:0] hsv_red;
  logic [                3:0] hsv_green;
  logic [                3:0] hsv_blue;

  logic                       is_red;
  logic                       is_green;
  logic                       is_blue;


  logic [                3:0] img_red;
  logic [                3:0] img_green;
  logic [                3:0] img_blue;

  logic [                8:0] center_x              [0:NUM_BOXES-1];
  logic [                7:0] center_y              [0:NUM_BOXES-1];

  // ── box_edge_img 출력 ─────────────────────────────────────────
  logic on_red_box0, on_grn_box0, on_blu_box0;
  logic on_red_box1, on_grn_box1, on_blu_box1;
  logic on_red_box, on_grn_box, on_blu_box;

  logic [                8:0] red_stb_x_max[0:NUM_BOXES-1];
  logic [                8:0] red_stb_x_min[0:NUM_BOXES-1];
  logic [                7:0] red_stb_y_max[0:NUM_BOXES-1];
  logic [                7:0] red_stb_y_min[0:NUM_BOXES-1];
  logic                       red_stb_valid[0:NUM_BOXES-1];
  logic [                8:0] spi_center_x;
  logic [                7:0] spi_center_y;
  logic                       spi_valid;

  //spi
  logic                       spi_start;
  logic [               15:0] spi_tx_data;
  logic [               15:0] spi_rx_data;
  logic                       spi_done;
  logic                       spi_tx_ready;

  logic [$clog2(320*240)-1:0] addr_up;
  logic [               15:0] data_up;
  logic [                3:0] red_img;
  logic [                3:0] green_img;
  logic [                3:0] blue_img;
  logic [                3:0] red_detect;
  logic [                3:0] green_detect;
  logic [                3:0] blue_detect;


  // clk
  // clk_out1__100MHz
  // clk_out2__25MHz
  clk_wiz_0 U_CLK_WIZ (
      // Clock out ports
      .clk_out1(clk_100m),  // output clk_out1
      .clk_out2(xclk),      // output clk_out2
      // Status and control signals
      .reset   (reset),     // input reset
      .locked  (locked),    // output locked
      // Clock in ports
      .clk_in1 (clk)
  );  // input clk_in1

  VGA_Decoder u_VGA_Decoder (
      .clk    (clk_100m),
      .reset  (reset),
      .pclk   (rclk),
      .h_sync (h_sync),
      .v_sync (v_sync),
      .x_pixel(x_pixel),
      .y_pixel(y_pixel),
      .DE     (DE)         //display enable
  );


  ImgMemReader #(
      .IMG_SIZE(320 * 240),
      .IMG_W(320),
      .IMG_H(240)
  ) u_ImgMemReader (
      .DE        (DE),
      .x_pixel   (x_pixel),
      .y_pixel   (y_pixel),
      .imgData   (rData),
      .addr      (rAddr),
      .port_red  (hsv_red),
      .port_green(hsv_green),
      .port_blue (hsv_blue)
  );

  Filter_top u_Filter_top (
      .DE          (DE),
      .rclk        (rclk),
      .reset       (reset),
      .x_pixel     (x_pixel),
      .y_pixel     (y_pixel),
      .hsv_red     (hsv_red),
      .hsv_green   (hsv_green),
      .hsv_blue    (hsv_blue),
      .is_red_out  (is_red),
      .is_green_out(is_green),
      .is_blue_out (is_blue)
  );

  Box_top #(
      .NUM_BOXES(2)
  ) u_Box_top (
      .DE           (DE),
      .is_red       (is_red),
      .is_green     (is_green),
      .is_blue      (is_blue),
      .rclk         (rclk),
      .reset        (reset),
      .vsync        (vsync),
      .x_pixel      (x_pixel),
      .y_pixel      (y_pixel),
      .on_blu_box0  (on_blu_box0),
      .on_blu_box1  (on_blu_box1),
      .on_grn_box0  (on_grn_box0),
      .on_grn_box1  (on_grn_box1),
      .on_red_box0  (on_red_box0),
      .on_red_box1  (on_red_box1),
      .red_stb_x_max(red_stb_x_max),
      .red_stb_x_min(red_stb_x_min),
      .red_stb_y_max(red_stb_y_max),
      .red_stb_y_min(red_stb_y_min),
      .red_stb_valid(red_stb_valid)
  );
  // ── image_output ──────────────────────────────────────────────

  image_output u_image_output (
      .x_pixel    (x_pixel),
      .y_pixel    (y_pixel),
      .DE         (DE),
      .img_red    (hsv_red),
      .img_green  (hsv_green),
      .img_blue   (hsv_blue),
      .is_red     (is_red),
      .is_green   (is_green),
      .is_blue    (is_blue),
      // .on_red_box(on_red_box),
      // .on_grn_box(on_grn_box),
      // .on_blu_box(on_blu_box),
      .on_red_box0(on_red_box0),
      .on_red_box1(on_red_box1),
      .on_grn_box0(on_grn_box0),
      .on_grn_box1(on_grn_box1),
      .on_blu_box0(on_blu_box0),
      .on_blu_box1(on_blu_box1),
      .o_img_red  (red_detect),
      .o_img_green(green_detect),
      .o_img_blue (blue_detect)
  );


  FrameBuffer u_FrameBuffer (
      //write side
      .wclk (pclk),
      .we   (we),
      .wAddr(wAddr),
      .wData(wData),
      //read side
      .rclk (rclk),
      .rAddr(rAddr),
      .rData(rData)
  );

  OV7670_MemController u_OV7670_MemController (
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
      .clk     (clk_100m),
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
      .clk          (clk_100m),
      .reset        (reset),
      .sccb_start   (sccb_start),
      .sccb_reg_addr(sccb_reg_addr),
      .sccb_reg_data(sccb_reg_data),
      .sccb_done    (sccb_done),
      .ov_reset     (ov_reset),
      .ov_pwdn      (ov_pwdn),
      .init_done    (init_done)
  );


  vga_overlay U_VGA_OVERLAY (
      .reset      (reset),
      .addr       (addr_up),
      .x_pixel    (x_pixel),
      .y_pixel    (y_pixel),
      .obj_x_1    (center_x[0]),
      .obj_y_1    (center_y[0]),
      .out_valid_1(red_stb_valid[0]),
      .obj_x_2    (center_x[1]),
      .obj_y_2    (center_y[1]),
      .out_valid_2(red_stb_valid[1]),
      .data       (data_up)
  );

  ImgMEMReader_overlay U_IMGMEMREADER_OVERLAY (
      .DE        (DE),
      .x_pixel   (x_pixel),
      .y_pixel   (y_pixel),
      .addr      (addr_up),
      .imgData   (data_up),
      .port_red  (red_img),
      .port_green(green_img),
      .port_blue (blue_img)
  );

  //   manual_control U_MANUAL_CONTROL (
  //       .clk       (clk_100m),
  //       .reset     (reset),
  //       .sw_mode   (sw_mode),
  //       .btn_left  (btn_left),
  //       .btn_right (btn_right),
  //       .btn_up    (btn_up),
  //       .btn_down  (btn_down),
  //       .btn_center(btn_center),
  //       .mode      (ctrl_mode),
  //       .left      (ctrl_left),
  //       .right     (ctrl_right),
  //       .up        (ctrl_up),
  //       .down      (ctrl_down),
  //       .fire      (ctrl_fire)
  //   );

  center u_center (
      .box_x_min(red_stb_x_min),
      .box_x_max(red_stb_x_max),
      .box_y_min(red_stb_y_min),
      .box_y_max(red_stb_y_max),
      .center_x (center_x),
      .center_y (center_y)
  );

  mux_for_spi #(
      .NUM_BOXES(2)
  ) U_MUX_FOR_SPI (
      //input logic btn,
      .box_valid   (red_stb_valid),
      .center_x    (center_x),
      .center_y    (center_y),
      .spi_center_x(center_x[0]),
      .spi_center_y(center_y[0]),
      .spi_valid   (spi_valid)
  );

  //   spi_send_fsm U_SPI_SEND_FSM (
  //       .clk         (clk_100m),
  //       .reset       (reset),
  //       .center_x    (center_x[0]),
  //       .center_y    (center_y[0]),
  //       .box_valid   (spi_valid),
  //       .vsync       (vsync),
  //       .mode        (ctrl_mode),
  //       .btn_left    (ctrl_left),
  //       .btn_right   (ctrl_right),
  //       .btn_up      (ctrl_up),
  //       .btn_down    (ctrl_down),
  //       .fire        (ctrl_fire),
  //       .spi_start   (spi_start),
  //       .spi_tx_data (spi_tx_data),
  //       .spi_done    (spi_done),
  //       .spi_tx_ready(spi_tx_ready)
  //   );

  spi_send_fsm U_SPI_SEND_FSM (
      .clk         (clk_100m),     // 100MHz (spi_master와 같은 클럭)
      .reset       (reset),
      .center_x    (center_x[0]),
      .center_y    (center_y[0]),
      .box_valid   (spi_valid),
      .vsync       (vsync),
      .spi_start   (spi_start),
      .spi_tx_data (spi_tx_data),
      .spi_done    (spi_done),
      .spi_tx_ready(spi_tx_ready)
  );

  spi_master U_SPI_MASTER (
      .clk     (clk_100m),
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


  mux_rgb U_MUX_RGB (
      .sw        (sw_img),
      .red1      (red_detect),
      .red2      (red_img),
      .green1    (green_detect),
      .green2    (green_img),
      .blue1     (blue_detect),
      .blue2     (blue_img),
      .port_red  (port_red),
      .port_green(port_green),
      .port_blue (port_blue)
  );

endmodule

module center #(
    parameter NUM_BOXES = 2
) (
    input  logic [8:0] box_x_min[0:NUM_BOXES-1],
    input  logic [8:0] box_x_max[0:NUM_BOXES-1],
    input  logic [7:0] box_y_min[0:NUM_BOXES-1],
    input  logic [7:0] box_y_max[0:NUM_BOXES-1],
    output logic [8:0] center_x [0:NUM_BOXES-1],
    output logic [7:0] center_y [0:NUM_BOXES-1]
);


  logic [9:0] cx_sum[0:NUM_BOXES-1];
  logic [8:0] cy_sum[0:NUM_BOXES-1];
  always_comb begin
    cx_sum[0]   = {1'b0, box_x_min[0]} + {1'b0, box_x_max[0]};
    cx_sum[1]   = {1'b0, box_x_min[1]} + {1'b0, box_x_max[1]};
    cy_sum[0]   = {1'b0, box_y_min[0]} + {1'b0, box_y_max[0]};
    cy_sum[1]   = {1'b0, box_y_min[1]} + {1'b0, box_y_max[1]};
    center_x[0] = cx_sum[0][9:1];
    center_x[1] = cx_sum[1][9:1];
    center_y[0] = cy_sum[0][8:1];
    center_y[1] = cy_sum[1][8:1];
  end

endmodule

module mux_for_spi #(
    parameter NUM_BOXES = 2
) (
    // input  logic       btn,
    input  logic       box_valid   [0:NUM_BOXES-1],
    input  logic [8:0] center_x    [0:NUM_BOXES-1],
    input  logic [7:0] center_y    [0:NUM_BOXES-1],
    output logic [8:0] spi_center_x,
    output logic [7:0] spi_center_y,
    output logic       spi_valid
);
  //   logic sel;

  assign spi_center_x = center_x[0];
  assign spi_center_y = center_y[0];
  assign spi_valid    = box_valid[0];

endmodule


module mux_rgb (
    input  logic       sw,
    input  logic [3:0] red1,
    input  logic [3:0] red2,
    input  logic [3:0] green1,
    input  logic [3:0] green2,
    input  logic [3:0] blue1,
    input  logic [3:0] blue2,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);
  assign port_red   = sw ? red1 : red2;
  assign port_green = sw ? green1 : green2;
  assign port_blue  = sw ? blue1 : blue2;

endmodule
