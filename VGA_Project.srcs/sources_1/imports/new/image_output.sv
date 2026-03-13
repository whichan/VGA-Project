`timescale 1ns / 1ps

// image_output
// box0 → 흰색 테두리
// box1 → 노란색 테두리 (R=F, G=F, B=0)
//
// ┌──────────────┬──────────────┐
// │  원본 영상    │  빨강 감지   │
// ├──────────────┼──────────────┤
// │  초록 감지    │  파랑 감지   │
// └──────────────┴──────────────┘

module image_output (
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic       DE,

    input  logic [3:0] img_red,
    input  logic [3:0] img_green,
    input  logic [3:0] img_blue,

    input  logic       is_red,
    input  logic       is_green,
    input  logic       is_blue,

    // box[0]: 흰색, box[1]: 노란색
    input  logic       on_red_box0, on_red_box1,
    input  logic       on_grn_box0, on_grn_box1,
    input  logic       on_blu_box0, on_blu_box1,

    output logic [3:0] o_img_red,
    output logic [3:0] o_img_green,
    output logic [3:0] o_img_blue
);

    logic cell_tl, cell_tr, cell_bl;
    assign cell_tl = (x_pixel <  320) && (y_pixel <  240);
    assign cell_tr = (x_pixel >= 320) && (y_pixel <  240);
    assign cell_bl = (x_pixel <  320) && (y_pixel >= 240);

    logic in_de;
    assign in_de = DE && (x_pixel < 640) && (y_pixel < 480);

    // 박스 색상 결정 태스크 (흰색 우선, 그 다음 노란색)
    // white=box0, yellow=box1
    function automatic void box_color(
        input  logic       box0, box1,
        output logic [3:0] r, g, b
    );
        if (box0) begin
            r = 4'hF; g = 4'hF; b = 4'hF;  // 흰색
        end else if (box1) begin
            r = 4'hF; g = 4'hF; b = 4'h0;  // 노란색
        end else begin
            r = 4'h0; g = 4'h0; b = 4'h0;  // 박스 없음 (호출자가 처리)
        end
    endfunction

    always_comb begin
        if (!in_de) begin
            o_img_red = 4'h0; o_img_green = 4'h0; o_img_blue = 4'h0;

        end else if (cell_tl) begin
            // 좌상: 원본 + 모든 색상 박스 오버레이
            if (on_red_box0 || on_grn_box0 || on_blu_box0)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
            else if (on_red_box1 || on_grn_box1 || on_blu_box1)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'h0};
            else
                {o_img_red, o_img_green, o_img_blue} = {img_red, img_green, img_blue};

        end else if (cell_tr) begin
            // 우상: 빨강 감지
            if (on_red_box0)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
            else if (on_red_box1)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'h0};
            else begin
                o_img_red   = is_red ? 4'hF : (img_red   >> 2);
                o_img_green = is_red ? 4'h0 : (img_green >> 2);
                o_img_blue  = is_red ? 4'h0 : (img_blue  >> 2);
            end

        end else if (cell_bl) begin
            // 좌하: 초록 감지
            if (on_grn_box0)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
            else if (on_grn_box1)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'h0};
            else begin
                o_img_red   = is_green ? 4'h0 : (img_red   >> 2);
                o_img_green = is_green ? 4'hF : (img_green >> 2);
                o_img_blue  = is_green ? 4'h0 : (img_blue  >> 2);
            end

        end else begin  // cell_br
            // 우하: 파랑 감지
            if (on_blu_box0)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
            else if (on_blu_box1)
                {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'h0};
            else begin
                o_img_red   = is_blue ? 4'h0 : (img_red   >> 2);
                o_img_green = is_blue ? 4'h0 : (img_green >> 2);
                o_img_blue  = is_blue ? 4'hF : (img_blue  >> 2);
            end
        end
    end

endmodule

// // 번호 없는거
//     `timescale 1ns / 1ps

//     // image_output (경량화)
//     // box 테두리 판별은 box_edge_img에서 담당
//     // 이 모듈은 최종 픽셀 색상 출력만 담당
//     //
//     // ┌──────────────┬──────────────┐
//     // │  원본 영상    │  빨강 감지   │
//     // ├──────────────┼──────────────┤
//     // │  초록 감지    │  파랑 감지   │
//     // └──────────────┴──────────────┘

//     module image_output (
//         input  logic [9:0] x_pixel,
//         input  logic [9:0] y_pixel,
//         input  logic       DE,

//         input  logic [3:0] img_red,
//         input  logic [3:0] img_green,
//         input  logic [3:0] img_blue,

//         input  logic       is_red,
//         input  logic       is_green,
//         input  logic       is_blue,

