
// `timescale 1ns / 1ps

// // box_maker v3: 픽셀 밀도 기반 박스 유지
// //
// // 박스 상태 머신 (박스당):
// //   EMPTY   → [이번 프레임 pix_cnt >= CREATE_MIN] → ACTIVE
// //   ACTIVE  → [이번 프레임 pix_cnt >= HOLD_MIN]   → ACTIVE  (좌표 업데이트)
// //   ACTIVE  → [이번 프레임 pix_cnt <  HOLD_MIN]   → hold_cnt--
// //           → [hold_cnt == 0]                      → EMPTY   (좌표 유지하다 소멸)
// //
// // CREATE_MIN > HOLD_MIN: 생성은 엄격, 유지는 느슨
// // HOLD_MAX: 감지 안 될 때 몇 프레임까지 유지할지

// module box_maker #(
//     parameter IMG_W      = 320,
//     parameter IMG_H      = 240,
//     parameter NUM_BOXES  = 2,
//     parameter MAX_BOX_W  = 160,
//     parameter MAX_BOX_H  = 120,
//     parameter CREATE_MIN = 300,   // 박스 생성 임계값 (엄격)
//     parameter HOLD_MIN   = 80,    // 박스 유지 임계값 (느슨)
//     parameter HOLD_MAX   = 5,     // 감지 끊겼을 때 유지 프레임 수
//     parameter MAX_RUNS   = 4
// ) (
//     input  logic       rclk,
//     input  logic       reset,
//     input  logic       vsync,
//     input  logic       DE,
//     input  logic [9:0] x_pixel,
//     input  logic [9:0] y_pixel,
//     input  logic       is_target,

//     output logic [8:0] box_x_min [0:NUM_BOXES-1],
//     output logic [8:0] box_x_max [0:NUM_BOXES-1],
//     output logic [7:0] box_y_min [0:NUM_BOXES-1],
//     output logic [7:0] box_y_max [0:NUM_BOXES-1],
//     output logic       box_valid [0:NUM_BOXES-1]
// );

//     // ── 좌표 / 활성 영역 ──────────────────────────────────────────
//     logic [8:0] cam_x;
//     logic [7:0] cam_y;
//     assign cam_x = x_pixel[8:0];
//     assign cam_y = y_pixel[7:0];

//     logic in_active;
//     assign in_active = DE && (x_pixel < IMG_W) && (y_pixel < IMG_H);

//     // ── 1클럭 지연 ───────────────────────────────────────────────
//     logic       DE_d, in_active_d, is_target_d;
//     logic [9:0] x_d, y_d;

//     always_ff @(posedge rclk) begin
//         DE_d        <= DE;
//         x_d         <= x_pixel;
//         y_d         <= y_pixel;
//         is_target_d <= is_target;
//         in_active_d <= in_active;
//     end

//     // ── 행 끝 / 프레임 끝 ────────────────────────────────────────
//     logic row_end, frame_end;
//     assign row_end   = DE_d && (x_d == IMG_W - 1) && (y_d <  IMG_H - 1);
//     assign frame_end = DE_d && (x_d == IMG_W - 1) && (y_d == IMG_H - 1);

//     // ── Run 타입 ──────────────────────────────────────────────────
//     typedef struct packed {
//         logic [8:0] x_start;
//         logic [8:0] x_end;
//         logic [1:0] box_id;
//         logic       valid;
//     } run_t;

//     run_t cur_runs  [0:MAX_RUNS-1];
//     run_t prev_runs [0:MAX_RUNS-1];
//     logic [$clog2(MAX_RUNS+1)-1:0] cur_run_cnt;

//     logic       in_run;
//     logic [8:0] run_start_x;

//     // ── 박스 추적 (프레임 내 임시 계산용) ────────────────────────
//     logic [8:0]  bx_min  [0:NUM_BOXES-1];  // 이번 프레임 계산 중
//     logic [8:0]  bx_max  [0:NUM_BOXES-1];
//     logic [7:0]  by_min  [0:NUM_BOXES-1];
//     logic [7:0]  by_max  [0:NUM_BOXES-1];
//     logic [15:0] pix_cnt [0:NUM_BOXES-1];  // 이번 프레임 픽셀 수
//     logic        bactive [0:NUM_BOXES-1];  // 이번 프레임에 run이 걸렸나
//     logic [1:0]  next_box_id;

//     // ── 박스 유지 상태 ────────────────────────────────────────────
//     // box_valid/x_min 등은 출력 레지스터 = 실제 표시되는 박스
//     // hold_cnt: 0이면 EMPTY, >0이면 ACTIVE
//     logic [$clog2(HOLD_MAX+1):0] hold_cnt [0:NUM_BOXES-1];

//     // ── vsync 에지 ────────────────────────────────────────────────
//     logic vsync_d, frame_start;
//     always_ff @(posedge rclk) vsync_d <= vsync;
//     assign frame_start = vsync && !vsync_d;

//     // ── run 종료 감지 ─────────────────────────────────────────────
//     logic run_fell, run_rowend;
//     assign run_fell   = in_active_d && is_target_d && in_active && !is_target;
//     assign run_rowend = row_end && in_run;

//     logic [8:0] run_end_x;
//     assign run_end_x = run_rowend ? (IMG_W[8:0] - 1) : (x_d[8:0] - 1);

//     integer i, k;

