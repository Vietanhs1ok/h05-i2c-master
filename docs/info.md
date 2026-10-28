## How it works

The I2C Master module communicates with an I2C slave device using the Serial Clock (SCL) and Serial Data (SDA) signals.

The module receives a start request and a 7-bit slave address through the input interface. It then generates the I2C start condition, transmits the address and data bits, and checks the slave's ACK or NACK response.

A finite-state machine controls the communication sequence, while a clock divider determines the timing of the SCL signal. The module provides status outputs to indicate whether a transaction is busy, completed, or has encountered an error.

The SDA interface uses an open-drain-style output: the master pulls SDA low when transmitting a zero and releases the line when it needs the line to be high. An external pull-up resistor is required on the I2C SDA line.

## How to test

The design can be tested using the Cocotb testbench and the TinyTapeout Gate-Level (GL) test flow.

The testbench resets the design, starts an I2C transaction, supplies the simulated slave ACK or NACK response, and checks the status outputs.

The test cases cover:
- A transaction with an ACK response.
- A transaction using address `0x00`.
- A transaction using address `0x7F`.
- A transaction with a NACK response.

A successful test should confirm that the transaction completes, the BUSY signal is deasserted, and the ERROR signal reflects the ACK or NACK response.