//         // box_edge_img에서 넘어온 테두리 판별 결과
//         input  logic       on_red_box,
//         input  logic       on_grn_box,
//         input  logic       on_blu_box,

//         output logic [3:0] o_img_red,
//         output logic [3:0] o_img_green,
//         output logic [3:0] o_img_blue
//     );

//         logic cell_tl, cell_tr, cell_bl;
//         assign cell_tl = (x_pixel <  320) && (y_pixel <  240);
//         assign cell_tr = (x_pixel >= 320) && (y_pixel <  240);
//         assign cell_bl = (x_pixel <  320) && (y_pixel >= 240);

//         logic in_de;
//         assign in_de = DE && (x_pixel < 640) && (y_pixel < 480);

//         always_comb begin
//             if (!in_de) begin
//                 o_img_red = 4'h0; o_img_green = 4'h0; o_img_blue = 4'h0;

//             end else if (cell_tl) begin
//                 if (on_red_box || on_grn_box || on_blu_box)
//                     {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
//                 else
//                     {o_img_red, o_img_green, o_img_blue} = {img_red, img_green, img_blue};

//             end else if (cell_tr) begin
//                 if (on_red_box)
//                     {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
//                 else begin
//                     o_img_red   = is_red ? 4'hF : (img_red   >> 2);
//                     o_img_green = is_red ? 4'h0 : (img_green >> 2);
//                     o_img_blue  = is_red ? 4'h0 : (img_blue  >> 2);
//                 end

//             end else if (cell_bl) begin
//                 if (on_grn_box)
//                     {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
//                 else begin
//                     o_img_red   = is_green ? 4'h0 : (img_red   >> 2);
//                     o_img_green = is_green ? 4'hF : (img_green >> 2);
//                     o_img_blue  = is_green ? 4'h0 : (img_blue  >> 2);
//                 end

//             end else begin  // cell_br
//                 if (on_blu_box)
//                     {o_img_red, o_img_green, o_img_blue} = {4'hF, 4'hF, 4'hF};
//                 else begin
//                     o_img_red   = is_blue ? 4'h0 : (img_red   >> 2);
//                     o_img_green = is_blue ? 4'h0 : (img_green >> 2);
//                     o_img_blue  = is_blue ? 4'hF : (img_blue  >> 2);
//                 end
//             end
//         end

//     endmodule


// // 엣지까지 디텍팅
// // `timescale 1ns / 1ps

// // // image_output
// // // 4분할 디버그 화면 + 박스 오버레이
// // // ┌──────────────┬──────────────┐
// // // │  원본 영상    │  빨강 감지   │
// // // ├──────────────┼──────────────┤
// // // │  초록 감지    │  파랑 감지   │
// // // └──────────────┴──────────────┘
// // // 각 셀에 해당 색상의 bounding box를 흰색 테두리로 오버레이

// // module image_output #(
// //     parameter NUM_BOXES = 2,
// //     parameter BOX_THICK = 1   // 박스 테두리 두께 (픽셀)
// // ) (
// //     input  logic [9:0] x_pixel,
// //     input  logic [9:0] y_pixel,
// //     input  logic       DE,

// //     // 원본 RGB
// //     input  logic [3:0] img_red,
// //     input  logic [3:0] img_green,
// //     input  logic [3:0] img_blue,

// //     // kernel_color_filter 판별 결과
// //     input  logic       is_red,
// //     input  logic       is_green,
// //     input  logic       is_blue,

// //     // RED 박스 (카메라 좌표 기준 0~319, 0~239)
// //     input  logic [8:0] red_box_x_min [0:NUM_BOXES-1],
// //     input  logic [8:0] red_box_x_max [0:NUM_BOXES-1],
// //     input  logic [7:0] red_box_y_min [0:NUM_BOXES-1],
// //     input  logic [7:0] red_box_y_max [0:NUM_BOXES-1],
// //     input  logic       red_box_valid [0:NUM_BOXES-1],

// //     // GREEN 박스
// //     input  logic [8:0] grn_box_x_min [0:NUM_BOXES-1],
// //     input  logic [8:0] grn_box_x_max [0:NUM_BOXES-1],
// //     input  logic [7:0] grn_box_y_min [0:NUM_BOXES-1],
// //     input  logic [7:0] grn_box_y_max [0:NUM_BOXES-1],
// //     input  logic       grn_box_valid [0:NUM_BOXES-1],

// //     // BLUE 박스
// //     input  logic [8:0] blu_box_x_min [0:NUM_BOXES-1],
// //     input  logic [8:0] blu_box_x_max [0:NUM_BOXES-1],
// //     input  logic [7:0] blu_box_y_min [0:NUM_BOXES-1],
// //     input  logic [7:0] blu_box_y_max [0:NUM_BOXES-1],
// //     input  logic       blu_box_valid [0:NUM_BOXES-1],