//     always_ff @(posedge rclk) begin
//         if (reset) begin
//             // 완전 리셋
//             for (i = 0; i < MAX_RUNS; i++) begin
//                 cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//                 prev_runs[i] <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//             end
//             for (i = 0; i < NUM_BOXES; i++) begin
//                 bx_min[i]    <= 9'd319; bx_max[i]    <= 9'd0;
//                 by_min[i]    <= 8'd239; by_max[i]    <= 8'd0;
//                 pix_cnt[i]   <= '0;
//                 bactive[i]   <= 1'b0;
//                 hold_cnt[i]  <= '0;
//                 box_valid[i] <= 1'b0;
//                 box_x_min[i] <= '0; box_x_max[i] <= '0;
//                 box_y_min[i] <= '0; box_y_max[i] <= '0;
//             end
//             cur_run_cnt <= '0;
//             in_run      <= 1'b0;
//             run_start_x <= '0;
//             next_box_id <= '0;

//         end else begin

//             // ── frame_start: 프레임 내 임시 계산용만 리셋 ────────
//             // 출력 레지스터(box_valid, box_x_min 등)는 건드리지 않음!
//             if (frame_start) begin
//                 for (i = 0; i < MAX_RUNS; i++) begin
//                     cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//                     prev_runs[i] <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//                 end
//                 for (i = 0; i < NUM_BOXES; i++) begin
//                     bx_min[i]  <= 9'd319; bx_max[i]  <= 9'd0;
//                     by_min[i]  <= 8'd239; by_max[i]  <= 8'd0;
//                     pix_cnt[i] <= '0;
//                     bactive[i] <= 1'b0;
//                 end
//                 cur_run_cnt <= '0;
//                 in_run      <= 1'b0;
//                 run_start_x <= '0;
//                 next_box_id <= '0;
//             end

//             // ── 1. run 시작/종료 추적 ────────────────────────────
//             if (in_active) begin
//                 if (is_target && !in_run) begin
//                     in_run      <= 1'b1;
//                     run_start_x <= cam_x;
//                 end
//             end
//             if (row_end || frame_end || !in_active) begin
//                 if (in_active || in_active_d) in_run <= 1'b0;
//             end
//             if (run_fell) in_run <= 1'b0;

//             // ── 2. run 완성 → 박스 매칭 ──────────────────────────
//             if (run_fell || run_rowend) begin : run_process
//                 logic [8:0] rx_s, rx_e;
//                 logic        matched;
//                 logic [1:0]  mid;

//                 rx_s    = run_start_x;
//                 rx_e    = run_end_x;
//                 matched = 1'b0;
//                 mid     = 2'd0;

//                 // prev_runs와 x범위 겹침 검사
//                 for (k = 0; k < MAX_RUNS; k++) begin
//                     if (prev_runs[k].valid && !matched) begin
//                         if (!(rx_e < prev_runs[k].x_start) &&
//                             !(rx_s > prev_runs[k].x_end)) begin
//                             matched = 1'b1;
//                             mid     = prev_runs[k].box_id;
//                         end
//                     end
//                 end

//                 // 매칭 실패 시: ACTIVE 박스(hold_cnt>0)의 x범위와 겹치면 연결
//                 if (!matched) begin
//                     for (k = 0; k < NUM_BOXES; k++) begin
//                         if (hold_cnt[k] > 0 && !matched) begin
//                             if (!(rx_e < box_x_min[k]) &&
//                                 !(rx_s > box_x_max[k])) begin
//                                 matched = 1'b1;
//                                 mid     = k[1:0];
//                             end
//                         end
//                     end
//                 end

//                 if (matched) begin
//                     if (cur_run_cnt < MAX_RUNS) begin
//                         cur_runs[cur_run_cnt] <= '{x_start:rx_s, x_end:rx_e,
//                                                    box_id:mid, valid:1'b1};
//                         cur_run_cnt <= cur_run_cnt + 1;
//                     end
//                     if (rx_s < bx_min[mid]) bx_min[mid] <= rx_s;
//                     if (rx_e > bx_max[mid]) bx_max[mid] <= rx_e;
//                     if (run_rowend) begin
//                         if (y_d[7:0] < by_min[mid]) by_min[mid] <= y_d[7:0];
//                         if (y_d[7:0] > by_max[mid]) by_max[mid] <= y_d[7:0];
//                     end else begin
//                         if (cam_y < by_min[mid]) by_min[mid] <= cam_y;
//                         if (cam_y > by_max[mid]) by_max[mid] <= cam_y;
//                     end
//                     pix_cnt[mid] <= pix_cnt[mid] + (rx_e - rx_s + 1);
//                     bactive[mid] <= 1'b1;
//                     // 크기 초과 검사는 frame_end에서만 수행
//                     // (run 단위 검사 시 by_max 타이밍 오판으로 오작동)

//                 end else if (next_box_id < NUM_BOXES) begin
//                     // 슬롯이 비어있을 때만 새 박스 할당
//                     if (hold_cnt[next_box_id] == 0) begin
//                         if (cur_run_cnt < MAX_RUNS) begin
//                             cur_runs[cur_run_cnt] <= '{x_start:rx_s, x_end:rx_e,
//                                                        box_id:next_box_id, valid:1'b1};
//                             cur_run_cnt <= cur_run_cnt + 1;
//                         end
//                         bx_min[next_box_id]  <= rx_s;
//                         bx_max[next_box_id]  <= rx_e;
//                         by_min[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
//                         by_max[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
//                         pix_cnt[next_box_id] <= rx_e - rx_s + 1;
//                         bactive[next_box_id] <= 1'b1;
//                         next_box_id          <= next_box_id + 1;
//                     end else begin
//                         // 슬롯이 사용 중이면 다음 슬롯 시도
//                         next_box_id <= next_box_id + 1;
//                     end
//                 end
//             end

//             // ── 3. 행 끝: prev_runs 교체 ─────────────────────────
//             if (row_end) begin
//                 for (i = 0; i < MAX_RUNS; i++) begin
//                     prev_runs[i] <= cur_runs[i];
//                     cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//                 end
//                 cur_run_cnt <= '0;
//             end

