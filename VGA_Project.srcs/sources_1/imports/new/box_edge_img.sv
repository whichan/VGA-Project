

// // box 색깔 구분 x
//     `timescale 1ns / 1ps

//     // box_edge_img
//     // 현재 픽셀(cam_x, cam_y)이 각 색상 bounding box의 테두리 위인지 판별
//     // image_output에서 분리된 모듈

//     module box_edge_img #(
//         parameter NUM_BOXES = 2,
//         parameter BOX_THICK = 1
//     ) (
//         input logic [9:0] x_pixel,  // 카메라 좌표 (0~319)
//         input logic [9:0] y_pixel,  // 카메라 좌표 (0~239)

//         input logic [8:0] red_box_x_min[0:NUM_BOXES-1],
//         input logic [8:0] red_box_x_max[0:NUM_BOXES-1],
//         input logic [7:0] red_box_y_min[0:NUM_BOXES-1],
//         input logic [7:0] red_box_y_max[0:NUM_BOXES-1],
//         input logic       red_box_valid[0:NUM_BOXES-1],

//         input logic [8:0] grn_box_x_min[0:NUM_BOXES-1],
//         input logic [8:0] grn_box_x_max[0:NUM_BOXES-1],
//         input logic [7:0] grn_box_y_min[0:NUM_BOXES-1],
//         input logic [7:0] grn_box_y_max[0:NUM_BOXES-1],
//         input logic       grn_box_valid[0:NUM_BOXES-1],

//         input logic [8:0] blu_box_x_min[0:NUM_BOXES-1],
//         input logic [8:0] blu_box_x_max[0:NUM_BOXES-1],
//         input logic [7:0] blu_box_y_min[0:NUM_BOXES-1],
//         input logic [7:0] blu_box_y_max[0:NUM_BOXES-1],
//         input logic       blu_box_valid[0:NUM_BOXES-1],

//         output logic on_red_box,
//         output logic on_grn_box,
//         output logic on_blu_box
//     );

//         logic [8:0] cam_x;  // 카메라 좌표 (0~319)
//         logic [7:0] cam_y;  // 카메라 좌표 (0~239)

//         assign cam_x = (x_pixel < 320) ? x_pixel[8:0] : (x_pixel - 10'd320);
//         assign cam_y = (y_pixel < 240) ? y_pixel[7:0] : (y_pixel - 10'd240);

//         function automatic logic on_box_edge(input logic [8:0] cx, input logic [7:0] cy, input logic [8:0] xmin, xmax,
//                                              input logic [7:0] ymin, ymax, input logic valid);
//             logic on_h, on_v;
//             on_h = valid &&
//                    (cx >= xmin) && (cx <= xmax) &&
//                    ((cy >= ymin && cy <= ymin + BOX_THICK - 1) ||
//                     (cy <= ymax && cy >= ymax - BOX_THICK + 1));
//             on_v = valid &&
//                    (cy >= ymin) && (cy <= ymax) &&
//                    ((cx >= xmin && cx <= xmin + BOX_THICK - 1) ||
//                     (cx <= xmax && cx >= xmax - BOX_THICK + 1));
//             return on_h || on_v;
//         endfunction

//         always_comb begin
//             on_red_box = 1'b0;
//             on_grn_box = 1'b0;
//             on_blu_box = 1'b0;
//             for (int i = 0; i < NUM_BOXES; i++) begin
//                 if (on_box_edge(
//                         cam_x,
//                         cam_y,
//                         red_box_x_min[i],
//                         red_box_x_max[i],
//                         red_box_y_min[i],
//                         red_box_y_max[i],
//                         red_box_valid[i]
//                     ))
//                     on_red_box = 1'b1;

//                 if (on_box_edge(
//                         cam_x,
//                         cam_y,
//                         grn_box_x_min[i],
//                         grn_box_x_max[i],
//                         grn_box_y_min[i],
//                         grn_box_y_max[i],
//                         grn_box_valid[i]
//                     ))
//                     on_grn_box = 1'b1;

//                 if (on_box_edge(
//                         cam_x,
//                         cam_y,
//                         blu_box_x_min[i],
//                         blu_box_x_max[i],
//                         blu_box_y_min[i],
//                         blu_box_y_max[i],
//                         blu_box_valid[i]
//                     ))
//                     on_blu_box = 1'b1;
//             end
//         end

//     endmodule


