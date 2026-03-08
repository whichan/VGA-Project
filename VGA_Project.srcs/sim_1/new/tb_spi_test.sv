`timescale 1ns / 1ps

module tb_spi_core ();

  // 입력 신호
  logic clk_100M;
  logic reset;
  logic [8:0] box_x_min, box_x_max;
  logic [7:0] box_y_min, box_y_max;
  logic        box_valid;
  logic        vsync;
  logic        miso;

  // 내부 연결 및 출력 신호
  logic        spi_start;
  logic [15:0] spi_tx_data;
  logic        spi_tx_ready;
  logic        spi_done;
  logic [15:0] spi_rx_data;

  logic        sclk;
  logic        mosi;
  logic        cs;

  // FSM 인스턴스화
  spi_send_fsm U_SPI_SEND_FSM (
      .clk         (clk_100M),
      .reset       (reset),
      .box_x_min   (box_x_min),
      .box_x_max   (box_x_max),
      .box_y_min   (box_y_min),
      .box_y_max   (box_y_max),
      .box_valid   (box_valid),
      .vsync       (vsync),
      .spi_start   (spi_start),
      .spi_tx_data (spi_tx_data),
      .spi_done    (spi_done),
      .spi_tx_ready(spi_tx_ready)
  );

  // SPI 마스터 인스턴스화
  spi_master U_SPI_MASTER (
      .clk     (clk_100M),
      .reset   (reset),
      .start   (spi_start),
      .tx_data (spi_tx_data),
      .tx_ready(spi_tx_ready),
      .rx_data (spi_rx_data),
      .done    (spi_done),
      .sclk    (sclk),
      .mosi    (mosi),
      .miso    (miso),
      .cs      (cs)
  );

  // 100MHz 클럭 생성
  always #5 clk_100M = ~clk_100M;

  initial begin
    // 1. 초기화
    clk_100M = 0;
    reset = 1;
    vsync = 0;
    miso = 0;

    // 2. 가상의 객체 좌표 주입 (Center X: 100, Center Y: 120 예상)
    box_x_min = 9'd80;
    box_x_max = 9'd120;
    box_y_min = 8'd100;
    box_y_max = 8'd140;
    box_valid = 1;

    #100 reset = 0;
    #200;

    // 3. VSYNC 펄스 발생 (Falling Edge에서 FSM이 동작 시작함)
    vsync = 1;
    #500;
    vsync = 0;

    // 4. SPI 전송 완료 대기 (약 35us 소요됨)
    #40000;

    $finish;
  end

endmodule