//             // ── 4. 프레임 끝: 밀도 기반 박스 유지/소멸/생성 ──────
//             if (frame_end) begin
//                 for (i = 0; i < NUM_BOXES; i++) begin

//                     // 크기 초과 → 이번 프레임 무효 (frame_end에서 한 번만 검사)
//                     if ((bx_max[i] - bx_min[i]) > MAX_BOX_W ||
//                         (by_max[i] - by_min[i]) > MAX_BOX_H) begin
//                         bactive[i] <= 1'b0;
//                     end

//                     if (hold_cnt[i] == 0) begin
//                         // ── EMPTY 상태: 생성 조건 검사 ───────────
//                         if (pix_cnt[i] >= CREATE_MIN && bactive[i]) begin
//                             box_x_min[i] <= bx_min[i];
//                             box_x_max[i] <= bx_max[i];
//                             box_y_min[i] <= by_min[i];
//                             box_y_max[i] <= by_max[i];
//                             box_valid[i] <= 1'b1;
//                             hold_cnt[i]  <= HOLD_MAX;
//                         end

//                     end else begin
//                         // ── ACTIVE 상태: 유지 조건 검사 ──────────
//                         if (pix_cnt[i] >= HOLD_MIN && bactive[i]) begin
//                             box_x_min[i] <= bx_min[i];
//                             box_x_max[i] <= bx_max[i];
//                             box_y_min[i] <= by_min[i];
//                             box_y_max[i] <= by_max[i];
//                             box_valid[i] <= 1'b1;
//                             hold_cnt[i]  <= HOLD_MAX;
//                         end else begin
//                             // 픽셀 부족 → 좌표 유지, 카운터 감소
//                             hold_cnt[i] <= hold_cnt[i] - 1;
//                             if (hold_cnt[i] == 1) begin
//                                 // 다음 클럭에 0이 됨 → 박스 소멸
//                                 box_valid[i] <= 1'b0;
//                             end
//                             // box_x_min 등은 건드리지 않음 (좌표 유지)
//                         end
//                     end

//                 end

//                 // 다음 프레임을 위한 run 리셋
//                 next_box_id <= '0;
//                 for (i = 0; i < MAX_RUNS; i++) begin
//                     cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//                     prev_runs[i] <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
//                 end
//             end

//         end
//     end

// endmodule

