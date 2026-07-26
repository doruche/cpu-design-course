    .option norvc
    .section .text.start
    .globl _start

_start:
    # Ordinary memory: a write-through store followed by a DCache refill and
    # load hit. The testbench checks both the value and the four-beat refill.
    li      s0, 0x00002000
    li      t0, 0x11223344
    sw      t0, 0(s0)
    sw      zero, 4(s0)
    sw      zero, 8(s0)
    sw      zero, 12(s0)
    lw      t1, 0(s0)
    bne     t0, t1, fail
    sw      t1, 4(s0)

    # Switch input and LED output.
    li      s1, 0xffff0000
    lw      t0, 0(s1)
    sw      t0, 8(s0)
    li      s1, 0xffff1000
    sw      t0, 0(s1)

    # Eight-digit hexadecimal display.
    li      s1, 0xffff2000
    li      t0, 0x12345678
    sw      t0, 0(s1)

    # Capture an early timer value.
    li      s2, 0xffff4000
    lw      t0, 0(s2)
    sw      t0, 12(s0)

    # Wait for one complete testbench-provided UART RX frame, consume it, and
    # transmit a deliberately different byte.
    li      s1, 0xffff3000
wait_rx:
    lw      t0, 8(s1)
    andi    t1, t0, 1
    beq     t1, zero, wait_rx
    lw      t0, 0(s1)
    sw      t0, 16(s0)
    li      t1, 0x3c
    bne     t0, t1, fail
    li      t0, 0xa5
    sw      t0, 4(s1)

    # Capture a later low word and the timer high word. The testbench checks
    # their relationship instead of assuming an atomic 64-bit snapshot.
    lw      t0, 0(s2)
    sw      t0, 20(s0)
    lw      t0, 8(s2)
    sw      t0, 24(s0)

    li      t0, 0x600d600d
    sw      t0, 32(s0)
pass_loop:
    jal     zero, pass_loop

fail:
    li      t0, 0xdeaddead
    sw      t0, 32(s0)
fail_loop:
    jal     zero, fail_loop
