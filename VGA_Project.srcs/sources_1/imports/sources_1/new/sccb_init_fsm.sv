`timescale 1ns / 1ps
//=============================================================================
// SCCB Init FSM — OV7670_REG.h 기반 정확한 레지스터 테이블
//
// 전송 순서 (main.c + OV7670.c 동작 순서 그대로):
//   1. 소프트 리셋 (0x12 = 0x80)             ← OV7670_ResetSW()
//   2. defaults[] 테이블                      ← OV7670_Config(defaults)
//   3. QVGA 해상도 (RES_QVGA[])              ← OV7670_SetResolution(QVGA)
//   4. SetFrameControl(168,24,12,492)         ← OV7670_SetResolution 내부
//   5. RGB565 설정                            ← OV7670_SetColorFormat(RGB565)
//   6. ShowColorBar(0)                        ← main.c
//   7. AEC/AGC/AWB 등                         ← main.c
//   8. 밝기/대비/채도/샤프니스                ← main.c
//=============================================================================
module sccb_init_fsm (
    input  logic       clk,
    input  logic       reset,
    output logic       sccb_start,
    output logic [7:0] sccb_reg_addr,
    output logic [7:0] sccb_reg_data,
    input  logic       sccb_done,
    output logic       ov_reset,
    output logic       ov_pwdn,
    output logic       init_done
);


  typedef enum logic [3:0] {
    S_PWDN_OFF,
    S_WAIT_PWDN,
    S_RESET_LOW,
    S_WAIT_RST_LOW,
    S_RESET_HIGH,
    S_WAIT_RST_HIGH,
    S_LOAD_REG,
    S_SEND_START,
    S_WAIT_DONE,
    S_DELAY,
    S_NEXT,
    S_FINISHED
  } state_t;

  state_t        state;
  logic   [ 7:0] reg_index;
  logic   [23:0] delay_cnt;

  // 레지스터 테이블 (ROM)
  // OV7670_REG.h
  localparam int NUM_REGS = 80;
  logic [15:0] reg_rom[0:NUM_REGS-1];

  wire [7:0] rom_addr = reg_rom[reg_index][15:8];
  wire [7:0] rom_data = reg_rom[reg_index][7:0];

  initial begin
    // [1] 소프트 리셋 — OV7670_ResetSW() 첫 줄
    //     이후 30ms 딜레이 (FSM에서 자동 처리)
    reg_rom[0]  = {8'h12, 8'h80};  // COM7 = 소프트 리셋

    // [2] defaults[] 테이블
    reg_rom[1]  = {8'h3A, 8'h04};  // TSLB: OV important
    reg_rom[2]  = {8'h12, 8'h00};  // COM7: VGA (기본)

    reg_rom[3]  = {8'h13, 8'hE7};  // COM8: Fast AGC/AEC, AGC=1, AWB=1, AEC=1
    reg_rom[4]  = {8'h6F, 8'h9F};  // AWBCTR0: White balance
    reg_rom[5]  = {8'hB0, 8'h84};  // 0xB0: important for color

    reg_rom[6]  = {8'h70, 8'h3A};  // SCALING_XSC
    reg_rom[7]  = {8'h71, 8'h35};  // SCALING_YSC
    reg_rom[8]  = {8'h72, 8'h11};  // SCALING_DCWCTR
    reg_rom[9]  = {8'h73, 8'hF0};  // SCALING_PCLK_DIV

    // Gamma curve values
    reg_rom[10] = {8'h7A, 8'h20};  // SLOP
    reg_rom[11] = {8'h7B, 8'h10};  // GAM1
    reg_rom[12] = {8'h7C, 8'h1E};  // GAM2
    reg_rom[13] = {8'h7D, 8'h35};  // GAM3
    reg_rom[14] = {8'h7E, 8'h5A};  // GAM4
    reg_rom[15] = {8'h7F, 8'h69};  // GAM5
    reg_rom[16] = {8'h80, 8'h76};  // GAM6
    reg_rom[17] = {8'h81, 8'h80};  // GAM7
    reg_rom[18] = {8'h82, 8'h88};  // GAM8
    reg_rom[19] = {8'h83, 8'h8F};  // GAM9
    reg_rom[20] = {8'h84, 8'h96};  // GAM10
    reg_rom[21] = {8'h85, 8'hA3};  // GAM11
    reg_rom[22] = {8'h86, 8'hAF};  // GAM12
    reg_rom[23] = {8'h87, 8'hC4};  // GAM13
    reg_rom[24] = {8'h88, 8'hD7};  // GAM14
    reg_rom[25] = {8'h89, 8'hE8};  // GAM15

    // AGC/AEC 상세 설정
    reg_rom[26] = {8'h00, 8'h00};  // GAIN
    reg_rom[27] = {8'h10, 8'h00};  // AECH
    reg_rom[28] = {8'h0D, 8'h40};  // COM4: magic reserved bit
    reg_rom[29] = {8'h14, 8'h18};  // COM9: 4x gain + magic rsvd
    reg_rom[30] = {8'hA5, 8'h05};  // BD50MAX
    reg_rom[31] = {8'hAB, 8'h07};  // BD60MAX
    reg_rom[32] = {8'h24, 8'h95};  // AEW
    reg_rom[33] = {8'h25, 8'h33};  // AEB
    reg_rom[34] = {8'h26, 8'hE3};  // VPT
    reg_rom[35] = {8'h9F, 8'h78};  // HAECC1
    reg_rom[36] = {8'hA0, 8'h68};  // HAECC2
    reg_rom[37] = {8'hA1, 8'h03};  // 0xA1: magic
    reg_rom[38] = {8'hA6, 8'hD8};  // HAECC3
    reg_rom[39] = {8'hA7, 8'hD8};  // HAECC4
    reg_rom[40] = {8'hA8, 8'hF0};  // HAECC5
    reg_rom[41] = {8'hA9, 8'h90};  // HAECC6
    reg_rom[42] = {8'hAA, 8'h94};  // HAECC7

    // [3] RES_QVGA[] — OV7670_SetResolution(QVGA)
    //     OV7670_REG.h의 RES_QVGA 테이블 그대로
    reg_rom[43] = {8'h12, 8'h11};  // COM7
    reg_rom[44] = {8'h0C, 8'h04};  // COM3: DCW enable
    reg_rom[45] = {8'h3E, 8'h19};  // COM14
    reg_rom[46] = {8'h70, 8'h3A};  // SCALING_XSC
    reg_rom[47] = {8'h71, 8'h35};  // SCALING_YSC
    reg_rom[48] = {8'h72, 8'h11};  // SCALING_DCWCTR
    reg_rom[49] = {8'h73, 8'hF1};  // SCALING_PCLK_DIV
    reg_rom[50] = {8'hA2, 8'h02};  // SCALING_PCLK_DELAY

    // [4] SetFrameControl(168, 24, 12, 492)
    //     C 함수 로직 계산:
    //     HSTART  = 168>>3        = 21  = 0x15
    //     HSTOP   = 24>>3         = 3   = 0x03
    //     HREF    = ((24&7)<<3)|(168&7) = (0<<3)|0 = 0x00
    //     VSTART  = 12>>2         = 3   = 0x03
    //     VSTOP   = 492>>2        = 123 = 0x7B
    //     VREF    = ((492&3)<<2)|(12&3) = (0<<2)|0 = 0x00
    reg_rom[51] = {8'h17, 8'h15};  // HSTART
    reg_rom[52] = {8'h18, 8'h03};  // HSTOP
    reg_rom[53] = {8'h32, 8'h00};  // HREF
    reg_rom[54] = {8'h19, 8'h03};  // VSTART
    reg_rom[55] = {8'h1A, 8'h7B};  // VSTOP
    reg_rom[56] = {8'h03, 8'h00};  // VREF

    // [5] RGB565 설정 — OV7670_SetColorFormat(RGB565)
    //     COM7: (현재 0x11) & 0xFA = 0x10, | 0x04 = 0x14
    //     COM15: (기본값) & 0x0F, | 0x10 → 안전하게 0xD0
    reg_rom[57] = {8'h12, 8'h14};  // COM7: QVGA + RGB
    reg_rom[58] = {8'h40, 8'hD0};  // COM15: RGB565
    reg_rom[59] = {8'h8C, 8'h00};  // RGB444: 비활성화

    // [6] ShowColorBar(0)
    //     COM17 bit3 = 0
    reg_rom[60] = {8'h42, 8'h00};  // COM17: 컬러바 OFF

    // [7] main.c 설정
    // COM8 = 0xE7 (AEC+AGC+AWB ON) — defaults에서 이미 설정됨, 재확인
    reg_rom[61] = {8'h13, 8'hE7};  // COM8

    // OV7670_SetAECAlgorithm(0) → Average-based
    // HAECC7 현재 0x94, & 0x7F = 0x14
    reg_rom[62] = {8'hAA, 8'h14};  // HAECC7: Average-based

    // OV7670_SetBrightness(120)
    // 120 < 127 → 255 - 120 = 135 = 0x87
    reg_rom[63] = {8'h55, 8'h87};  // BRIGHT

    // OV7670_SetGainCeiling(1) → COM9 = (0x18 & 0x8F) | (1<<4) = 0x18
    reg_rom[64] = {8'h14, 8'h18};  // COM9: gain ceiling 4x

    // OV7670_SetSharpness(10) → EDGE = (0x00 & 0xE0) | 10 = 0x0A
    reg_rom[65] = {8'h3F, 8'h0A};  // EDGE: sharpness=10

    // OV7670_SetContrast(80) → 80 = 0x50
    reg_rom[66] = {8'h56, 8'h50};  // CONTRAS

    // OV7670_SetSaturation(60)
    // saturation = 60 + 20 = 80, mtx_rgb * 80 / 100:
    //   MTX1: 0xB3(179)*0.8 = 143 = 0x8F
    //   MTX2: 0xB3(179)*0.8 = 143 = 0x8F
    //   MTX3: 0x00(0)*0.8   = 0   = 0x00
    //   MTX4: 0x3D(61)*0.8  = 48  = 0x30
    //   MTX5: 0xB0(176)*0.8 = 140 = 0x8C
    //   MTX6: 0xE4(228)*0.8 = 182 = 0xB6
    reg_rom[67] = {8'h4F, 8'h8F};  // MTX1
    reg_rom[68] = {8'h50, 8'h8F};  // MTX2
    reg_rom[69] = {8'h51, 8'h00};  // MTX3
    reg_rom[70] = {8'h52, 8'h30};  // MTX4
    reg_rom[71] = {8'h53, 8'h8C};  // MTX5
    reg_rom[72] = {8'h54, 8'hB6};  // MTX6
    reg_rom[73] = {8'h58, 8'h9E};  // MTXS

    // [8] 클럭/PLL/기타
    reg_rom[74] = {8'h11, 8'h01};  // CLKRC: 프리스케일러
    reg_rom[75] = {8'h6B, 8'h4A};  // DBLV: PLL x4
    reg_rom[76] = {8'h1E, 8'h07};  // MVFP: 미러/플립 OFF

    // 종료 마커
    reg_rom[77] = {8'hFF, 8'hFF};
    reg_rom[78] = {8'hFF, 8'hFF};
    reg_rom[79] = {8'hFF, 8'hFF};
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state         <= S_PWDN_OFF;
      reg_index     <= 8'd0;
      delay_cnt     <= 24'd0;
      init_done     <= 1'b0;
      sccb_start    <= 1'b0;
      sccb_reg_addr <= 8'd0;
      sccb_reg_data <= 8'd0;
      ov_reset      <= 1'b0;
      ov_pwdn       <= 1'b1;
    end else begin
      sccb_start <= 1'b0;

      case (state)

        S_PWDN_OFF: begin
          ov_pwdn   <= 1'b0;  // 파워다운 해제
          delay_cnt <= 24'd5_000_000;  // 50ms @100MHz
          state     <= S_WAIT_PWDN;
        end

        S_WAIT_PWDN: begin
          if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
          else begin
            ov_reset  <= 1'b0;
            delay_cnt <= 24'd5_000_000;  // 50ms
            state     <= S_RESET_LOW;
          end
        end

        S_RESET_LOW: begin
          if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
          else begin
            ov_reset  <= 1'b1;  // RESET 해제
            delay_cnt <= 24'd5_000_000;  // 50ms
            state     <= S_WAIT_RST_LOW;
          end
        end

        S_WAIT_RST_LOW: begin
          if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
          else begin
            delay_cnt <= 24'd10_000_000;  // 100ms 안정화
            state     <= S_RESET_HIGH;
          end
        end

        S_RESET_HIGH: begin
          if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
          else begin
            delay_cnt <= 24'd5_000_000;  // 50ms
            state     <= S_WAIT_RST_HIGH;
          end
        end

        S_WAIT_RST_HIGH: begin
          if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
          else begin
            reg_index <= 8'd0;
            state     <= S_LOAD_REG;
          end
        end

        S_LOAD_REG: begin
          if (rom_addr == 8'hFF) begin
            state <= S_FINISHED;
          end else begin
            sccb_reg_addr <= rom_addr;
            sccb_reg_data <= rom_data;
            state         <= S_SEND_START;
          end
        end

        S_SEND_START: begin
          sccb_start <= 1'b1;
          state      <= S_WAIT_DONE;
        end

        S_WAIT_DONE: begin
          if (sccb_done) begin
            if (reg_index == 8'd0) delay_cnt <= 24'd3_000_000;  // 30ms (소프트리셋 후)
            else delay_cnt <= 24'd100_000;  // 1ms
            state <= S_DELAY;
          end
        end

        S_DELAY: begin
          if (delay_cnt > 0) delay_cnt <= delay_cnt - 1;
          else state <= S_NEXT;
        end

        S_NEXT: begin
          reg_index <= reg_index + 1;
          state     <= S_LOAD_REG;
        end

        S_FINISHED: begin
          init_done <= 1'b1;
        end

        default: state <= S_PWDN_OFF;
      endcase
    end
  end

endmodule