// //     output logic [3:0] o_img_red,
// //     output logic [3:0] o_img_green,
// //     output logic [3:0] o_img_blue
// // );

// //     // ── 4분할 셀 판단 ─────────────────────────────────────────────
// //     logic cell_tl, cell_tr, cell_bl, cell_br;
// //     assign cell_tl = (x_pixel <  320) && (y_pixel <  240);
// //     assign cell_tr = (x_pixel >= 320) && (y_pixel <  240);
// //     assign cell_bl = (x_pixel <  320) && (y_pixel >= 240);
// //     assign cell_br = (x_pixel >= 320) && (y_pixel >= 240);

// //     logic in_de;
// //     assign in_de = DE && (x_pixel < 640) && (y_pixel < 480);

// //     // ── 카메라 좌표 변환 ──────────────────────────────────────────
// //     logic [8:0] cam_x;
// //     logic [7:0] cam_y;
// //     assign cam_x = (x_pixel < 320) ? x_pixel[8:0] : (x_pixel - 10'd320);
// //     assign cam_y = (y_pixel < 240) ? y_pixel[7:0] : (y_pixel - 10'd240);

// //     // ── 박스 테두리 판별 함수 ─────────────────────────────────────
// //     // 현재 cam_x, cam_y가 특정 박스의 테두리 위인지 확인
// //     function automatic logic on_box_edge(
// //         input logic [8:0] cx,
// //         input logic [7:0] cy,
// //         input logic [8:0] xmin, xmax,
// //         input logic [7:0] ymin, ymax,
// //         input logic       valid
// //     );
// //         logic on_h, on_v;
// //         // 수평선 (top/bottom)
// //         on_h = valid &&
// //                (cx >= xmin) && (cx <= xmax) &&
// //                ((cy >= ymin && cy <= ymin + BOX_THICK - 1) ||
// //                 (cy <= ymax && cy >= ymax - BOX_THICK + 1));
// //         // 수직선 (left/right)
// //         on_v = valid &&
// //                (cy >= ymin) && (cy <= ymax) &&
// //                ((cx >= xmin && cx <= xmin + BOX_THICK - 1) ||
// //                 (cx <= xmax && cx >= xmax - BOX_THICK + 1));
// //         return on_h || on_v;
// //     endfunction

// //     // ── 각 색상 셀의 박스 오버레이 여부 ──────────────────────────
// //     logic on_red_box, on_grn_box, on_blu_box;

// //     always_comb begin
// //         on_red_box = 1'b0;
// //         on_grn_box = 1'b0;
// //         on_blu_box = 1'b0;
// //         for (int i = 0; i < NUM_BOXES; i++) begin
// //             if (on_box_edge(cam_x, cam_y,
// //                             red_box_x_min[i], red_box_x_max[i],
// //                             red_box_y_min[i], red_box_y_max[i],
// //                             red_box_valid[i]))
// //                 on_red_box = 1'b1;

// //             if (on_box_edge(cam_x, cam_y,
// //                             grn_box_x_min[i], grn_box_x_max[i],
// //                             grn_box_y_min[i], grn_box_y_max[i],
// //                             grn_box_valid[i]))
// //                 on_grn_box = 1'b1;

// //             if (on_box_edge(cam_x, cam_y,
// //                             blu_box_x_min[i], blu_box_x_max[i],
// //                             blu_box_y_min[i], blu_box_y_max[i],
// //                             blu_box_valid[i]))
// //                 on_blu_box = 1'b1;
// //         end
// //     end

// //     // ── 최종 출력 ─────────────────────────────────────────────────
// //     always_comb begin
// //         if (!in_de) begin
// //             o_img_red   = 4'h0;
// //             o_img_green = 4'h0;
// //             o_img_blue  = 4'h0;

// //         end else if (cell_tl) begin
// //             // 좌상: 원본 + 모든 박스 흰색 오버레이
// //             if (on_red_box || on_grn_box || on_blu_box) begin
// //                 o_img_red   = 4'hF;
// //                 o_img_green = 4'hF;
// //                 o_img_blue  = 4'hF;
// //             end else begin
// //                 o_img_red   = img_red;
// //                 o_img_green = img_green;
// //                 o_img_blue  = img_blue;
// //             end

// //         end else if (cell_tr) begin
// //             // 우상: 빨강 감지 + 빨강 박스 흰색 오버레이
// //             if (on_red_box) begin
// //                 o_img_red   = 4'hF;
// //                 o_img_green = 4'hF;
// //                 o_img_blue  = 4'hF;
// //             end else begin
// //                 o_img_red   = is_red ? 4'hF : (img_red   >> 2);
// //                 o_img_green = is_red ? 4'h0 : (img_green >> 2);
// //                 o_img_blue  = is_red ? 4'h0 : (img_blue  >> 2);
// //             end

