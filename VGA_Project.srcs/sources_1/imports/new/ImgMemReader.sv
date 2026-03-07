// `timescale 1ns / 1ps `timescale 1ns / 1ps
// // io : addr
// // in : data

// module ImgMemReader #(
//     parameter IMG_SIZE = 360 * 240,
//     parameter IMG_W = 320,
//     parameter IMG_H = 240
// ) (
//     input  logic                        DE,
//     input  logic [                 9:0] x_pixel,
//     input  logic [                 9:0] y_pixel,
//     input  logic [                15:0] imgData,
//     output logic [$clog2(IMG_SIZE)-1:0] addr,
//     output logic [                 3:0] port_red,
//     output logic [                 3:0] port_green,
//     output logic [                 3:0] port_blue,
//     // Bounding Box 입력 추가
//     input  logic [                 8:0] box_x_min,
//     input  logic [                 8:0] box_x_max,
//     input  logic [                 7:0] box_y_min,
//     input  logic [                 7:0] box_y_max,
//     input  logic                        box_valid
// );


//   logic qvga_de;
//   logic on_box;

//   assign qvga_de = DE && (x_pixel < 320) && (y_pixel < 240);
//   assign addr = qvga_de ? (320 * y_pixel + x_pixel) : 'bz;

//   assign on_box = box_valid && qvga_de && (
//       // 상단/하단 가로선
//       ((y_pixel == box_y_min || y_pixel == box_y_max) && (x_pixel >= box_x_min) && (x_pixel <= box_x_max)) ||
//       // 좌측/우측 세로선
//       ((x_pixel == box_x_min || x_pixel == box_x_max) && (y_pixel >= box_y_min) && (y_pixel <= box_y_max)));

//   // 출력: box 경계면이면 빨간색, 아니면 카메라 영상
//   assign port_red = qvga_de ? (on_box ? 4'hF : imgData[15:12]) : 4'h0;
//   assign port_green = qvga_de ? (on_box ? 4'h0 : imgData[10:7]) : 4'h0;
//   assign port_blue = qvga_de ? (on_box ? 4'h0 : imgData[4:1]) : 4'h0;

//   //==original==
//   // logic qvga_de;

//   // assign qvga_de = DE && (x_pixel < 320) && (y_pixel < 240);
//   // assign addr = qvga_de ? (320 * y_pixel + x_pixel) : 'bz;
//   // assign {port_red, port_green, port_blue} = qvga_de ? {imgData[15:12], imgData[10:7], imgData[4:1]} : 0;


//   //==중앙출력==
//   // localparam X_OFFSET = 160, Y_OFFSET = 120;
//   // // X_OFFSET = (640 - 320) / 2 = 160
//   // // Y_OFFSET = (480 - 240) / 2 = 120
//   // logic img_en;
//   // assign img_en = DE &&
//   //                 (x_pixel >= X_OFFSET) && (x_pixel < X_OFFSET + IMG_W) &&
//   //                 (y_pixel >= Y_OFFSET) && (y_pixel < Y_OFFSET + IMG_H);

//   // assign addr = img_en ? ((y_pixel - Y_OFFSET) * IMG_W + (x_pixel - X_OFFSET)) : '0;
//   // assign {port_red, port_green, port_blue} = img_en ? {imgData[15:12], imgData[10:7], imgData[4:1]} : 12'h000;



// endmodule



// // module ImgMemReader_upscaler (
// //     input  logic                       DE,
// //     input  logic [                9:0] x_pixel,
// //     input  logic [                9:0] y_pixel,
// //     output logic [$clog2(320*240)-1:0] addr,
// //     input  logic [               15:0] imgData,
// //     output logic [                3:0] port_red,
// //     output logic [                3:0] port_green,
// //     output logic [                3:0] port_blue
// // );

// //   // logic qvga_de;  //1/4
// //   //   assign qvga_de = (x_pixel < 320) && (y_pixel < 240);
// //   assign addr = (DE) ? (320 * y_pixel[9:1] + x_pixel[9:1]) : 0; //2차원 이미지를 1차원 주소로 변환

// //   assign {port_red, port_green, port_blue} = (DE) ? {imgData[15:12], imgData[10:7], imgData[4:1]} : 0; //DE=0이면 검정색 

// // endmodule

// `timescale 1ns / 1ps

// module ImgMemReader_upscaler (
//     input  logic                       clk,         // VGA 픽셀 클럭 (25MHz)
//     input  logic                       DE,
//     input  logic [                9:0] x_pixel,
//     input  logic [                9:0] y_pixel,
//     output logic [$clog2(320*240)-1:0] addr,
//     input  logic [               15:0] imgData,     // RGB565 from BRAM
//     output logic [                3:0] port_red,
//     output logic [                3:0] port_green,
//     output logic [                3:0] port_blue
// );