// box가 중앙을 지나갈때 할당 초기화됨.
// box를 생성 후 유지하는 로직
`timescale 1ns / 1ps

// box_maker v3: 픽셀 밀도 기반 박스 유지
//
// 박스 상태 머신 (박스당):
//   EMPTY   → [이번 프레임 pix_cnt >= CREATE_MIN] → ACTIVE
//   ACTIVE  → [이번 프레임 pix_cnt >= HOLD_MIN]   → ACTIVE  (좌표 업데이트)
//   ACTIVE  → [이번 프레임 pix_cnt <  HOLD_MIN]   → hold_cnt--
//           → [hold_cnt == 0]                      → EMPTY   (좌표 유지하다 소멸)
//
// CREATE_MIN > HOLD_MIN: 생성은 엄격, 유지는 느슨
// HOLD_MAX: 감지 안 될 때 몇 프레임까지 유지할지

module box_maker #(
    parameter IMG_W      = 320,
    parameter IMG_H      = 240,
    parameter NUM_BOXES  = 2,
    parameter MAX_BOX_W  = 160,
    parameter MAX_BOX_H  = 120,
    parameter CREATE_MIN = 300,   // 박스 생성 임계값 (엄격)
    parameter HOLD_MIN   = 80,    // 박스 유지 임계값 (느슨)
    parameter HOLD_MAX   = 5,     // 감지 끊겼을 때 유지 프레임 수
    parameter MAX_RUNS   = 4
) (
    input  logic       rclk,
    input  logic       reset,
    input  logic       vsync,
    input  logic       DE,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic       is_target,

    output logic [8:0] box_x_min [0:NUM_BOXES-1],
    output logic [8:0] box_x_max [0:NUM_BOXES-1],
    output logic [7:0] box_y_min [0:NUM_BOXES-1],
    output logic [7:0] box_y_max [0:NUM_BOXES-1],
    output logic       box_valid [0:NUM_BOXES-1]
);

    // ── 좌표 / 활성 영역 ──────────────────────────────────────────
    logic [8:0] cam_x;
    logic [7:0] cam_y;
    assign cam_x = x_pixel[8:0];
    assign cam_y = y_pixel[7:0];

    logic in_active;
    assign in_active = DE && (x_pixel < IMG_W) && (y_pixel < IMG_H);

    // ── 1클럭 지연 ───────────────────────────────────────────────
    logic       DE_d, in_active_d, is_target_d;
    logic [9:0] x_d, y_d;

    always_ff @(posedge rclk) begin
        DE_d        <= DE;
        x_d         <= x_pixel;
        y_d         <= y_pixel;
        is_target_d <= is_target;
        in_active_d <= in_active;
    end

    // ── 행 끝 / 프레임 끝 ────────────────────────────────────────
    logic row_end, frame_end;
    assign row_end   = DE_d && (x_d == IMG_W - 1) && (y_d <  IMG_H - 1);
    assign frame_end = DE_d && (x_d == IMG_W - 1) && (y_d == IMG_H - 1);

    // ── Run 타입 ──────────────────────────────────────────────────
    typedef struct packed {
        logic [8:0] x_start;
        logic [8:0] x_end;
        logic [1:0] box_id;
        logic       valid;
    } run_t;

    run_t cur_runs  [0:MAX_RUNS-1];
    run_t prev_runs [0:MAX_RUNS-1];
    logic [$clog2(MAX_RUNS+1)-1:0] cur_run_cnt;

    logic       in_run;
    logic [8:0] run_start_x;

    // ── 박스 추적 (프레임 내 임시 계산용) ────────────────────────
    logic [8:0]  bx_min  [0:NUM_BOXES-1];  // 이번 프레임 계산 중
    logic [8:0]  bx_max  [0:NUM_BOXES-1];
    logic [7:0]  by_min  [0:NUM_BOXES-1];
    logic [7:0]  by_max  [0:NUM_BOXES-1];
    logic [15:0] pix_cnt [0:NUM_BOXES-1];  // 이번 프레임 픽셀 수
    logic        bactive [0:NUM_BOXES-1];  // 이번 프레임에 run이 걸렸나
    logic [1:0]  next_box_id;

    // ── 박스 유지 상태 ────────────────────────────────────────────
    // box_valid/x_min 등은 출력 레지스터 = 실제 표시되는 박스
    // hold_cnt: 0이면 EMPTY, >0이면 ACTIVE
    logic [$clog2(HOLD_MAX+1):0] hold_cnt [0:NUM_BOXES-1];

    // ── vsync 에지 ────────────────────────────────────────────────
    logic vsync_d, frame_start;
    always_ff @(posedge rclk) vsync_d <= vsync;
    assign frame_start = vsync && !vsync_d;

    // ── run 종료 감지 ─────────────────────────────────────────────
    logic run_fell, run_rowend;
    assign run_fell   = in_active_d && is_target_d && in_active && !is_target;
    assign run_rowend = row_end && in_run;

    logic [8:0] run_end_x;
    assign run_end_x = run_rowend ? (IMG_W[8:0] - 1) : (x_d[8:0] - 1);

    integer i, k;

    always_ff @(posedge rclk) begin
        if (reset) begin
            // 완전 리셋
            for (i = 0; i < MAX_RUNS; i++) begin
                cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
                prev_runs[i] <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
            end
            for (i = 0; i < NUM_BOXES; i++) begin
                bx_min[i]    <= 9'd319; bx_max[i]    <= 9'd0;
                by_min[i]    <= 8'd239; by_max[i]    <= 8'd0;
                pix_cnt[i]   <= '0;
                bactive[i]   <= 1'b0;
                hold_cnt[i]  <= '0;
                box_valid[i] <= 1'b0;
                box_x_min[i] <= '0; box_x_max[i] <= '0;
                box_y_min[i] <= '0; box_y_max[i] <= '0;
            end
            cur_run_cnt <= '0;
            in_run      <= 1'b0;
            run_start_x <= '0;
            next_box_id <= '0;

        end else begin

            // ── frame_start: 프레임 내 임시 계산용만 리셋 ────────
            // 출력 레지스터(box_valid, box_x_min 등)는 건드리지 않음!
            if (frame_start) begin
                for (i = 0; i < MAX_RUNS; i++) begin
                    cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
                    prev_runs[i] <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
                end
                for (i = 0; i < NUM_BOXES; i++) begin
                    bx_min[i]  <= 9'd319; bx_max[i]  <= 9'd0;
                    by_min[i]  <= 8'd239; by_max[i]  <= 8'd0;
                    pix_cnt[i] <= '0;
                    bactive[i] <= 1'b0;
                end
                cur_run_cnt <= '0;
                in_run      <= 1'b0;
                run_start_x <= '0;
                next_box_id <= '0;
            end

            // ── 1. run 시작/종료 추적 ────────────────────────────
            if (in_active) begin
                if (is_target && !in_run) begin
                    in_run      <= 1'b1;
                    run_start_x <= cam_x;
                end
            end
            if (row_end || frame_end || !in_active) begin
                if (in_active || in_active_d) in_run <= 1'b0;
            end
            if (run_fell) in_run <= 1'b0;

            // ── 2. run 완성 → 박스 매칭 ──────────────────────────
            if (run_fell || run_rowend) begin : run_process
                logic [8:0] rx_s, rx_e;
                logic        matched;
                logic [1:0]  mid;

                rx_s    = run_start_x;
                rx_e    = run_end_x;
                matched = 1'b0;
                mid     = 2'd0;

                // prev_runs와 x범위 겹침 검사
                for (k = 0; k < MAX_RUNS; k++) begin
                    if (prev_runs[k].valid && !matched) begin
                        if (!(rx_e < prev_runs[k].x_start) &&
                            !(rx_s > prev_runs[k].x_end)) begin
                            matched = 1'b1;
                            mid     = prev_runs[k].box_id;
                        end
                    end
                end

                // 매칭 실패 시: ACTIVE 박스(hold_cnt>0)의 x범위와 겹치면 연결
                if (!matched) begin
                    for (k = 0; k < NUM_BOXES; k++) begin
                        if (hold_cnt[k] > 0 && !matched) begin
                            if (!(rx_e < box_x_min[k]) &&
                                !(rx_s > box_x_max[k])) begin
                                matched = 1'b1;
                                mid     = k[1:0];
                            end
                        end
                    end
                end

                if (matched) begin
                    if (cur_run_cnt < MAX_RUNS) begin
                        cur_runs[cur_run_cnt] <= '{x_start:rx_s, x_end:rx_e,
                                                   box_id:mid, valid:1'b1};
                        cur_run_cnt <= cur_run_cnt + 1;
                    end
                    if (rx_s < bx_min[mid]) bx_min[mid] <= rx_s;
                    if (rx_e > bx_max[mid]) bx_max[mid] <= rx_e;
                    if (run_rowend) begin
                        if (y_d[7:0] < by_min[mid]) by_min[mid] <= y_d[7:0];
                        if (y_d[7:0] > by_max[mid]) by_max[mid] <= y_d[7:0];
                    end else begin
                        if (cam_y < by_min[mid]) by_min[mid] <= cam_y;
                        if (cam_y > by_max[mid]) by_max[mid] <= cam_y;
                    end
                    pix_cnt[mid] <= pix_cnt[mid] + (rx_e - rx_s + 1);
                    bactive[mid] <= 1'b1;

                    // 크기 초과 → 이번 프레임 계산 무효화
                    if ((bx_max[mid] - bx_min[mid]) > MAX_BOX_W ||
                        (by_max[mid] - by_min[mid]) > MAX_BOX_H) begin
                        bactive[mid] <= 1'b0;
                        bx_min[mid] <= 9'd319; bx_max[mid] <= 9'd0;
                        by_min[mid] <= 8'd239; by_max[mid] <= 8'd0;
                        pix_cnt[mid] <= '0;
                    end

                end else if (next_box_id < NUM_BOXES) begin
                    // 슬롯이 비어있을 때만 새 박스 할당
                    if (hold_cnt[next_box_id] == 0) begin
                        if (cur_run_cnt < MAX_RUNS) begin
                            cur_runs[cur_run_cnt] <= '{x_start:rx_s, x_end:rx_e,
                                                       box_id:next_box_id, valid:1'b1};
                            cur_run_cnt <= cur_run_cnt + 1;
                        end
                        bx_min[next_box_id]  <= rx_s;
                        bx_max[next_box_id]  <= rx_e;
                        by_min[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
                        by_max[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
                        pix_cnt[next_box_id] <= rx_e - rx_s + 1;
                        bactive[next_box_id] <= 1'b1;
                        next_box_id          <= next_box_id + 1;
                    end else begin
                        // 슬롯이 사용 중이면 다음 슬롯 시도
                        next_box_id <= next_box_id + 1;
                    end
                end
            end

            // ── 3. 행 끝: prev_runs 교체 ─────────────────────────
            if (row_end) begin
                for (i = 0; i < MAX_RUNS; i++) begin
                    prev_runs[i] <= cur_runs[i];
                    cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
                end
                cur_run_cnt <= '0;
            end

            // ── 4. 프레임 끝: 밀도 기반 박스 유지/소멸/생성 ──────
            if (frame_end) begin
                for (i = 0; i < NUM_BOXES; i++) begin

                    if (hold_cnt[i] == 0) begin
                        // ── EMPTY 상태: 생성 조건 검사 ───────────
                        if (pix_cnt[i] >= CREATE_MIN && bactive[i]) begin
                            // 박스 생성!
                            box_x_min[i] <= bx_min[i];
                            box_x_max[i] <= bx_max[i];
                            box_y_min[i] <= by_min[i];
                            box_y_max[i] <= by_max[i];
                            box_valid[i] <= 1'b1;
                            hold_cnt[i]  <= HOLD_MAX;
                        end
                        // 생성 조건 미달 → 계속 EMPTY, 출력 유지 안 함

                    end else begin
                        // ── ACTIVE 상태: 유지 조건 검사 ──────────
                        if (pix_cnt[i] >= HOLD_MIN && bactive[i]) begin
                            // 충분한 픽셀 감지 → 좌표 업데이트 + hold 리셋
                            box_x_min[i] <= bx_min[i];
                            box_x_max[i] <= bx_max[i];
                            box_y_min[i] <= by_min[i];
                            box_y_max[i] <= by_max[i];
                            box_valid[i] <= 1'b1;
                            hold_cnt[i]  <= HOLD_MAX;  // 카운터 리셋
                        end else begin
                            // 픽셀 부족 → 좌표 유지, 카운터 감소
                            hold_cnt[i] <= hold_cnt[i] - 1;
                            if (hold_cnt[i] == 1) begin
                                // 다음 클럭에 0이 됨 → 박스 소멸
                                box_valid[i] <= 1'b0;
                            end
                            // box_x_min 등은 건드리지 않음 (좌표 유지)
                        end
                    end

                end

                // 다음 프레임을 위한 run 리셋
                next_box_id <= '0;
                for (i = 0; i < MAX_RUNS; i++) begin
                    cur_runs[i]  <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
                    prev_runs[i] <= '{x_start:'0, x_end:'0, box_id:'0, valid:1'b0};
                end
            end

        end
    end

endmodule

// //box를 지속적으로 생성
    // `timescale 1ns / 1ps

    // // box_maker: 다중 물체 bounding box 생성 (CCL 단순화)
    // // 수정 사항:
    // //   - row_end/frame_end: DE_d (이전 클럭 DE) 사용
    // //   - in_active: x<IMG_W, y<IMG_H, DE 모두 체크
    // //   - run 종료: is_target 하강 엣지 또는 행 끝 강제 종료

    // module box_maker #(
    //     parameter IMG_W      = 320,
    //     parameter IMG_H      = 240,
    //     parameter NUM_BOXES  = 2,
    //     parameter MAX_BOX_W  = 160,
    //     parameter MAX_BOX_H  = 120,
    //     parameter MIN_PIXELS = 20,
    //     parameter MAX_RUNS   = 4,
    //     parameter GAP_Y      = 5
    // ) (
    //     input logic       rclk,
    //     input logic       reset,
    //     input logic       vsync,
    //     input logic       DE,
    //     input logic [9:0] x_pixel,
    //     input logic [9:0] y_pixel,
    //     input logic       is_target,

    //     output logic [8:0] box_x_min[0:NUM_BOXES-1],
    //     output logic [8:0] box_x_max[0:NUM_BOXES-1],
    //     output logic [7:0] box_y_min[0:NUM_BOXES-1],
    //     output logic [7:0] box_y_max[0:NUM_BOXES-1],
    //     output logic       box_valid[0:NUM_BOXES-1]
    // );

    //     // ── 카메라 좌표: 좌상 셀 기준 ────────────────────────────────
    //     logic [8:0] cam_x;
    //     logic [7:0] cam_y;
    //     assign cam_x = x_pixel[8:0];
    //     assign cam_y = y_pixel[7:0];

    //     // 좌상 셀(x<IMG_W, y<IMG_H)만 처리
    //     logic in_active;
    //     assign in_active = DE && (x_pixel < IMG_W) && (y_pixel < IMG_H);

    //     // ── 1클럭 지연 신호 ──────────────────────────────────────────
    //     logic DE_d;
    //     logic [9:0] x_d, y_d;
    //     logic is_target_d;
    //     logic in_active_d;

    //     always_ff @(posedge rclk) begin
    //         DE_d        <= DE;
    //         x_d         <= x_pixel;
    //         y_d         <= y_pixel;
    //         is_target_d <= is_target;
    //         in_active_d <= in_active;
    //     end

    //     // ── 행 끝 / 프레임 끝: 이전 클럭이 유효 마지막 픽셀이었을 때
    //     // DE_d=1(유효), 현재 DE=0 또는 x가 넘어감 → 행 끝
    //     logic row_end, frame_end;
    //     assign row_end   = DE_d && (x_d == IMG_W - 1) && (y_d < IMG_H - 1);
    //     assign frame_end = DE_d && (x_d == IMG_W - 1) && (y_d == IMG_H - 1);

    //     // ── Run 타입 ──────────────────────────────────────────────────
    //     typedef struct packed {
    //         logic [8:0] x_start;
    //         logic [8:0] x_end;
    //         logic [1:0] box_id;
    //         logic       valid;
    //     } run_t;

    //     run_t                          cur_runs    [ 0:MAX_RUNS-1];
    //     run_t                          prev_runs   [ 0:MAX_RUNS-1];
    //     logic [$clog2(MAX_RUNS+1)-1:0] cur_run_cnt;

    //     logic                          in_run;
    //     logic [                   8:0] run_start_x;

    //     // ── 박스 추적 ─────────────────────────────────────────────────
    //     logic [                   8:0] bx_min      [0:NUM_BOXES-1];
    //     logic [                   8:0] bx_max      [0:NUM_BOXES-1];
    //     logic [                   7:0] by_min      [0:NUM_BOXES-1];
    //     logic [                   7:0] by_max      [0:NUM_BOXES-1];
    //     logic [                  15:0] pix_cnt     [0:NUM_BOXES-1];
    //     logic [                   7:0] last_y      [0:NUM_BOXES-1];
    //     logic                          bactive     [0:NUM_BOXES-1];
    //     logic [                   1:0] next_box_id;

    //     // ── vsync 에지 ────────────────────────────────────────────────
    //     logic vsync_d, frame_start;
    //     always_ff @(posedge rclk) vsync_d <= vsync;
    //     assign frame_start = vsync && !vsync_d;

    //     // ── run 종료 감지 (combinational, 이전 클럭 기준) ─────────────
    //     // 이전 클럭: in_active이고 is_target이었음
    //     // 현재 클럭: is_target=0 또는 active 벗어남
    //     logic run_fell;  // is_target 하강 엣지 (행 중간)
    //     logic run_rowend;  // 행 끝에서 강제 종료

    //     assign run_fell   = in_active_d && is_target_d && in_active && !is_target;
    //     assign run_rowend = row_end && in_run;

    //     // run 종료 시 끝 x좌표
    //     // run_fell: 현재 cam_x-1 (이전 클럭 cam_x = x_d-1이 마지막)
    //     // run_rowend: IMG_W-1
    //     logic [8:0] run_end_x;
    //     assign run_end_x = run_rowend ? (IMG_W - 1) : (x_d[8:0] - 1);
    //     // x_d = 이전 클럭 x_pixel, 즉 마지막 is_target=1이었던 픽셀

    //     integer i, k;

    //     always_ff @(posedge rclk) begin
    //         if (reset || frame_start) begin
    //             for (i = 0; i < MAX_RUNS; i++) begin
    //                 cur_runs[i]  <= '{x_start: '0, x_end: '0, box_id: '0, valid: 1'b0};
    //                 prev_runs[i] <= '{x_start: '0, x_end: '0, box_id: '0, valid: 1'b0};
    //             end
    //             for (i = 0; i < NUM_BOXES; i++) begin
    //                 bx_min[i]    <= 9'd319;
    //                 bx_max[i]    <= 9'd0;
    //                 by_min[i]    <= 8'd239;
    //                 by_max[i]    <= 8'd0;
    //                 pix_cnt[i]   <= '0;
    //                 last_y[i]    <= '0;
    //                 bactive[i]   <= 1'b0;
    //                 box_valid[i] <= 1'b0;
    //                 box_x_min[i] <= '0;
    //                 box_x_max[i] <= '0;
    //                 box_y_min[i] <= '0;
    //                 box_y_max[i] <= '0;
    //             end
    //             cur_run_cnt <= '0;
    //             in_run      <= 1'b0;
    //             run_start_x <= '0;
    //             next_box_id <= '0;

    //         end else begin

    //             // ── 1. run 시작/종료 추적 ────────────────────────────
    //             if (in_active) begin
    //                 if (is_target && !in_run) begin
    //                     in_run      <= 1'b1;
    //                     run_start_x <= cam_x;
    //                 end
    //             end
    //             // 행 끝이나 active 벗어나면 run 강제 종료
    //             if (row_end || frame_end || !in_active) begin
    //                 if (in_active || in_active_d) in_run <= 1'b0;
    //             end
    //             // is_target 하강 시 run 종료
    //             if (run_fell) in_run <= 1'b0;

    //             // ── 2. run 완성 → 박스 매칭 ──────────────────────────
    //             if (run_fell || run_rowend) begin : run_process
    //                 logic [8:0] rx_s, rx_e;
    //                 logic       matched;
    //                 logic [1:0] mid;

    //                 rx_s    = run_start_x;
    //                 rx_e    = run_end_x;

    //                 matched = 1'b0;
    //                 mid     = 2'd0;

    //                 for (k = 0; k < MAX_RUNS; k++) begin
    //                     if (prev_runs[k].valid && !matched) begin
    //                         if (!(rx_e < prev_runs[k].x_start) && !(rx_s > prev_runs[k].x_end)) begin
    //                             matched = 1'b1;
    //                             mid     = prev_runs[k].box_id;
    //                         end
    //                     end
    //                 end

    //                 if (matched) begin
    //                     // 기존 박스 병합
    //                     if (cur_run_cnt < MAX_RUNS) begin
    //                         cur_runs[cur_run_cnt] <= '{x_start: rx_s, x_end: rx_e, box_id: mid, valid: 1'b1};
    //                         cur_run_cnt <= cur_run_cnt + 1;
    //                     end
    //                     if (rx_s < bx_min[mid]) bx_min[mid] <= rx_s;
    //                     if (rx_e > bx_max[mid]) bx_max[mid] <= rx_e;
    //                     // cam_y: run_fell이면 현재 y_pixel, run_rowend면 y_d
    //                     if (run_rowend) begin
    //                         if (y_d[7:0] < by_min[mid]) by_min[mid] <= y_d[7:0];
    //                         if (y_d[7:0] > by_max[mid]) by_max[mid] <= y_d[7:0];
    //                         last_y[mid] <= y_d[7:0];
    //                     end else begin
    //                         if (cam_y < by_min[mid]) by_min[mid] <= cam_y;
    //                         if (cam_y > by_max[mid]) by_max[mid] <= cam_y;
    //                         last_y[mid] <= cam_y;
    //                     end
    //                     pix_cnt[mid] <= pix_cnt[mid] + (rx_e - rx_s + 1);
    //                     bactive[mid] <= 1'b1;

    //                     // 크기 초과 무효화
    //                     if ((bx_max[mid] - bx_min[mid]) > MAX_BOX_W || (by_max[mid] - by_min[mid]) > MAX_BOX_H) begin
    //                         bactive[mid] <= 1'b0;
    //                         bx_min[mid]  <= 9'd319;
    //                         bx_max[mid]  <= 9'd0;
    //                         by_min[mid]  <= 8'd239;
    //                         by_max[mid]  <= 8'd0;
    //                         pix_cnt[mid] <= '0;
    //                     end

    //                 end else if (next_box_id < NUM_BOXES) begin
    //                     // 새 박스
    //                     if (cur_run_cnt < MAX_RUNS) begin
    //                         cur_runs[cur_run_cnt] <= '{x_start: rx_s, x_end: rx_e, box_id: next_box_id, valid: 1'b1};
    //                         cur_run_cnt <= cur_run_cnt + 1;
    //                     end
    //                     bx_min[next_box_id]  <= rx_s;
    //                     bx_max[next_box_id]  <= rx_e;
    //                     by_min[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
    //                     by_max[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
    //                     pix_cnt[next_box_id] <= rx_e - rx_s + 1;
    //                     last_y[next_box_id]  <= run_rowend ? y_d[7:0] : cam_y;
    //                     bactive[next_box_id] <= 1'b1;
    //                     next_box_id          <= next_box_id + 1;
    //                 end
    //             end

    //             // ── 3. 행 끝: prev_runs 교체만 (gap 검사 제거) ────────
    //             if (row_end) begin
    //                 for (i = 0; i < MAX_RUNS; i++) begin
    //                     prev_runs[i] <= cur_runs[i];
    //                     cur_runs[i]  <= '{x_start: '0, x_end: '0, box_id: '0, valid: 1'b0};
    //                 end
    //                 cur_run_cnt <= '0;
    //             end

    //             // ── 4. 프레임 끝: 박스 확정 출력 ─────────────────────
    //             // gap 검사: last_y가 프레임 하단 근처가 아니면 무효
    //             // (bactive 조건 제거 → 프레임 중간에 소멸하지 않음)
    //             if (frame_end) begin
    //                 for (i = 0; i < NUM_BOXES; i++) begin
    //                     if (pix_cnt[i] >= MIN_PIXELS) begin
    //                         box_x_min[i] <= bx_min[i];
    //                         box_x_max[i] <= bx_max[i];
    //                         box_y_min[i] <= by_min[i];
    //                         box_y_max[i] <= by_max[i];
    //                         box_valid[i] <= 1'b1;
    //                     end else begin
    //                         box_valid[i] <= 1'b0;
    //                     end
    //                     bactive[i] <= 1'b0;
    //                     pix_cnt[i] <= '0;
    //                     bx_min[i]  <= 9'd319;
    //                     bx_max[i]  <= 9'd0;
    //                     by_min[i]  <= 8'd239;
    //                     by_max[i]  <= 8'd0;
    //                 end
    //                 next_box_id <= '0;
    //                 for (i = 0; i < MAX_RUNS; i++) begin
    //                     cur_runs[i]  <= '{x_start: '0, x_end: '0, box_id: '0, valid: 1'b0};
    //                     prev_runs[i] <= '{x_start: '0, x_end: '0, box_id: '0, valid: 1'b0};
    //                 end
    //             end

    //         end
    //     end

    // endmodule

    `timescale 1ns / 1ps

    // box_stabilizer
    // box_maker의 raw 출력을 안정화:
    //   ① EMA (Exponential Moving Average): 좌표 떨림 완화
    //   ② 유효성 카운터: N프레임 연속 valid여야 출력
    //
    // EMA 공식: smooth = (prev * (2^EMA_SHIFT - 1) + new) >> EMA_SHIFT
    //   EMA_SHIFT=2 → 75% 이전 + 25% 새값 (빠른 추적)
    //   EMA_SHIFT=3 → 87.5% 이전 + 12.5% 새값 (느린 추적, 더 안정)
    //
    // VALID_THRESH: 몇 프레임 연속 valid여야 출력할지
    //   VALID_THRESH=3 → 3프레임 연속 감지돼야 박스 출력

    `timescale 1ns / 1ps

    // box_stabilizer
    // ① EMA: 좌표 떨림 완화
    // ② valid_cnt: N프레임 연속 valid여야 출력

