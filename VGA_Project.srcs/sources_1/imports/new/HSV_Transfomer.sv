`timescale 1ns / 1ps

module HSV_Transformer #(
    parameter S_MIN_RED   = 4'd6,   // 채도 최소 임계값
    parameter V_MIN_RED   = 4'd4,   // 명도 최소 임계값
    parameter V_MAX_RED   = 4'd14,  // 명도 상한 (15=순백, 14면 반사광 차단)
    parameter S_MIN_GREEN = 4'd6,
    parameter V_MIN_GREEN = 4'd4,
    parameter V_MAX_GREEN = 4'd14,
    parameter S_MIN_BLUE  = 4'd6,
    parameter V_MIN_BLUE  = 4'd4,
    parameter V_MAX_BLUE  = 4'd13

) (
    input logic [3:0] hsv_red,
    input logic [3:0] hsv_green,
    input logic [3:0] hsv_blue,

    // HSV 근사 출력
    output logic [1:0] hue,  // 0=R, 1=G, 2=B, 3=기타(무채색)
    output logic [3:0] sat,  // 채도 근사 (cmax - cmin)
    output logic [3:0] val,  // 명도 (cmax)

    // 색상 판별 플래그
    output logic is_red,
    output logic is_green,
    output logic is_blue
);

    logic [3:0] cmax, cmin;

    always_comb begin
        // ── cmax, cmin 계산 ───────────────────────────────────────
        cmax = hsv_red;
        if (hsv_green > cmax) cmax = hsv_green;
        if (hsv_blue > cmax) cmax = hsv_blue;

        cmin = hsv_red;
        if (hsv_green < cmin) cmin = hsv_green;
        if (hsv_blue < cmin) cmin = hsv_blue;

        // ── V, S 계산 ─────────────────────────────────────────────
        val = cmax;
        sat = cmax - cmin;

        // ── H 근사 (어느 채널이 cmax인지) ────────────────────────
        // 동점일 경우 우선순위: R > G > B

        if (hsv_red == cmax) hue = 2'd0;  // 빨강 영역
        else if (hsv_green == cmax) hue = 2'd1;  // 초록 영역
        else hue = 2'd2;  // 파랑 영역

        // ── 색상 판별 (채도+명도 조건 + 색상 우세 조건) ─────────
        // 조건: val >= V_MIN (너무 어둡지 않음)
        //       sat >= S_MIN (충분히 채도 있음)
        //       해당 채널이 다른 채널의 1.5배 이상
        //       (hsv_red >= hsv_green + hsv_green>>1 은 hsv_red >= hsv_green*1.5 근사)

        is_red = (val >= V_MIN_RED) && (val <= V_MAX_RED) && (sat >= S_MIN_RED) &&
                 (hsv_red == cmax) &&
                 (hsv_red >= hsv_green + (hsv_green >> 2)) &&
                 (hsv_red >= hsv_blue + (hsv_blue >> 2));

        is_green = (val >= V_MIN_GREEN) && (val <= V_MAX_GREEN) &&
                    (sat >= S_MIN_GREEN) &&
                   (hsv_green == cmax) &&
                   (hsv_green >= hsv_red + (hsv_red >> 2)) &&
                   (hsv_green >= hsv_blue + (hsv_blue >> 2));

        //기존
        // is_blue = (val >= V_MIN_BLUE) &&  (val <= V_MAX_BLUE) && (sat >= S_MIN_BLUE) &&
        //           (hsv_blue == cmax) &&
        //           (hsv_blue >= hsv_red + (hsv_red >> 2)) &&
        //           (hsv_blue >= hsv_green + (hsv_green >> 2));
        //식별 up
        is_blue = (val >= V_MIN_BLUE) &&  (val <= V_MAX_BLUE) && (sat >= S_MIN_BLUE) &&
                  (hsv_blue == cmax) &&
                  (hsv_blue >= hsv_red) &&
                  (hsv_blue >= hsv_green);
    end

endmodule
