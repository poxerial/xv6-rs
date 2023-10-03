# xv6-rs
## Prerequirements
### 1. install rust 
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 2. add target for bare metal risc-v 
```
rustup target add riscv64gc-unknown-none-elf
```

### 3. install riscv tool-chains 
#### Debian/Ubuntu:
```
sudo apt-get install git build-essential gdb-multiarch qemu-system-misc gcc-riscv64-linux-gnu binutils-riscv64-linux-gnu 
```

#### MacOS:
* install developer tools: 
```
xcode-select --install
```
* install homebrew: 
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
* install riscv toolchain 
```
brew tap riscv/riscv
brew install riscv-tools
```
* add `/usr/local/opt/riscv-gnu-toolchain/bin` to `PATH`
* install qemu 
```
brew install qemu
```

## Build and run
run `make ` to compile the kernel, run `make qemu` to run the os in qemu.


## Reference
[The embedonomicon](https://docs.rust-embedded.org/embedonomicon/memory-layout.html)