// //stabilizer
//     module box_stabilizer #(
//         parameter NUM_BOXES   = 2,
//         parameter EMA_SHIFT   = 2,
//         parameter VALID_THRESH = 3
//     ) (
//         input  logic clk,
//         input  logic reset,
//         input  logic vsync,

//         input  logic [8:0] raw_x_min [0:NUM_BOXES-1],
//         input  logic [8:0] raw_x_max [0:NUM_BOXES-1],
//         input  logic [7:0] raw_y_min [0:NUM_BOXES-1],
//         input  logic [7:0] raw_y_max [0:NUM_BOXES-1],
//         input  logic       raw_valid [0:NUM_BOXES-1],

//         output logic [8:0] stb_x_min [0:NUM_BOXES-1],
//         output logic [8:0] stb_x_max [0:NUM_BOXES-1],
//         output logic [7:0] stb_y_min [0:NUM_BOXES-1],
//         output logic [7:0] stb_y_max [0:NUM_BOXES-1],
//         output logic       stb_valid [0:NUM_BOXES-1]
//     );
//         localparam EXT = EMA_SHIFT;

//         // EMA 레지스터: 정수부 + 소수부 EXT비트
//         logic [8+EXT:0] ema_x_min [0:NUM_BOXES-1];
//         logic [8+EXT:0] ema_x_max [0:NUM_BOXES-1];
//         logic [7+EXT:0] ema_y_min [0:NUM_BOXES-1];
//         logic [7+EXT:0] ema_y_max [0:NUM_BOXES-1];