//   wire [8:0] qvga_x = x_pixel[9:1];  // 0~319
//   wire [8:0] qvga_y = y_pixel[9:1];  // 0~239

//   // 홀수 x일 때 다음 픽셀 주소, 짝수일 때 현재 픽셀 주소
//   wire [8:0] read_x = x_pixel[0] ? (qvga_x + 1) : qvga_x;

//   // 오른쪽 끝 경계 처리 (319 넘어가면 319로 클램프)
//   wire [8:0] clamped_x = (read_x > 319) ? 319 : read_x;

//   assign addr = (DE) ? (320 * qvga_y + clamped_x) : 0;

//   // 현재 BRAM 데이터에서 RGB 추출 (RGB565 → 각 4비트)
//   wire [3:0] cur_r = imgData[15:12];
//   wire [3:0] cur_g = imgData[10:7];
//   wire [3:0] cur_b = imgData[4:1];

//   // 이전 픽셀 저장 레지스터
//   reg [3:0] prev_r, prev_g, prev_b;

//   // 짝수 x에서 읽은 값 = 원본 픽셀 → 저장
//   always_ff @(posedge clk) begin
//     if (!DE) begin
//       prev_r <= 4'd0;
//       prev_g <= 4'd0;
//       prev_b <= 4'd0;
//     end else if (!x_pixel[0]) begin
//       // 짝수 x: 현재 BRAM 데이터가 원본 픽셀
//       prev_r <= cur_r;
//       prev_g <= cur_g;
//       prev_b <= cur_b;
//     end
//   end

//   // 평균 계산 (보간)
//   // (a + b) >> 1 = 평균 (4비트 + 4비트 → 5비트 → 시프트)
//   wire [4:0] avg_r = ({1'b0, prev_r} + {1'b0, cur_r});  // 5비트 합
//   wire [4:0] avg_g = ({1'b0, prev_g} + {1'b0, cur_g});
//   wire [4:0] avg_b = ({1'b0, prev_b} + {1'b0, cur_b});

//   // 출력 MUX
//   // 짝수 x → 원본 픽셀 그대로
//   // 홀수 x → 이전 픽셀과 현재(다음) 픽셀의 평균
//   always_comb begin
//     if (!DE) begin
//       port_red   = 4'd0;
//       port_green = 4'd0;
//       port_blue  = 4'd0;
//     end else if (!x_pixel[0]) begin
//       // 짝수 x: 원본 픽셀
//       port_red   = cur_r;
//       port_green = cur_g;
//       port_blue  = cur_b;
//     end else begin
//       // 홀수 x: 좌우 평균 (보간)
//       port_red   = avg_r[4:1];  // 5비트 합을 1비트 우시프트 = 평균
//       port_green = avg_g[4:1];
//       port_blue  = avg_b[4:1];
//     end
//   end

// endmodule


