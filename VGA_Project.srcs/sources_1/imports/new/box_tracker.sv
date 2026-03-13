`timescale 1ns / 1ps

// box_tracker: 중심점 거리 기반 ID 안정화
// 타이밍: vsync 하강엣지 (box_maker 프레임 완료 후)
// 임시변수를 모두 모듈 레벨로 이동 → Vivado 합성 안전

module box_tracker #(
    parameter NUM_BOXES   = 2,
    parameter DIST_THRESH = 40,
    parameter HOLD_MAX    = 10
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       vsync,

    input  logic [8:0] raw_x_min [0:NUM_BOXES-1],
    input  logic [8:0] raw_x_max [0:NUM_BOXES-1],
    input  logic [7:0] raw_y_min [0:NUM_BOXES-1],
    input  logic [7:0] raw_y_max [0:NUM_BOXES-1],
    input  logic       raw_valid [0:NUM_BOXES-1],

    output logic [8:0] trk_x_min [0:NUM_BOXES-1],
    output logic [8:0] trk_x_max [0:NUM_BOXES-1],
    output logic [7:0] trk_y_min [0:NUM_BOXES-1],
    output logic [7:0] trk_y_max [0:NUM_BOXES-1],
    output logic       trk_valid [0:NUM_BOXES-1]
);

    // ── 추적 슬롯 ────────────────────────────────────────────────
    logic [8:0] trk_cx  [0:NUM_BOXES-1];
    logic [7:0] trk_cy  [0:NUM_BOXES-1];
    logic [$clog2(HOLD_MAX+1):0] hold_cnt [0:NUM_BOXES-1];

    // ── vsync 하강엣지 ────────────────────────────────────────────
    logic vsync_d, frame_pulse;
    always_ff @(posedge clk) vsync_d <= vsync;
    assign frame_pulse = !vsync && vsync_d;

    // ── 임시변수: 모듈 레벨 선언 (Vivado 합성 안전) ──────────────
    logic       raw_matched [0:NUM_BOXES-1];
    logic       trk_matched [0:NUM_BOXES-1];
    logic [1:0] raw_to_trk  [0:NUM_BOXES-1];

    logic [8:0] raw_cx [0:NUM_BOXES-1];
    logic [7:0] raw_cy [0:NUM_BOXES-1];
    logic [9:0] best_dist [0:NUM_BOXES-1];
    logic [1:0] best_id   [0:NUM_BOXES-1];
    logic       found     [0:NUM_BOXES-1];
    logic [9:0] dist_tmp  [0:NUM_BOXES-1][0:NUM_BOXES-1];

    // ── Manhattan 거리 함수 ───────────────────────────────────────
    function automatic logic [9:0] manhattan(
        input logic [8:0] ax, input logic [7:0] ay,
        input logic [8:0] bx, input logic [7:0] by
    );
        return ({1'b0, (ax > bx) ? (ax - bx) : (bx - ax)}) +
               ({2'b0, (ay > by) ? (ay - by) : (by - ay)});
    endfunction

    integer i, j;

    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < NUM_BOXES; i++) begin
                trk_x_min[i] <= '0; trk_x_max[i] <= '0;
                trk_y_min[i] <= '0; trk_y_max[i] <= '0;
                trk_valid[i] <= 1'b0;
                trk_cx[i]    <= '0; trk_cy[i]    <= '0;
                hold_cnt[i]  <= '0;
            end

        end else if (frame_pulse) begin

            // Step 1: 임시변수 초기화
            for (i = 0; i < NUM_BOXES; i++) begin
                raw_matched[i] = 1'b0;
                trk_matched[i] = 1'b0;
                raw_to_trk[i]  = '0;
                raw_cx[i] = (raw_x_min[i] + raw_x_max[i]) >> 1;
                raw_cy[i] = (raw_y_min[i] + raw_y_max[i]) >> 1;
                best_dist[i] = 10'h3FF;
                best_id[i]   = '0;
                found[i]     = 1'b0;
            end

            // Step 2: 거리 계산 및 최근접 trk 슬롯 탐색
            for (j = 0; j < NUM_BOXES; j++) begin
                if (raw_valid[j]) begin
                    for (i = 0; i < NUM_BOXES; i++) begin
                        dist_tmp[j][i] = manhattan(raw_cx[j], raw_cy[j],
                                                   trk_cx[i], trk_cy[i]);
                        if (hold_cnt[i] > 0 && !trk_matched[i]) begin
                            if (dist_tmp[j][i] < best_dist[j]) begin
                                best_dist[j] = dist_tmp[j][i];
                                best_id[j]   = i[1:0];
                                found[j]     = 1'b1;
                            end
                        end
                    end
                    if (found[j] && best_dist[j] <= DIST_THRESH) begin
                        raw_matched[j]          = 1'b1;
                        trk_matched[best_id[j]] = 1'b1;
                        raw_to_trk[j]           = best_id[j];
                    end
                end
            end

            // Step 3: 매칭된 raw → trk 업데이트
            for (j = 0; j < NUM_BOXES; j++) begin
                if (raw_valid[j] && raw_matched[j]) begin
                    trk_x_min[raw_to_trk[j]] <= raw_x_min[j];
                    trk_x_max[raw_to_trk[j]] <= raw_x_max[j];
                    trk_y_min[raw_to_trk[j]] <= raw_y_min[j];
                    trk_y_max[raw_to_trk[j]] <= raw_y_max[j];
                    trk_valid[raw_to_trk[j]] <= 1'b1;
                    trk_cx[raw_to_trk[j]]    <= raw_cx[j];
                    trk_cy[raw_to_trk[j]]    <= raw_cy[j];
                    hold_cnt[raw_to_trk[j]]  <= HOLD_MAX[$clog2(HOLD_MAX+1):0];
                end
            end

            // Step 4: 매칭 안 된 raw → 빈 슬롯 할당
            for (j = 0; j < NUM_BOXES; j++) begin
                if (raw_valid[j] && !raw_matched[j]) begin
                    for (i = 0; i < NUM_BOXES; i++) begin
                        if (hold_cnt[i] == 0 && !trk_matched[i]) begin
                            trk_x_min[i] <= raw_x_min[j];
                            trk_x_max[i] <= raw_x_max[j];
                            trk_y_min[i] <= raw_y_min[j];
                            trk_y_max[i] <= raw_y_max[j];
                            trk_valid[i] <= 1'b1;
                            trk_cx[i]    <= raw_cx[j];
                            trk_cy[i]    <= raw_cy[j];
                            hold_cnt[i]  <= HOLD_MAX[$clog2(HOLD_MAX+1):0];
                            trk_matched[i] = 1'b1;
                        end
                    end
                end
            end

            // Step 5: 매칭 안 된 ACTIVE trk → hold_cnt 감소
            for (i = 0; i < NUM_BOXES; i++) begin
                if (hold_cnt[i] > 0 && !trk_matched[i]) begin
                    hold_cnt[i] <= hold_cnt[i] - 1;
                    if (hold_cnt[i] == 1)
                        trk_valid[i] <= 1'b0;
                end
            end

        end
    end

endmodule