// //         end else if (cell_bl) begin
// //             // 좌하: 초록 감지 + 초록 박스 흰색 오버레이
// //             if (on_grn_box) begin
// //                 o_img_red   = 4'hF;
// //                 o_img_green = 4'hF;
// //                 o_img_blue  = 4'hF;
// //             end else begin
// //                 o_img_red   = is_green ? 4'h0 : (img_red   >> 2);
// //                 o_img_green = is_green ? 4'hF : (img_green >> 2);
// //                 o_img_blue  = is_green ? 4'h0 : (img_blue  >> 2);
// //             end

// //         end else begin
// //             // 우하: 파랑 감지 + 파랑 박스 흰색 오버레이
// //             if (on_blu_box) begin
// //                 o_img_red   = 4'hF;
// //                 o_img_green = 4'hF;
// //                 o_img_blue  = 4'hF;
// //             end else begin
// //                 o_img_red   = is_blue ? 4'h0 : (img_red   >> 2);
// //                 o_img_green = is_blue ? 4'h0 : (img_green >> 2);
// //                 o_img_blue  = is_blue ? 4'hF : (img_blue  >> 2);
// //             end
// //         end
// //     end

// // endmodule

// // 뭐였지
// // `timescale 1ns / 1ps

// // // image_output
// // // 4분할 디버그 화면:
// // // ┌──────────────┬──────────────┐
// // // │  원본 영상    │  빨강 감지   │  (좌상: x<320, y<240)  (우상: x>=320, y<240)
// // // ├──────────────┼──────────────┤
// // // │  초록 감지    │  파랑 감지   │  (좌하: x<320, y>=240) (우하: x>=320, y>=240)
// // // └──────────────┴──────────────┘
// // // 감지된 픽셀: 해당 색으로 강조, 미감지 픽셀: 1/4 밝기로 어둡게

// // module image_output (
// //     input  logic [9:0] x_pixel,
// //     input  logic [9:0] y_pixel,
// //     input  logic       DE,

// //     // 원본 RGB (ImgMemReader에서)
// //     input  logic [3:0] img_red,
// //     input  logic [3:0] img_green,
// //     input  logic [3:0] img_blue,

// //     // HSV_Transformer 판별 결과
// //     input  logic       is_red,
// //     input  logic       is_green,
// //     input  logic       is_blue,

//     output logic [3:0] o_img_red,
//     output logic [3:0] o_img_green,
//     output logic [3:0] o_img_blue
// );

//     // ── 4분할 셀 판단 ─────────────────────────────────────────────
//     logic cell_tl, cell_tr, cell_bl, cell_br;
//     assign cell_tl = (x_pixel <  320) && (y_pixel <  240);  // 좌상: 원본
//     assign cell_tr = (x_pixel >= 320) && (y_pixel <  240);  // 우상: 빨강
//     assign cell_bl = (x_pixel <  320) && (y_pixel >= 240);  // 좌하: 초록
//     assign cell_br = (x_pixel >= 320) && (y_pixel >= 240);  // 우하: 파랑

//     logic in_de;
//     assign in_de = DE && (x_pixel < 640) && (y_pixel < 480);

//     // ── 최종 출력 ─────────────────────────────────────────────────
//     always_comb begin
//         if (!in_de) begin
//             o_img_red   = 4'h0;
//             o_img_green = 4'h0;
//             o_img_blue  = 4'h0;
//         end else if (cell_tl) begin
//             // 좌상: 원본 영상 그대로
//             o_img_red   = img_red;
//             o_img_green = img_green;
//             o_img_blue  = img_blue;
//         end else if (cell_tr) begin
//             // 우상: 빨강 감지
//             // 감지된 픽셀 → 순수 빨간색
//             // 미감지 픽셀 → 1/4 밝기 (>>2)
//             o_img_red   = is_red ? 4'hF : (img_red   >> 2);
//             o_img_green = is_red ? 4'h0 : (img_green >> 2);
//             o_img_blue  = is_red ? 4'h0 : (img_blue  >> 2);
//         end else if (cell_bl) begin
//             // 좌하: 초록 감지
//             o_img_red   = is_green ? 4'h0 : (img_red   >> 2);
//             o_img_green = is_green ? 4'hF : (img_green >> 2);
//             o_img_blue  = is_green ? 4'h0 : (img_blue  >> 2);
//         end else begin
//             // 우하: 파랑 감지
//             o_img_red   = is_blue ? 4'h0 : (img_red   >> 2);
//             o_img_green = is_blue ? 4'h0 : (img_green >> 2);
//             o_img_blue  = is_blue ? 4'hF : (img_blue  >> 2);
//         end
//     end

// endmodule
