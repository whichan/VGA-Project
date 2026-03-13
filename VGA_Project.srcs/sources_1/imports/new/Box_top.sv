`timescale 1ns / 1ps

module Box_top #(
    parameter NUM_BOXES = 2
) (
    input  logic       DE,
    input  logic       is_red,
    input  logic       is_green,
    input  logic       is_blue,
    input  logic       rclk,
    input  logic       reset,
    input  logic       vsync,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    output logic       on_blu_box0,
    output logic       on_blu_box1,
    output logic       on_grn_box0,
    output logic       on_grn_box1,
    output logic       on_red_box0,
    output logic       on_red_box1,

    output logic [8:0] red_stb_x_max[0:NUM_BOXES-1],
    output logic [8:0] red_stb_x_min[0:NUM_BOXES-1],
    output logic [7:0] red_stb_y_max[0:NUM_BOXES-1],
    output logic [7:0] red_stb_y_min[0:NUM_BOXES-1],
    output logic       red_stb_valid[0:NUM_BOXES-1]
);



  // ── box_maker raw 출력 ────────────────────────────────────────
  logic [8:0] red_raw_x_min[0:NUM_BOXES-1];
  logic [8:0] red_raw_x_max[0:NUM_BOXES-1];
  logic [7:0] red_raw_y_min[0:NUM_BOXES-1];
  logic [7:0] red_raw_y_max[0:NUM_BOXES-1];
  logic       red_raw_valid[0:NUM_BOXES-1];

  logic [8:0] grn_raw_x_min[0:NUM_BOXES-1];
  logic [8:0] grn_raw_x_max[0:NUM_BOXES-1];
  logic [7:0] grn_raw_y_min[0:NUM_BOXES-1];
  logic [7:0] grn_raw_y_max[0:NUM_BOXES-1];
  logic       grn_raw_valid[0:NUM_BOXES-1];

  logic [8:0] blu_raw_x_min[0:NUM_BOXES-1];
  logic [8:0] blu_raw_x_max[0:NUM_BOXES-1];
  logic [7:0] blu_raw_y_min[0:NUM_BOXES-1];
  logic [7:0] blu_raw_y_max[0:NUM_BOXES-1];
  logic       blu_raw_valid[0:NUM_BOXES-1];

  // ── box_stabilizer 안정화 출력 ────────────────────────────────
  // logic [8:0] red_stb_x_min[0:NUM_BOXES-1];
  // logic [8:0] red_stb_x_max[0:NUM_BOXES-1];
  // logic [7:0] red_stb_y_min[0:NUM_BOXES-1];
  // logic [7:0] red_stb_y_max[0:NUM_BOXES-1];
  // logic       red_stb_valid[0:NUM_BOXES-1];

  logic [8:0] grn_stb_x_min[0:NUM_BOXES-1];
  logic [8:0] grn_stb_x_max[0:NUM_BOXES-1];
  logic [7:0] grn_stb_y_min[0:NUM_BOXES-1];
  logic [7:0] grn_stb_y_max[0:NUM_BOXES-1];
  logic       grn_stb_valid[0:NUM_BOXES-1];

  logic [8:0] blu_stb_x_min[0:NUM_BOXES-1];
  logic [8:0] blu_stb_x_max[0:NUM_BOXES-1];
  logic [7:0] blu_stb_y_min[0:NUM_BOXES-1];
  logic [7:0] blu_stb_y_max[0:NUM_BOXES-1];
  logic       blu_stb_valid[0:NUM_BOXES-1];
  // ── box_tracker 출력 ─────────────────────────────────────────
  logic [8:0] red_trk_x_min[0:NUM_BOXES-1];
  logic [8:0] red_trk_x_max[0:NUM_BOXES-1];
  logic [7:0] red_trk_y_min[0:NUM_BOXES-1];
  logic [7:0] red_trk_y_max[0:NUM_BOXES-1];
  logic       red_trk_valid[0:NUM_BOXES-1];

  logic [8:0] grn_trk_x_min[0:NUM_BOXES-1];
  logic [8:0] grn_trk_x_max[0:NUM_BOXES-1];
  logic [7:0] grn_trk_y_min[0:NUM_BOXES-1];
  logic [7:0] grn_trk_y_max[0:NUM_BOXES-1];
  logic       grn_trk_valid[0:NUM_BOXES-1];

  logic [8:0] blu_trk_x_min[0:NUM_BOXES-1];
  logic [8:0] blu_trk_x_max[0:NUM_BOXES-1];
  logic [7:0] blu_trk_y_min[0:NUM_BOXES-1];
  logic [7:0] blu_trk_y_max[0:NUM_BOXES-1];
  logic       blu_trk_valid[0:NUM_BOXES-1];

  assign red_stb_x_max = red_trk_x_max;
  assign red_stb_x_min = red_trk_x_min;
  assign red_stb_y_max = red_trk_y_max;
  assign red_stb_y_min = red_trk_y_min;
  assign red_stb_valid = red_trk_valid;

  //  box_maker - 생성 후 유지
  //── box_maker: RED ────────────────────────────────────────────
  box_maker #(
      .IMG_W     (320),
      .IMG_H     (240),
      .NUM_BOXES (NUM_BOXES),
      .MAX_BOX_W (160),
      .MAX_BOX_H (120),
      .CREATE_MIN(200),
      .HOLD_MIN  (10),
      .HOLD_MAX  (10),
      .MAX_RUNS  (4)
  ) u_box_maker_red (
      .rclk     (rclk),
      .reset    (reset),
      .vsync    (vsync),
      .DE       (DE),
      .x_pixel  (x_pixel),
      .y_pixel  (y_pixel),
      .is_target(is_red),
      .box_x_min(red_raw_x_min),
      .box_x_max(red_raw_x_max),
      .box_y_min(red_raw_y_min),
      .box_y_max(red_raw_y_max),
      .box_valid(red_raw_valid)
  );

  // ── box_maker: GREEN ──────────────────────────────────────────
  box_maker #(
      .IMG_W     (320),
      .IMG_H     (240),
      .NUM_BOXES (NUM_BOXES),
      .MAX_BOX_W (160),
      .MAX_BOX_H (120),
      .CREATE_MIN(200),
      .HOLD_MIN  (10),
      .HOLD_MAX  (10),
      .MAX_RUNS  (4)
  ) u_box_maker_green (
      .rclk     (rclk),
      .reset    (reset),
      .vsync    (vsync),
      .DE       (DE),
      .x_pixel  (x_pixel),
      .y_pixel  (y_pixel),
      .is_target(is_green),
      .box_x_min(grn_raw_x_min),
      .box_x_max(grn_raw_x_max),
      .box_y_min(grn_raw_y_min),
      .box_y_max(grn_raw_y_max),
      .box_valid(grn_raw_valid)
  );

  // ── box_maker: BLUE ───────────────────────────────────────────
  box_maker #(
      .IMG_W     (320),
      .IMG_H     (240),
      .NUM_BOXES (NUM_BOXES),
      .MAX_BOX_W (160),
      .MAX_BOX_H (120),
      .CREATE_MIN(150),
      .HOLD_MIN  (10),
      .HOLD_MAX  (10),
      .MAX_RUNS  (4)
  ) u_box_maker_blue (
      .rclk     (rclk),
      .reset    (reset),
      .vsync    (vsync),
      .DE       (DE),
      .x_pixel  (x_pixel),
      .y_pixel  (y_pixel),
      .is_target(is_blue),
      .box_x_min(blu_raw_x_min),
      .box_x_max(blu_raw_x_max),
      .box_y_min(blu_raw_y_min),
      .box_y_max(blu_raw_y_max),
      .box_valid(blu_raw_valid)
  );

  // ── box_tracker: RED ─────────────────────────────────────────
  box_tracker #(
      .NUM_BOXES  (NUM_BOXES),
      .DIST_THRESH(100),
      .HOLD_MAX   (20)
  ) u_trk_red (
      .clk      (rclk),
      .reset    (reset),
      .vsync    (vsync),
      .raw_x_min(red_raw_x_min),
      .raw_x_max(red_raw_x_max),
      .raw_y_min(red_raw_y_min),
      .raw_y_max(red_raw_y_max),
      .raw_valid(red_raw_valid),
      .trk_x_min(red_trk_x_min),
      .trk_x_max(red_trk_x_max),
      .trk_y_min(red_trk_y_min),
      .trk_y_max(red_trk_y_max),
      .trk_valid(red_trk_valid)
  );

  // ── box_tracker: GREEN ────────────────────────────────────────
  box_tracker #(
      .NUM_BOXES  (NUM_BOXES),
      .DIST_THRESH(100),
      .HOLD_MAX   (20)
  ) u_trk_green (
      .clk      (rclk),
      .reset    (reset),
      .vsync    (vsync),
      .raw_x_min(grn_raw_x_min),
      .raw_x_max(grn_raw_x_max),
      .raw_y_min(grn_raw_y_min),
      .raw_y_max(grn_raw_y_max),
      .raw_valid(grn_raw_valid),
      .trk_x_min(grn_trk_x_min),
      .trk_x_max(grn_trk_x_max),
      .trk_y_min(grn_trk_y_min),
      .trk_y_max(grn_trk_y_max),
      .trk_valid(grn_trk_valid)
  );

  // ── box_tracker: BLUE ─────────────────────────────────────────
  box_tracker #(
      .NUM_BOXES  (NUM_BOXES),
      .DIST_THRESH(100),
      .HOLD_MAX   (20)
  ) u_trk_blue (
      .clk      (rclk),
      .reset    (reset),
      .vsync    (vsync),
      .raw_x_min(blu_raw_x_min),
      .raw_x_max(blu_raw_x_max),
      .raw_y_min(blu_raw_y_min),
      .raw_y_max(blu_raw_y_max),
      .raw_valid(blu_raw_valid),
      .trk_x_min(blu_trk_x_min),
      .trk_x_max(blu_trk_x_max),
      .trk_y_min(blu_trk_y_min),
      .trk_y_max(blu_trk_y_max),
      .trk_valid(blu_trk_valid)
  );

  // box 로우 데이터
  box_edge_img #(
      .NUM_BOXES(2),
      .BOX_THICK(1)
  ) u_box_edge_img (
      .x_pixel      (x_pixel),
      .y_pixel      (y_pixel),
      .red_box_x_min(red_trk_x_min),
      .red_box_x_max(red_trk_x_max),
      .red_box_y_min(red_trk_y_min),
      .red_box_y_max(red_trk_y_max),
      .red_box_valid(red_trk_valid),
      .grn_box_x_min(grn_trk_x_min),
      .grn_box_x_max(grn_trk_x_max),
      .grn_box_y_min(grn_trk_y_min),
      .grn_box_y_max(grn_trk_y_max),
      .grn_box_valid(grn_trk_valid),
      .blu_box_x_min(blu_trk_x_min),
      .blu_box_x_max(blu_trk_x_max),
      .blu_box_y_min(blu_trk_y_min),
      .blu_box_y_max(blu_trk_y_max),
      .blu_box_valid(blu_trk_valid),
      .on_red_box0  (on_red_box0),
      .on_red_box1  (on_red_box1),
      .on_grn_box0  (on_grn_box0),
      .on_grn_box1  (on_grn_box1),
      .on_blu_box0  (on_blu_box0),
      .on_blu_box1  (on_blu_box1)
  );

endmodule
