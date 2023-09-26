# xv6-rs
## Prerequirements
### Debian/Ubuntu
1. intall rust 
```curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh```

2. install riscv tool-chains 
```sudo apt-get install git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu ```

3. add target for bare metal risc-v 
```rustup target add riscv64gc-unknown-none-elf```

## Reference
[The embedonomicon](https://docs.rust-embedded.org/embedonomicon/memory-layout.html)