//         // valid 카운터: VALID_THRESH+1까지 표현 가능한 비트폭
//         logic [$clog2(VALID_THRESH+1):0] valid_cnt [0:NUM_BOXES-1];

//         // vsync 상승엣지 = frame_pulse
//         logic vsync_r, frame_pulse;
//         always_ff @(posedge clk) vsync_r <= vsync;
//         assign frame_pulse = vsync && !vsync_r;

//         integer i;

//         always_ff @(posedge clk) begin
//             if (reset) begin
//                 for (i = 0; i < NUM_BOXES; i++) begin
//                     ema_x_min[i] <= '0; ema_x_max[i] <= '0;
//                     ema_y_min[i] <= '0; ema_y_max[i] <= '0;
//                     valid_cnt[i] <= '0;
//                     stb_x_min[i] <= '0; stb_x_max[i] <= '0;
//                     stb_y_min[i] <= '0; stb_y_max[i] <= '0;
//                     stb_valid[i] <= 1'b0;
//                 end

//             end else if (frame_pulse) begin
//                 for (i = 0; i < NUM_BOXES; i++) begin

//                     if (raw_valid[i]) begin
//                         // ① EMA 업데이트
//                         if (valid_cnt[i] == 0) begin
//                             // 첫 프레임: raw값으로 초기화
//                             ema_x_min[i] <= {raw_x_min[i], {EXT{1'b0}}};
//                             ema_x_max[i] <= {raw_x_max[i], {EXT{1'b0}}};
//                             ema_y_min[i] <= {raw_y_min[i], {EXT{1'b0}}};
//                             ema_y_max[i] <= {raw_y_max[i], {EXT{1'b0}}};
//                         end else begin
//                             // EMA: prev*(N-1)/N + new/N, N=2^EMA_SHIFT
//                             // 괄호 필수! >> 는 + 보다 우선순위 높음
//                             ema_x_min[i] <= ema_x_min[i] - (ema_x_min[i] >> EMA_SHIFT)
//                                             + ({raw_x_min[i], {EXT{1'b0}}} >> EMA_SHIFT);
//                             ema_x_max[i] <= ema_x_max[i] - (ema_x_max[i] >> EMA_SHIFT)
//                                             + ({raw_x_max[i], {EXT{1'b0}}} >> EMA_SHIFT);
//                             ema_y_min[i] <= ema_y_min[i] - (ema_y_min[i] >> EMA_SHIFT)
//                                             + ({raw_y_min[i], {EXT{1'b0}}} >> EMA_SHIFT);
//                             ema_y_max[i] <= ema_y_max[i] - (ema_y_max[i] >> EMA_SHIFT)
//                                             + ({raw_y_max[i], {EXT{1'b0}}} >> EMA_SHIFT);
//                         end

//                         // ② valid 카운터 증가
//                         if (valid_cnt[i] < VALID_THRESH)
//                             valid_cnt[i] <= valid_cnt[i] + 1;

//                     end else begin
//                         valid_cnt[i] <= '0;  // 감지 끊기면 카운터 리셋
//                     end

//                     // 출력: VALID_THRESH 도달 시 확정
//                     if (valid_cnt[i] >= VALID_THRESH) begin
//                         stb_x_min[i] <= ema_x_min[i][8+EXT:EXT];
//                         stb_x_max[i] <= ema_x_max[i][8+EXT:EXT];
//                         stb_y_min[i] <= ema_y_min[i][7+EXT:EXT];
//                         stb_y_max[i] <= ema_y_max[i][7+EXT:EXT];
//                         stb_valid[i] <= 1'b1;
//                     end else begin
//                         stb_valid[i] <= 1'b0;
//                     end
//                 end
//             end
//         end

//     endmodule