use crate::arch::uart::{uartinit, uartputc};


#[no_mangle]
static mut stack0: [u8; 4096 * crate::param::NCPU] = [0; 4096 * crate::param::NCPU];


static HELLO: &[u8] = b"Hello, world!";

#[no_mangle]
pub unsafe extern "C" fn start() -> ! {
    uartinit();
    for c in HELLO {
        uartputc(*c);
    } 
    loop {}
}