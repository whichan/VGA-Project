module Filter_top (
    input  logic       DE,
    input  logic       rclk,
    input  logic       reset,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [3:0] hsv_red,
    input  logic [3:0] hsv_green,
    input  logic [3:0] hsv_blue,
    output logic       is_red_out,
    output logic       is_green_out,
    output logic       is_blue_out
);
  logic [1:0] hue;
  logic [3:0] sat;
  logic [3:0] val;
  logic       is_red_raw;
  logic       is_green_raw;
  logic       is_blue_raw;

  assign is_red_out   = is_red;
  assign is_green_out = is_green;
  assign is_blue_out  = is_blue;


  HSV_Transformer #(
      .S_MIN_RED  (4'd4),
      .V_MIN_RED  (4'd0),
      .V_MAX_RED  (4'd15),
      .S_MIN_GREEN(4'd1),
      .V_MIN_GREEN(4'd0),
      .V_MAX_GREEN(4'd12),
      .S_MIN_BLUE (4'd2),
      .V_MIN_BLUE (4'd0),
      .V_MAX_BLUE (4'd15)
  ) u_HSV_Transfomer (
      .hsv_red  (hsv_red),
      .hsv_green(hsv_green),
      .hsv_blue (hsv_blue),
      .hue      (hue),
      .sat      (sat),
      .val      (val),
      .is_red   (is_red_raw),
      .is_green (is_green_raw),
      .is_blue  (is_blue_raw)
  );

  kernel_color_filter #(
      .IMG_W (320),
      .IMG_H (240),
      .THRESH(4'd5)  // 9픽셀 중 몇 개 이상이면 통과 (4=과반수)
  ) u_kernel_color_filter (
      .rclk        (rclk),
      .reset       (reset),
      .x_pixel     (x_pixel),
      .y_pixel     (y_pixel),
      .DE          (DE),
      .is_red_in   (is_red_raw),
      .is_green_in (is_green_raw),
      .is_blue_in  (is_blue_raw),
      .is_red_out  (is_red),
      .is_green_out(is_green),
      .is_blue_out (is_blue)
  );


endmodule