`timescale 1ns / 1ps
 
// box_edge_img v4
// - 박스 테두리 판별
// - box[0] → on_*_box0 (흰색용)
// - box[1] → on_*_box1 (노란색용)
// image_output에서 box0=흰색, box1=노란색으로 처리
 
module box_edge_img #(
    parameter NUM_BOXES = 2,
    parameter BOX_THICK = 1
) (
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
 
    input  logic [8:0] red_box_x_min [0:NUM_BOXES-1],
    input  logic [8:0] red_box_x_max [0:NUM_BOXES-1],
    input  logic [7:0] red_box_y_min [0:NUM_BOXES-1],
    input  logic [7:0] red_box_y_max [0:NUM_BOXES-1],
    input  logic       red_box_valid [0:NUM_BOXES-1],
 
    input  logic [8:0] grn_box_x_min [0:NUM_BOXES-1],
    input  logic [8:0] grn_box_x_max [0:NUM_BOXES-1],
    input  logic [7:0] grn_box_y_min [0:NUM_BOXES-1],
    input  logic [7:0] grn_box_y_max [0:NUM_BOXES-1],
    input  logic       grn_box_valid [0:NUM_BOXES-1],
 
    input  logic [8:0] blu_box_x_min [0:NUM_BOXES-1],
    input  logic [8:0] blu_box_x_max [0:NUM_BOXES-1],
    input  logic [7:0] blu_box_y_min [0:NUM_BOXES-1],
    input  logic [7:0] blu_box_y_max [0:NUM_BOXES-1],
    input  logic       blu_box_valid [0:NUM_BOXES-1],
 
    // box[0]: 흰색, box[1]: 노란색
    output logic on_red_box0, on_red_box1,
    output logic on_grn_box0, on_grn_box1,
    output logic on_blu_box0, on_blu_box1
);
 
    // ── 카메라 좌표 변환 ──────────────────────────────────────────
    logic [9:0] cam_x_10, cam_y_10;
    assign cam_x_10 = (x_pixel < 320) ? x_pixel : (x_pixel - 10'd320);
    assign cam_y_10 = (y_pixel < 240) ? y_pixel : (y_pixel - 10'd240);
 
    logic [8:0] cam_x;
    logic [7:0] cam_y;
    assign cam_x = cam_x_10[8:0];
    assign cam_y = cam_y_10[7:0];
 
    // ── 테두리 판별 함수 ──────────────────────────────────────────
    function automatic logic on_box_edge(
        input logic [8:0] cx, input logic [7:0] cy,
        input logic [8:0] xmin, xmax,
        input logic [7:0] ymin, ymax,
        input logic       valid
    );
        logic on_h, on_v;
        on_h = valid && (cx >= xmin) && (cx <= xmax) &&
               ((cy >= ymin && cy <= ymin + BOX_THICK - 1) ||
                (cy <= ymax && cy >= ymax - BOX_THICK + 1));
        on_v = valid && (cy >= ymin) && (cy <= ymax) &&
               ((cx >= xmin && cx <= xmin + BOX_THICK - 1) ||
                (cx <= xmax && cx >= xmax - BOX_THICK + 1));
        return on_h || on_v;
    endfunction
 
    // ── combinational 출력 ────────────────────────────────────────
    always_comb begin
        on_red_box0 = on_box_edge(cam_x, cam_y,
                        red_box_x_min[0], red_box_x_max[0],
                        red_box_y_min[0], red_box_y_max[0],
                        red_box_valid[0]);
        on_red_box1 = on_box_edge(cam_x, cam_y,
                        red_box_x_min[1], red_box_x_max[1],
                        red_box_y_min[1], red_box_y_max[1],
                        red_box_valid[1]);
 
        on_grn_box0 = on_box_edge(cam_x, cam_y,
                        grn_box_x_min[0], grn_box_x_max[0],
                        grn_box_y_min[0], grn_box_y_max[0],
                        grn_box_valid[0]);
        on_grn_box1 = on_box_edge(cam_x, cam_y,
                        grn_box_x_min[1], grn_box_x_max[1],
                        grn_box_y_min[1], grn_box_y_max[1],
                        grn_box_valid[1]);
 
        on_blu_box0 = on_box_edge(cam_x, cam_y,
                        blu_box_x_min[0], blu_box_x_max[0],
                        blu_box_y_min[0], blu_box_y_max[0],
                        blu_box_valid[0]);
        on_blu_box1 = on_box_edge(cam_x, cam_y,
                        blu_box_x_min[1], blu_box_x_max[1],
                        blu_box_y_min[1], blu_box_y_max[1],
                        blu_box_valid[1]);
    end
 
endmodule