
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def reset_dut(dut):
    """Reset the DUT and initialize all inputs."""

    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)


async def start_transaction(dut, address, data, ack_value=0):
    """Start an I2C transaction and simulate the slave ACK/NACK."""

    # ui_in[7] = START request
    # ui_in[6:0] = 7-bit I2C address
    dut.ui_in.value = (1 << 7) | (address & 0x7F)

    # Supply the data byte.
    dut.uio_in.value = data & 0xFF

    # Wait until the DUT enters BUSY state.
    for _ in range(500):
        await ClockCycles(dut.clk, 1)

        raw_output = str(dut.uo_out.value)

        if any(bit not in "01" for bit in raw_output):
            assert False, (
                f"uo_out contains X/Z: {raw_output}"
            )

        output = int(raw_output, 2)

        if output & 0x10:
            break
    else:
        raw_output = str(dut.uo_out.value)
        assert False, (
            "I2C Master did not enter BUSY state. "
            f"uo_out={raw_output}"
        )

    # uio_in[0] = 0 simulates ACK.
    # uio_in[0] = 1 simulates NACK.
    dut.uio_in.value = ack_value & 1
async def finish_transaction(dut):
    """Wait for DONE and release the START request."""

    for _ in range(10000):
        await ClockCycles(dut.clk, 1)

        raw_output = str(dut.uo_out.value)

        if any(bit not in "01" for bit in raw_output):
            assert False, f"uo_out contains X/Z: {raw_output}"

        output = int(raw_output, 2)

        # BUSY should be low after completion.
        assert not (output & 0x10), (
            f"BUSY should be low after transaction, "
            f"uo_out=0x{output:02X}"
        )

        if output & 0x04:
            break
    else:
        assert False, "I2C Master did not finish transaction"
    
    # Release START request.
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)
@cocotb.test()
async def test_i2c_ack(dut):
    """Test a transaction with ACK."""

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="us").start()
    )

    await reset_dut(dut)

    await start_transaction(
        dut,
        address=0x50,
        data=0xA5,
        ack_value=0
    )

    await finish_transaction(dut)

    output = int(dut.uo_out.value)

    assert output & 0x04, (
        f"DONE should remain asserted, uo_out=0x{output:02X}"
    )

    assert not (output & 0x08), (
        f"Unexpected ERROR during ACK transaction, "
        f"uo_out=0x{output:02X}"
    )

    dut._log.info("PASS: ACK transaction completed")


@cocotb.test()
async def test_i2c_address_zero(dut):
    """Test an I2C transaction using address 0x00."""

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="us").start()
    )

    await reset_dut(dut)

    await start_transaction(
        dut,
        address=0x00,
        data=0x55,
        ack_value=0
    )

    await finish_transaction(dut)

    output = int(dut.uo_out.value)

    assert output & 0x04, (
        f"DONE missing for address 0x00, "
        f"uo_out=0x{output:02X}"
    )

    assert not (output & 0x08), (
        f"Unexpected ERROR for address 0x00, "
        f"uo_out=0x{output:02X}"
    )

    dut._log.info("PASS: Address 0x00")

@cocotb.test()
async def test_i2c_address_max(dut):
    """Test an I2C transaction using address 0x7F."""

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="us").start()
    )

    await reset_dut(dut)

    await start_transaction(
        dut,
        address=0x7F,
        data=0xFF,
        ack_value=0
    )

    await finish_transaction(dut)

    output = int(dut.uo_out.value)

    assert output & 0x04, (
        f"DONE missing for address 0x7F, "
        f"uo_out=0x{output:02X}"
    )

    assert not (output & 0x08), (
        f"Unexpected ERROR for address 0x7F, "
        f"uo_out=0x{output:02X}"
    )

    dut._log.info("PASS: Address 0x7F")


@cocotb.test()
async def test_i2c_address_nack(dut):
    """Test a transaction where the slave returns NACK."""

    cocotb.start_soon(
        Clock(dut.clk, 10, unit="us").start()
    )

    await reset_dut(dut)

    await start_transaction(
        dut,
        address=0x50,
        data=0xA5,
        ack_value=1
    )

    await finish_transaction(dut)

    output = int(dut.uo_out.value)

    assert output & 0x04, (
        f"DONE missing after NACK, uo_out=0x{output:02X}"
    )

    assert output & 0x08, (
        f"ERROR should be asserted after NACK, "
        f"uo_out=0x{output:02X}"
    )

    dut._log.info("PASS: NACK detected correctly")
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

