#![allow(dead_code, unused_variables)]

use core::ptr::{read_volatile, write_volatile};

use super::memlayout::*;

const RHR: usize = 0; // receive holding register (for input bytes)
const THR: usize = 0; // transmit holding register (for output bytes)
const IER: usize = 1; // interrupt enable register
const IER_RX_ENABLE: u8 = 1 << 0;
const IER_TX_ENABLE: u8 = 1 << 1;
const FCR: usize = 2; // FIFO control register
const FCR_FIFO_ENABLE: u8 = 1 << 0;
const FCR_FIFO_CLEAR: u8 = 3 << 1; // clear the content of the two FIFOs
const ISR: usize = 2; // interrupt status register
const LCR: usize = 3; // line control register
const LCR_EIGHT_BITS: u8 = 3 << 0;
const LCR_BAUD_LATCH: u8 = 1 << 7; // special mode to set baud rate
const LSR: usize = 5; // line status register
const LSR_RX_READY: usize = 1 << 0; // input is waiting to be read from RHR
const LSR_TX_IDLE: u8 = 1 << 5; // THR can accept another character to send

unsafe fn write_reg(reg: usize, val: u8) {
    let dst = (reg + UART0) as *mut u8;
    write_volatile(dst, val);
}

unsafe fn read_reg(reg: usize) -> u8 {
    let dst = (reg + UART0) as *const u8;
    read_volatile(dst)
}

pub unsafe fn uartinit() {
    // disable interrupts.
    write_reg(IER, 0x00);

    // special mode to set baud rate.
    write_reg(LCR, LCR_BAUD_LATCH);

    // LSB for baud rate of 38.4K.
    write_reg(0, 0x03);

    // MSB for baud rate of 38.4K.
    write_reg(1, 0x00);

    // leave set-baud mode,
    // and set word length to 8 bits, no parity.
    write_reg(LCR, LCR_EIGHT_BITS);

    // reset and enable FIFOs.
    write_reg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);

    // enable transmit and receive interrupts.
    write_reg(IER, IER_TX_ENABLE | IER_RX_ENABLE);
}

pub unsafe fn uartputc(c: u8) {
    while read_reg(LSR) & LSR_TX_IDLE == 0 {}
    write_reg(THR, c);
}

pub unsafe fn uartgetc() -> u8 {
    loop {
        if read_reg(LSR) & 0x01 != 0 {
            // input data is ready.
            return read_reg(RHR);
        }
    }
}
