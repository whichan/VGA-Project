`timescale 1ns / 1ps

// ColorFilter: 3x3 다수결 필터
// HSV_Transformer의 is_red/green/blue를 받아서
// 주변 9픽셀 중 THRESH개 이상이 1이면 출력 1
// → 고립된 노이즈 점 제거, 연속된 물체 픽셀만 통과
//
// 동작 도메인: rclk (VGA 읽기 도메인)
// x_pixel, y_pixel은 ImgMemReader와 동일한 신호 사용

module kernel_color_filter #(
    parameter IMG_W  = 320,
    parameter IMG_H  = 240,
    parameter THRESH = 4'd4  // 9픽셀 중 몇 개 이상이면 통과 (4=과반수)
) (
    input logic rclk,
    input logic reset,

    // 현재 픽셀 좌표 (4분할 기준 cam_x/cam_y가 아닌 x_pixel/y_pixel 그대로)
    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    input logic       DE,

    // HSV 판별 입력
    input logic is_red_in,
    input logic is_green_in,
    input logic is_blue_in,

    // 필터링된 출력
    output logic is_red_out,
    output logic is_green_out,
    output logic is_blue_out
);

    // ── 4분할 셀 내 카메라 좌표 계산 ─────────────────────────────
    logic [9:0] cam_x, cam_y;
    always_comb begin
        cam_x = (x_pixel < 320) ? x_pixel : x_pixel - 10'd320;
        cam_y = (y_pixel < 240) ? y_pixel : y_pixel - 10'd240;
    end

    logic in_de;
    assign in_de = DE && (x_pixel < 640) && (y_pixel < 480);

    // ── 라인버퍼 (1bit × IMG_W × 2줄) ───────────────────────────
    // R, G, B 각각 독립 라인버퍼
    logic r_lb0[0:IMG_W-1], r_lb1[0:IMG_W-1];
    logic g_lb0[0:IMG_W-1], g_lb1[0:IMG_W-1];
    logic b_lb0[0:IMG_W-1], b_lb1[0:IMG_W-1];

    logic [1:0] lb_sel;  // 현재 쓰는 줄 (0,1 순환)

    always_ff @(posedge rclk) begin
        if (reset) begin
            lb_sel <= 0;
        end else if (in_de) begin
            // 현재 줄에 쓰기
            case (lb_sel)
                1'b0: begin
                    r_lb0[cam_x] <= is_red_in;
                    g_lb0[cam_x] <= is_green_in;
                    b_lb0[cam_x] <= is_blue_in;
                end
                1'b1: begin
                    r_lb1[cam_x] <= is_red_in;
                    g_lb1[cam_x] <= is_green_in;
                    b_lb1[cam_x] <= is_blue_in;
                end
            endcase
            // 행 끝에서 줄 전환
            if (cam_x == IMG_W - 1) lb_sel <= ~lb_sel;
        end
    end

    // ── 3x3 윈도우 읽기 ──────────────────────────────────────────
    // row2 = 현재 행 (라인버퍼에 방금 쓴 줄)
    // row1 = 1행 전
    // row0 = 2행 전 (없으므로 현재 줄로 대체 → 경계처리)
    // 단순화: lb_sel이 가리키는 줄 = 이전 행, 반대 = 2행 전

    logic [9:0] cx_m1, cx_p1;
    assign cx_m1 = (cam_x == 0) ? 10'd0 : cam_x - 1;
    assign cx_p1 = (cam_x == IMG_W - 1) ? IMG_W - 1 : cam_x + 1;

    // 현재 행(row2)은 is_*_in 직접 사용
    // row1 = lb_sel 줄 (방금 완성된 이전 행)
    // row0 = ~lb_sel 줄 (2행 전)
    logic r_row1_l, r_row1_c, r_row1_r;
    logic r_row0_l, r_row0_c, r_row0_r;
    logic g_row1_l, g_row1_c, g_row1_r;
    logic g_row0_l, g_row0_c, g_row0_r;
    logic b_row1_l, b_row1_c, b_row1_r;
    logic b_row0_l, b_row0_c, b_row0_r;

    always_comb begin
        case (lb_sel)
            1'b0: begin
                // lb0 = 이전 행, lb1 = 2행 전
                r_row1_l = r_lb0[cx_m1];
                r_row1_c = r_lb0[cam_x];
                r_row1_r = r_lb0[cx_p1];
                r_row0_l = r_lb1[cx_m1];
                r_row0_c = r_lb1[cam_x];
                r_row0_r = r_lb1[cx_p1];
                g_row1_l = g_lb0[cx_m1];
                g_row1_c = g_lb0[cam_x];
                g_row1_r = g_lb0[cx_p1];
                g_row0_l = g_lb1[cx_m1];
                g_row0_c = g_lb1[cam_x];
                g_row0_r = g_lb1[cx_p1];
                b_row1_l = b_lb0[cx_m1];
                b_row1_c = b_lb0[cam_x];
                b_row1_r = b_lb0[cx_p1];
                b_row0_l = b_lb1[cx_m1];
                b_row0_c = b_lb1[cam_x];
                b_row0_r = b_lb1[cx_p1];
            end
            default: begin
                // lb1 = 이전 행, lb0 = 2행 전
                r_row1_l = r_lb1[cx_m1];
                r_row1_c = r_lb1[cam_x];
                r_row1_r = r_lb1[cx_p1];
                r_row0_l = r_lb0[cx_m1];
                r_row0_c = r_lb0[cam_x];
                r_row0_r = r_lb0[cx_p1];
                g_row1_l = g_lb1[cx_m1];
                g_row1_c = g_lb1[cam_x];
                g_row1_r = g_lb1[cx_p1];
                g_row0_l = g_lb0[cx_m1];
                g_row0_c = g_lb0[cam_x];
                g_row0_r = g_lb0[cx_p1];
                b_row1_l = b_lb1[cx_m1];
                b_row1_c = b_lb1[cam_x];
                b_row1_r = b_lb1[cx_p1];
                b_row0_l = b_lb0[cx_m1];
                b_row0_c = b_lb0[cam_x];
                b_row0_r = b_lb0[cx_p1];
            end
        endcase
    end

    // ── 3x3 합산 (현재 행 포함 총 9픽셀) ────────────────────────
    logic [3:0] r_cnt, g_cnt, b_cnt;

    assign r_cnt = r_row0_l + r_row0_c + r_row0_r
                 + r_row1_l + r_row1_c + r_row1_r
                 + {{2{1'b0}}, is_red_in} + 1'b0  // 현재 픽셀 (중앙, 좌, 우 따로 없음)
        // 현재 행 3픽셀: 직전 cam_x-1, cam_x, cam_x+1 을 shift reg로 유지
        // 간략화: 현재 행은 is_red_in 1픽셀만 카운트
        // → 총 7픽셀 (row0 3 + row1 3 + 현재 1)
        + 4'd0;  // 패딩

    // 현재 행 3픽셀을 위한 shift register
    logic r_prev, r_prev2;
    logic g_prev, g_prev2;
    logic b_prev, b_prev2;

    always_ff @(posedge rclk) begin
        if (reset) begin
            r_prev  <= 0;
            r_prev2 <= 0;
            g_prev  <= 0;
            g_prev2 <= 0;
            b_prev  <= 0;
            b_prev2 <= 0;
        end else if (in_de) begin
            r_prev2 <= r_prev;
            r_prev  <= is_red_in;
            g_prev2 <= g_prev;
            g_prev  <= is_green_in;
            b_prev2 <= b_prev;
            b_prev  <= is_blue_in;
        end
    end

    // 최종 합산: row0(3) + row1(3) + 현재행(3: prev2,prev,cur)
    logic [3:0] r_sum, g_sum, b_sum;

    assign r_sum = (r_row0_l + r_row0_c + r_row0_r) + (r_row1_l + r_row1_c + r_row1_r) + (r_prev2 + r_prev + is_red_in);

    assign g_sum = (g_row0_l + g_row0_c + g_row0_r)
                 + (g_row1_l + g_row1_c + g_row1_r)
                 + (g_prev2  + g_prev   + is_green_in);

    assign b_sum = (b_row0_l + b_row0_c + b_row0_r)
                 + (b_row1_l + b_row1_c + b_row1_r)
                 + (b_prev2  + b_prev   + is_blue_in);

    // ── 출력: THRESH 이상이면 통과 ───────────────────────────────
    // 경계(cam_y<2, cam_x<1)는 필터 적용 안 함 → 0 출력
    logic valid_pos;
    assign valid_pos = in_de && (cam_y >= 2) && (cam_x >= 1) && (cam_x < IMG_W - 1);

    assign is_red_out = valid_pos && (r_sum >= THRESH);
    assign is_green_out = valid_pos && (g_sum >= THRESH);
    assign is_blue_out = valid_pos && (b_sum >= THRESH);

endmodule