//////////////////////////////
`timescale 1ns / 1ps
//=============================================================================
// ImgMemReader — 업스케일 보간 + 바운딩 박스 + 좌표 텍스트 표시
//
// 기능:
//   1. 320×240 → 640×480 업스케일 (가로 바이리니어 보간)
//   2. 바운딩 박스 테두리 오버레이 (빨간색)
//   3. 중심점 크로스헤어 (노란색)
//   4. 좌상단 좌표 텍스트 표시 (X:nnn Y:nnn)
//=============================================================================
module ImgMemReader #(
    parameter IMG_SIZE = 320 * 240,
    parameter IMG_W    = 320,
    parameter IMG_H    = 240
) (
    input  logic                        clk,
    input  logic                        DE,
    input  logic [                 9:0] x_pixel,
    input  logic [                 9:0] y_pixel,
    input  logic [                15:0] imgData,
    output logic [$clog2(IMG_SIZE)-1:0] addr,
    output logic [                 3:0] port_red,
    output logic [                 3:0] port_green,
    output logic [                 3:0] port_blue,
    input  logic [                 8:0] box_x_min,
    input  logic [                 8:0] box_x_max,
    input  logic [                 7:0] box_y_min,
    input  logic [                 7:0] box_y_max,
    input  logic                        box_valid
);

  // =========================================================================
  // QVGA 좌표 변환
  // =========================================================================
  wire [8:0] qvga_x = x_pixel[9:1];
  wire [7:0] qvga_y = y_pixel[9:1];

  // =========================================================================
  // BRAM 주소 생성 (보간용)
  // =========================================================================
  wire [8:0] read_x = x_pixel[0] ? (qvga_x + 1) : qvga_x;
  wire [8:0] clamped_x = (read_x > (IMG_W - 1)) ? (IMG_W - 1) : read_x;
  assign addr = DE ? (IMG_W * qvga_y + clamped_x) : '0;

  // =========================================================================
  // RGB565 → RGB444
  // =========================================================================
  wire [3:0] cur_r = imgData[15:12];
  wire [3:0] cur_g = imgData[10:7];
  wire [3:0] cur_b = imgData[4:1];

  // =========================================================================
  // 이전 픽셀 저장 (보간용)
  // =========================================================================
  reg [3:0] prev_r, prev_g, prev_b;
  always_ff @(posedge clk) begin
    if (!DE) begin
      prev_r <= 4'd0;
      prev_g <= 4'd0;
      prev_b <= 4'd0;
    end else if (!x_pixel[0]) begin
      prev_r <= cur_r;
      prev_g <= cur_g;
      prev_b <= cur_b;
    end
  end

  // =========================================================================
  // 보간 평균
  // =========================================================================
  wire [3:0] avg_r = ({1'b0, prev_r} + {1'b0, cur_r}) >> 1;
  wire [3:0] avg_g = ({1'b0, prev_g} + {1'b0, cur_g}) >> 1;
  wire [3:0] avg_b = ({1'b0, prev_b} + {1'b0, cur_b}) >> 1;

  wire [3:0] img_r = x_pixel[0] ? avg_r : cur_r;
  wire [3:0] img_g = x_pixel[0] ? avg_g : cur_g;
  wire [3:0] img_b = x_pixel[0] ? avg_b : cur_b;

  // =========================================================================
  // 바운딩 박스 (×2 스케일)
  // =========================================================================
  wire [9:0] bx_min = {box_x_min, 1'b0};
  wire [9:0] bx_max = {box_x_max, 1'b0} + 1;
  wire [9:0] by_min = {box_y_min, 1'b0};
  wire [9:0] by_max = {box_y_max, 1'b0} + 1;

  wire on_left   = (x_pixel >= bx_min) && (x_pixel <= bx_min + 1)
                     && (y_pixel >= by_min) && (y_pixel <= by_max);
  wire on_right  = (x_pixel >= bx_max - 1) && (x_pixel <= bx_max)
                     && (y_pixel >= by_min) && (y_pixel <= by_max);
  wire on_top    = (y_pixel >= by_min) && (y_pixel <= by_min + 1)
                     && (x_pixel >= bx_min) && (x_pixel <= bx_max);
  wire on_bottom = (y_pixel >= by_max - 1) && (y_pixel <= by_max)
                     && (x_pixel >= bx_min) && (x_pixel <= bx_max);

  wire on_box = box_valid && (on_left || on_right || on_top || on_bottom);

  // =========================================================================
  // 중심점 크로스헤어
  // =========================================================================
  wire [9:0] cx = (bx_min + bx_max) >> 1;
  wire [9:0] cy = (by_min + by_max) >> 1;

  wire on_cross = box_valid && (
        ((x_pixel == cx) && (y_pixel >= cy - 5) && (y_pixel <= cy + 5)) ||
        ((y_pixel == cy) && (x_pixel >= cx - 5) && (x_pixel <= cx + 5))
    );

  // =========================================================================
  // 중심점 QVGA 좌표 (텍스트 표시용)
  // =========================================================================
  wire [9:0] center_x_val = (box_x_min + box_x_max) >> 1;
  wire [8:0] center_y_val = (box_y_min + box_y_max) >> 1;

  // =========================================================================
  // 텍스트 오버레이 인스턴스
  // =========================================================================
  logic text_on;
  logic [3:0] text_r, text_g, text_b;
  logic bg_on;

  text_overlay u_text_overlay (
      .x_pixel    (x_pixel),
      .y_pixel    (y_pixel),
      .DE         (DE),
      .center_x   (center_x_val),
      .center_y   (center_y_val),
      .coord_valid(box_valid),
      .text_on    (text_on),
      .text_r     (text_r),
      .text_g     (text_g),
      .text_b     (text_b),
      .bg_on      (bg_on)
  );

  // =========================================================================
  // 최종 출력
  // 우선순위: 텍스트 > 텍스트배경 > 크로스헤어 > 박스 > 보간영상
  // =========================================================================
  always_comb begin
    if (!DE) begin
      port_red   = 4'd0;
      port_green = 4'd0;
      port_blue  = 4'd0;
    end else if (text_on) begin
      port_red   = text_r;
      port_green = text_g;
      port_blue  = text_b;
    end else if (bg_on) begin
      port_red   = img_r >> 1;
      port_green = img_g >> 1;
      port_blue  = img_b >> 1;
    end else if (on_cross) begin
      port_red   = 4'hF;
      port_green = 4'hD;
      port_blue  = 4'h0;
    end else if (on_box) begin
      port_red   = 4'hF;
      port_green = 4'h0;
      port_blue  = 4'h0;
    end else begin
      port_red   = img_r;
      port_green = img_g;
      port_blue  = img_b;
    end
  end

endmodule
