`timescale 1ns/1ps

module tb_i2c_master;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;

    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    reg ena;
    reg clk;
    reg rst_n;

    // Ket noi module I2C Master
    tt_um_i2c_master uut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    // Tao xung clock chu ky 20 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // Ghi waveform
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_i2c_master);
    end

    // Kich thich dau vao
    initial begin
        ui_in  = 8'b00000000;
        uio_in = 8'b00000000;
        ena    = 1'b1;
        rst_n  = 1'b0;

        // Reset
        #100;
        rst_n = 1'b1;

        // Cho he thong khoi dong
        #100;

        // Dua du lieu thu vao
        ui_in = 8'b10101010;
        #100;

        // Bat dau giao dich
        ui_in[7] = 1'b1;
        #100000;

        // Ket thuc yeu cau
        ui_in[7] = 1'b0;
        #500;

        // Ket thuc mo phong
        $finish;
    end

    // Theo doi cac tin hieu chinh
    initial begin
        $monitor(
            "time=%0t clk=%b rst_n=%b SCL=%b SDA=%b done=%b busy=%b error=%b",
            $time,
            clk,
            rst_n,
            uo_out[0],
            uio_out[0],
            uo_out[2],
            uo_out[4],
            uo_out[3]
        );
    end

endmodule
