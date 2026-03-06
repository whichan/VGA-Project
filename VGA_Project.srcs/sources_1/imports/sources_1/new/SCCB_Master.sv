`timescale 1ns / 1ps

module sccb_master #(
    parameter int CLK_FREQ  = 100_000_000,  // 시스템 클럭 (100MHz)
    parameter int SCCB_FREQ = 100_000       // SCCB 클럭 (100kHz)
) (
    input logic clk,
    input logic reset,

    // 제어 인터페이스
    input  logic       start,     // 1-클럭 펄스 → 전송 시작
    input  logic [7:0] reg_addr,  // 레지스터 주소
    input  logic [7:0] reg_data,  // 쓸 데이터
    output logic       busy,      // 전송 중
    output logic       done,      // 전송 완료 (1-클럭 펄스)

    // OV7670 물리 핀
    output logic sioc,  // SCCB Clock (SCL)
    inout  wire  siod   // SCCB Data  (SDA, open-drain)
);

  // =========================================================================
  // 위상 카운터: SCCB 클럭의 1/4 주기마다 phase_tick 생성
  // 100MHz / (100kHz × 4) = 250 → PHASE_MAX = 249
  // phase 0,1,2,3 = SCL의 LOW전반, HIGH전반, HIGH후반, LOW후반
  // =========================================================================
  localparam int PHASE_MAX = CLK_FREQ / (SCCB_FREQ * 4) - 1;

  logic sioc_reg;
  logic sda_drive;  // 1 = SDA를 LOW로 끌어내림, 0 = 해제(풀업=HIGH)

  assign sioc = sioc_reg;
  assign siod = sda_drive ? 1'b0 : 1'bz;  // open-drain

  int unsigned phase_cnt;
  logic        phase_tick;

  always_ff @(posedge clk or posedge reset) begin
    if (reset || !busy) begin
      phase_cnt  <= 0;
      phase_tick <= 1'b0;
    end else begin
      phase_tick <= 1'b0;
      if (phase_cnt == PHASE_MAX) begin
        phase_cnt  <= 0;
        phase_tick <= 1'b1;
      end else begin
        phase_cnt <= phase_cnt + 1;
      end
    end
  end

  // =========================================================================
  // 상태 정의
  // =========================================================================
  // SCCB 3-Phase Write 시퀀스:
  //   [START] [0x42 + W] [ACK*] [reg_addr] [ACK*] [reg_data] [ACK*] [STOP]
  //   * ACK = Don't Care (무시)
  //
  // 바이트 전송 3회: phase_num = 0 (장치주소), 1 (레지스터), 2 (데이터)
  // =========================================================================
  typedef enum logic [3:0] {
    IDLE,
    START_0,  // SDA↓ (SCL=HIGH 상태에서)
    START_1,  // SCL↓
    DATA,     // 8비트 전송 (MSB first)
    ACK,      // ACK 구간 (Don't Care — SDA 해제만)
    STOP_0,   // SDA=LOW 확보
    STOP_1,   // SCL↑
    STOP_2    // SDA↑ → STOP 조건
  } state_t;

  state_t       state;
  logic   [1:0] phase;  // SCL 위상 (0~3)
  logic   [2:0] bit_idx;  // 비트 인덱스 (7~0, MSB first)
  logic   [7:0] shift_reg;  // 현재 전송 중인 바이트
  logic   [1:0] phase_num;  // 바이트 번호 (0=주소, 1=레지스터, 2=데이터)

  logic   [7:0] reg_addr_r;  // 래치된 레지스터 주소
  logic   [7:0] reg_data_r;  // 래치된 데이터

  // OV7670 쓰기 주소 = 0x42 = 7'b010_0001 + W(0) = 8'b0100_0010
  localparam logic [7:0] OV7670_WRITE_ADDR = 8'h42;

  // =========================================================================
  // 메인 상태머신
  // =========================================================================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state      <= IDLE;
      phase      <= 2'd0;
      bit_idx    <= 3'd7;
      shift_reg  <= 8'd0;
      phase_num  <= 2'd0;
      reg_addr_r <= 8'd0;
      reg_data_r <= 8'd0;
      busy       <= 1'b0;
      done       <= 1'b0;
      sioc_reg   <= 1'b1;  // SCL idle = HIGH
      sda_drive  <= 1'b0;  // SDA idle = HIGH (해제)
    end else begin
      done <= 1'b0;  // done은 1-클럭 펄스

      case (state)

        // ─────────────────────────────────────────────
        // IDLE: 대기 상태
        // ─────────────────────────────────────────────
        IDLE: begin
          sioc_reg  <= 1'b1;
          sda_drive <= 1'b0;
          if (start) begin
            busy       <= 1'b1;
            reg_addr_r <= reg_addr;  // 입력값 래치
            reg_data_r <= reg_data;
            phase_num  <= 2'd0;
            shift_reg  <= OV7670_WRITE_ADDR;  // 첫 바이트 = 0x42
            bit_idx    <= 3'd7;
            phase      <= 2'd0;
            state      <= START_0;
          end
        end

        // ─────────────────────────────────────────────
        // START 조건: SCL=HIGH일 때 SDA를 HIGH→LOW
        // ─────────────────────────────────────────────
        START_0: begin
          if (phase_tick) begin
            sda_drive <= 1'b1;  // SDA → LOW (Start 조건)
            state     <= START_1;
          end
        end

        START_1: begin
          if (phase_tick) begin
            sioc_reg <= 1'b0;  // SCL → LOW
            phase    <= 2'd0;
            state    <= DATA;
          end
        end

        // ─────────────────────────────────────────────
        // DATA: 8비트 전송 (MSB first)
        // phase 0: SCL LOW  → SDA에 비트 세팅
        // phase 1: SCL HIGH → Slave가 샘플링
        // phase 2: SCL HIGH (유지)
        // phase 3: SCL LOW  → 다음 비트 준비
        // ─────────────────────────────────────────────
        DATA: begin
          if (phase_tick) begin
            phase <= phase + 1;
            case (phase)
              2'd0: begin
                sioc_reg  <= 1'b0;
                // MSB first: shift_reg[7]이 현재 전송할 비트
                // sda_drive=1 → SDA=LOW, sda_drive=0 → SDA=HIGH
                sda_drive <= ~shift_reg[7];
              end
              2'd1: begin
                sioc_reg <= 1'b1;  // SCL↑ (Slave 샘플링)
              end
              2'd2: begin
                // SCL HIGH 유지
              end
              2'd3: begin
                sioc_reg <= 1'b0;  // SCL↓
                if (bit_idx == 3'd0) begin
                  // 8비트 전송 완료 → ACK 구간으로
                  bit_idx <= 3'd7;
                  phase   <= 2'd0;
                  state   <= ACK;
                end else begin
                  shift_reg <= {shift_reg[6:0], 1'b0};  // 왼쪽 시프트
                  bit_idx   <= bit_idx - 1;
                end
              end
            endcase
          end
        end

        // ─────────────────────────────────────────────
        // ACK: Don't Care (SCCB 스펙)
        // SDA를 해제하고, SCL 한 사이클 보내고, 무시
        // ─────────────────────────────────────────────
        ACK: begin
          if (phase_tick) begin
            phase <= phase + 1;
            case (phase)
              2'd0: begin
                sioc_reg  <= 1'b0;
                sda_drive <= 1'b0;  // SDA 해제 (Slave가 구동하든 말든)
              end
              2'd1: begin
                sioc_reg <= 1'b1;  // SCL↑
              end
              2'd2: begin
                // ACK 비트 읽지 않음 — Don't Care
              end
              2'd3: begin
                sioc_reg <= 1'b0;    // SCL↓
                phase    <= 2'd0;

                // 다음 바이트 결정
                case (phase_num)
                  2'd0: begin
                    // 장치 주소 전송 완료 → 레지스터 주소
                    phase_num <= 2'd1;
                    shift_reg <= reg_addr_r;
                    state     <= DATA;
                  end
                  2'd1: begin
                    // 레지스터 주소 전송 완료 → 데이터
                    phase_num <= 2'd2;
                    shift_reg <= reg_data_r;
                    state     <= DATA;
                  end
                  2'd2: begin
                    // 데이터 전송 완료 → STOP
                    state <= STOP_0;
                  end
                  default: state <= STOP_0;
                endcase
              end
            endcase
          end
        end

        // ─────────────────────────────────────────────
        // STOP 조건: SCL=HIGH일 때 SDA를 LOW→HIGH
        // ─────────────────────────────────────────────
        STOP_0: begin
          if (phase_tick) begin
            sioc_reg  <= 1'b0;
            sda_drive <= 1'b1;  // SDA → LOW 확보
            state     <= STOP_1;
          end
        end

        STOP_1: begin
          if (phase_tick) begin
            sioc_reg <= 1'b1;  // SCL → HIGH
            state    <= STOP_2;
          end
        end

        STOP_2: begin
          if (phase_tick) begin
            sda_drive <= 1'b0;  // SDA → HIGH (Stop 조건)
            busy      <= 1'b0;
            done      <= 1'b1;  // 완료 펄스
            state     <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
