
module tt_um_i2c_master #(
    parameter integer CLK_DIV = 1
) (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // =========================================================
    // State machine
    // =========================================================
    localparam [3:0]
        IDLE         = 4'd0,
        START        = 4'd1,
        ADDR         = 4'd2,
        ACK_ADDR     = 4'd3,
        DATA         = 4'd4,
        ACK_DATA     = 4'd5,
        STOP_SETUP   = 4'd6,
        STOP_HIGH    = 4'd7,
        STOP_RELEASE = 4'd8,
        FINISH       = 4'd9;

    reg [3:0] state;

    // =========================================================
    // Clock divider
    // One FSM step occurs every CLK_DIV input clock cycles.
    // =========================================================
    reg [31:0] div_count;

    wire tick = (div_count == CLK_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_count <= 32'd0;
        end else if (!ena || tick) begin
            div_count <= 32'd0;
        end else begin
            div_count <= div_count + 1'b1;
        end
    end

    // =========================================================
    // Registers and signals
    // =========================================================
    reg [6:0] address;
    reg [7:0] data;
    reg [3:0] bit_count;

    reg scl;
    reg sda_low;

    reg done;
    reg error;
    reg busy;

    // sda_low = 1: pull SDA low
    // sda_low = 0: release SDA
    //
    // External pull-up resistor is required for an open-drain SDA bus.

    // =========================================================
    // I2C Master FSM
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            scl       <= 1'b1;
            sda_low   <= 1'b0;

            done      <= 1'b0;
            error     <= 1'b0;
            busy      <= 1'b0;

            address   <= 7'd0;
            data      <= 8'd0;
            bit_count <= 4'd0;

        end else if (!ena) begin
            state     <= IDLE;
            scl       <= 1'b1;
            sda_low   <= 1'b0;

            done      <= 1'b0;
            error     <= 1'b0;
            busy      <= 1'b0;

            bit_count <= 4'd0;

        end else if (tick) begin

            case (state)

                // -------------------------------------------------
                // IDLE: wait for start request
                // -------------------------------------------------
                IDLE: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b0;
                    done    <= 1'b0;
                    error   <= 1'b0;
                    busy    <= 1'b0;

                    if (ui_in[7]) begin
                        address   <= ui_in[6:0];
                        data      <= uio_in;
                        bit_count <= 4'd0;

                        busy  <= 1'b1;
                        state <= START;
                    end
                end

                // -------------------------------------------------
                // START: SDA falls while SCL is high
                // -------------------------------------------------
                START: begin
                    scl       <= 1'b1;
                    sda_low   <= 1'b1;
                    bit_count <= 4'd0;
                    state     <= ADDR;
                end

                // -------------------------------------------------
                // ADDR: transmit 7-bit address, MSB first
                // This version retains the existing address phase.
                // -------------------------------------------------
                ADDR: begin
                    scl <= 1'b0;

                    if (bit_count < 7)
                        sda_low <= ~address[6-bit_count];
                    else
                        sda_low <= 1'b1;

                    if (bit_count == 7) begin
                        state <= ACK_ADDR;
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                // -------------------------------------------------
                // ACK_ADDR: release SDA and sample the slave input
                // -------------------------------------------------
                ACK_ADDR: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b0;

                    if (uio_in[0] == 1'b0) begin
                        bit_count <= 4'd0;
                        state     <= DATA;
                    end else begin
                        error <= 1'b1;
                        state <= STOP_SETUP;
                    end
                end

                // -------------------------------------------------
                // DATA: transmit 8-bit data, MSB first
                // -------------------------------------------------
                DATA: begin
                    scl     <= 1'b0;
                    sda_low <= ~data[7-bit_count];

                    if (bit_count == 7) begin
                        state <= ACK_DATA;
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                // -------------------------------------------------
                // ACK_DATA: release SDA and sample ACK/NACK
                // -------------------------------------------------
                ACK_DATA: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b0;

                    if (uio_in[0] != 1'b0)
                        error <= 1'b1;

                    state <= STOP_SETUP;
                end

                // -------------------------------------------------
                // STOP_SETUP:
                // Pull SDA low while SCL is low.
                // -------------------------------------------------
                STOP_SETUP: begin
                    scl     <= 1'b0;
                    sda_low <= 1'b1;
                    state   <= STOP_HIGH;
                end

                // -------------------------------------------------
                // STOP_HIGH:
                // Raise SCL while keeping SDA low.
                // -------------------------------------------------
                STOP_HIGH: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b1;
                    state   <= STOP_RELEASE;
                end

                // -------------------------------------------------
                // STOP_RELEASE:
                // Release SDA only after SCL has been high
                // for one FSM interval, producing the STOP edge.
                // -------------------------------------------------
                STOP_RELEASE: begin
                    scl     <= 1'b1;
                    sda_low <= 1'b0;

                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= FINISH;
                end

                // -------------------------------------------------
                // FINISH: wait until start request is deasserted
                // -------------------------------------------------
                FINISH: begin
                    scl <= 1'b1;
                    sda_low <= 1'b0;
                    done <= 1'b1;
                    busy <= 1'b0;

                    if (!ui_in[7]) begin
                        state <= IDLE;
                    end
                 end

                // -------------------------------------------------
                // Default recovery
                // -------------------------------------------------
                default: begin
                    state     <= IDLE;
                    scl       <= 1'b1;
                    sda_low   <= 1'b0;
                    done      <= 1'b0;
                    error     <= 1'b0;
                    busy      <= 1'b0;
                    bit_count <= 4'd0;
                end

            endcase
        end
    end

    // =========================================================
    // Tiny Tapeout output mapping
    // =========================================================
    assign uo_out[0]   = scl;
    assign uo_out[1]   = 1'b0;
    assign uo_out[2]   = done;
    assign uo_out[3]   = error;
    assign uo_out[4]   = busy;
    assign uo_out[7:5] = 3'b000;

    // SDA is open-drain:
    // uio_oe[0] = 1 means this design drives SDA low.
    // uio_oe[0] = 0 means this design releases SDA.
    assign uio_out = 8'b00000000;
    assign uio_oe  = {7'b0000000, sda_low};

endmodule

`default_nettype wire
