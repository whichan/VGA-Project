module ImgMEMReader_overlay (
    input  logic                       DE,
    input  logic [                9:0] x_pixel,
    input  logic [                9:0] y_pixel,
    output logic [$clog2(320*240)-1:0] addr,
    input  logic [               15:0] imgData,
    output logic [                3:0] port_red,
    output logic [                3:0] port_green,
    output logic [                3:0] port_blue
);
  assign addr = DE ? (320 * (y_pixel >> 1) + (x_pixel >> 1)) : 'bz;
  assign {port_red, port_green, port_blue} = DE ? {
        imgData[15:12], imgData[10:7], imgData[4:1]
    } : 12'b0;
endmodule
