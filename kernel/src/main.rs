#![no_main]
#![no_std]

use core::{arch::{asm, global_asm}, panic::PanicInfo};

use boot::start;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

pub mod arch;
pub mod boot;
pub mod param;

use arch::uart::{uartinit, uartputc};


global_asm!(
        "
        .section .text.entry
        .global _entry
        _entry:
            la sp, stack0
            li a0, 1024*4
            csrr a1, mhartid
            addi a1, a1, 1
            mul a0, a0, a1
            add sp, sp, a0
            call start"
);
