module sccb_reg_table (
    input  wire [7:0]  index,     // 몇 번째 레지스터인지
    output reg  [7:0]  reg_addr,  // 레지스터 주소
    output reg  [7:0]  reg_data   // 설정할 값
);

  always @(*) begin
    case (index)
      // ===== OV7670_ResetSW() =====
      0: begin
        reg_addr = 8'h12;
        reg_data = 8'h80;
      end  // 소프트 리셋

      // ===== defaults 테이블 (OV7670_REG.h에서 가져옴) =====
      1: begin
        reg_addr = 8'h3A;
        reg_data = 8'h04;
      end
      2: begin
        reg_addr = 8'h40;
        reg_data = 8'hD0;
      end
      3: begin
        reg_addr = 8'h12;
        reg_data = 8'h04;
      end  // RGB mode
      // ... defaults 테이블의 나머지 항목들 ...

      // ===== OV7670_SetResolution(QVGA) =====
      // RES_QVGA 테이블 + SetFrameControl(168,24,12,492)
      30: begin
        reg_addr = 8'h0C;
        reg_data = 8'h04;
      end  // QVGA 설정 예시
      31: begin
        reg_addr = 8'h3E;
        reg_data = 8'h19;
      end
      // ... QVGA 레지스터들 ...

      // ===== OV7670_SetColorFormat(RGB565) =====
      40: begin
        reg_addr = 8'h12;
        reg_data = 8'h04;
      end  // COM7: RGB
      41: begin
        reg_addr = 8'h40;
        reg_data = 8'hD0;
      end  // COM15: RGB565

      // ===== 기타 설정들 =====
      // OV7670_AutoExposureMode(1)
      42: begin
        reg_addr = 8'h13;
        reg_data = 8'hE7;
      end  // COM8: AEC+AGC+AWB ON

      // OV7670_SetBrightness(120)
      43: begin
        reg_addr = 8'h55;
        reg_data = 8'h00;
      end  // BRIGHT

      // OV7670_SetContrast(80)
      44: begin
        reg_addr = 8'h56;
        reg_data = 8'h50;
      end  // CONTRAS

      // ... 나머지 설정들 ...

      // 종료 마커
      default: begin
        reg_addr = 8'hFF;
        reg_data = 8'hFF;
      end
    endcase
  end
endmodule
