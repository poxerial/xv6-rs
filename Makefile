# This file is based on the Makefile of xv6-labs-2023.


# riscv64-unknown-elf- or riscv64-linux-gnu-
# perhaps in /opt/riscv/bin
#TOOLPREFIX = 

K = kernel
U = user

ifndef TOOLPREFIX
TOOLPREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

QEMU = qemu-system-riscv64

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

CFLAGS = -Wall -Werror -O -fno-omit-frame-pointer -ggdb -gdwarf-2

CFLAGS += $(XCFLAGS)
CFLAGS += -MD
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -I.
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

LDFLAGS = -z max-page-size=4096

KERNEL_SRC = $(shell find ./$K -name *.rs)
TARGET = riscv64gc-unknown-none-elf
KERNEL_BIN_PATH = $K/target/$(TARGET)/debug
KERNEL_BIN = $(KERNEL_BIN_PATH)/$K


$(KERNEL_BIN): $(KERNEL_SRC) $K/kernel.ld # $U/initcode
	cd $K && cargo clean && cargo rustc --target $(TARGET) -- -C linker=$(TOOLPREFIX)ld -C link-args='$(LDFLAGS) -T $(shell pwd)/$K/kernel.ld'
	$(OBJDUMP) -S $(KERNEL_BIN) > $(KERNEL_BIN_PATH)/kernel.asm
	$(OBJDUMP) -t $(KERNEL_BIN) | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(KERNEL_BIN_PATH)/kernel.sym

$U/initcode: $U/initcode.S
	$(CC) $(CFLAGS) -march=rv64g -nostdinc -I. -Ikernel -c $U/initcode.S -o $U/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $U/initcode.out $U/initcode.o
	$(OBJCOPY) -S -O binary $U/initcode.out $U/initcode
	$(OBJDUMP) -S $U/initcode.o > $U/initcode.asm

tags: $(OBJS) _init
	etags *.S *.c

ULIB = $U/ulib.o $U/usys.o $U/printf.o $U/umalloc.o

ifeq ($(LAB),$(filter $(LAB), lock))
ULIB += $U/statistics.o
endif

_%: %.o $(ULIB)
	$(LD) $(LDFLAGS) -T $U/user.ld -o $@ $^
	$(OBJDUMP) -S $@ > $*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

$U/usys.S : $U/usys.pl
	perl $U/usys.pl > $U/usys.S

$U/usys.o : $U/usys.S
	$(CC) $(CFLAGS) -c -o $U/usys.o $U/usys.S

$U/_forktest: $U/forktest.o $(ULIB)
	# forktest has less library code linked in - needs to be small
	# in order to be able to max out the proc table.
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $U/_forktest $U/forktest.o $U/ulib.o $U/usys.o
	$(OBJDUMP) -S $U/_forktest > $U/forktest.asm

mkfs/mkfs: mkfs/mkfs.c $K/fs.h $K/param.h
	gcc $(XCFLAGS) -Werror -Wall -I. -o mkfs/mkfs mkfs/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: %.o

UPROGS=\
	$U/_cat\
	$U/_echo\
	$U/_forktest\
	$U/_grep\
	$U/_init\
	$U/_kill\
	$U/_ln\
	$U/_ls\
	$U/_mkdir\
	$U/_rm\
	$U/_sh\
	$U/_stressfs\
	$U/_usertests\
	$U/_grind\
	$U/_wc\
	$U/_zombie\




ifeq ($(LAB),$(filter $(LAB), lock))
UPROGS += \
	$U/_stats
endif

ifeq ($(LAB),traps)
UPROGS += \
	$U/_call\
	$U/_bttest
endif

ifeq ($(LAB),lazy)
UPROGS += \
	$U/_lazytests
endif

ifeq ($(LAB),cow)
UPROGS += \
	$U/_cowtest
endif

ifeq ($(LAB),thread)
UPROGS += \
	$U/_uthread

$U/uthread_switch.o : $U/uthread_switch.S
	$(CC) $(CFLAGS) -c -o $U/uthread_switch.o $U/uthread_switch.S

$U/_uthread: $U/uthread.o $U/uthread_switch.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $U/_uthread $U/uthread.o $U/uthread_switch.o $(ULIB)
	$(OBJDUMP) -S $U/_uthread > $U/uthread.asm

ph: notxv6/ph.c
	gcc -o ph -g -O2 $(XCFLAGS) notxv6/ph.c -pthread

barrier: notxv6/barrier.c
	gcc -o barrier -g -O2 $(XCFLAGS) notxv6/barrier.c -pthread
endif

ifeq ($(LAB),pgtbl)
UPROGS += \
	$U/_pgtbltest
endif

ifeq ($(LAB),lock)
UPROGS += \
	$U/_kalloctest\
	$U/_bcachetest
endif

ifeq ($(LAB),fs)
UPROGS += \
	$U/_bigfile
endif



ifeq ($(LAB),net)
UPROGS += \
	$U/_nettests
endif

UEXTRA=
ifeq ($(LAB),util)
	UEXTRA += user/xargstest.sh
endif


fs.img: mkfs/mkfs README $(UEXTRA) $(UPROGS)
	mkfs/mkfs fs.img README $(UEXTRA) $(UPROGS)

-include kernel/*.d user/*.d

clean: 
	rm -f *.tex *.dvi *.idx *.aux *.log *.ind *.ilg \
	*/*.o */*.d */*.asm */*.sym \
	$U/initcode $U/initcode.out $K/kernel fs.img \
	mkfs/mkfs .gdbinit \
        $U/usys.S \
	$(UPROGS) \
	ph barrier

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 1
endif
ifeq ($(LAB),fs)
CPUS := 1
endif

FWDPORT = $(shell expr `id -u` % 5000 + 25999)

QEMUOPTS = -machine virt -bios none -kernel $(KERNEL_BIN) -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -global virtio-mmio.force-legacy=false
QEMUOPTS += -drive file=fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

qemu: $(KERNEL_BIN) #fs.img
	$(QEMU) $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

qemu-gdb: $(KERNEL_BIN) .gdbinit #fs.img
	@echo "*** Now run 'gdb' in another window." 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

ifeq ($(LAB),net)
# try to generate a unique port for the echo server
SERVERPORT = $(shell expr `id -u` % 5000 + 25099)

server:
	python3 server.py $(SERVERPORT)

ping:
	python3 ping.py $(FWDPORT)
endif

##
##  FOR testing lab grading script
##

ifneq ($(V),@)
GRADEFLAGS += -v
endif

print-gdbport:
	@echo $(GDBPORT)

grade:
	@echo $(MAKE) clean
	@$(MAKE) clean || \
          (echo "'make clean' failed.  HINT: Do you have another running instance of xv6?" && exit 1)
	./grade-lab-$(LAB) $(GRADEFLAGS)

##
## FOR submissions
##

submit-check:
	@if ! test -d .git; then \
		echo No .git directory, is this a git repository?; \
		false; \
	fi
	@if test "$$(git symbolic-ref HEAD)" != refs/heads/$(LAB); then \
		git branch; \
		read -p "You are not on the $(LAB) branch.  Hand-in the current branch? [y/N] " r; \
		test "$$r" = y; \
	fi
	@if ! git diff-files --quiet || ! git diff-index --quiet --cached HEAD; then \
		git status -s; \
		echo; \
		echo "You have uncomitted changes.  Please commit or stash them."; \
		false; \
	fi
	@if test -n "`git status -s`"; then \
		git status -s; \
		read -p "Untracked files will not be handed in.  Continue? [y/N] " r; \
		test "$$r" = y; \
	fi

zipball: submit-check
	git archive --format=zip --output lab.zip HEAD

.PHONY: zipball clean grade submit-check


#LC_ALL="C" PATH="/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/bin:/home/poxerial/.local/bin:/home/poxerial/.cargo/bin:/home/poxerial/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:/usr/local/go/bin:/usr/local/go/bin" VSLANG="1033" "riscv64-linux-gnu-ld" "/tmp/rustcoi8tqi/symbols.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.17t0d3t5rl9d4klo.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.2epvc8yirayy3qd7.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.2ol0f1dcda9c3y2f.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.5a8rjmtg5k3vazpf.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.ua6ld8oaa3jvpyd.rcgu.o" "--as-needed" "-L" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps" "-L" "/home/poxerial/repos/xv6-rs/kernel/target/debug/deps" "-L" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib" "-Bstatic" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib/librustc_std_workspace_core-3cc102c0d4b27bb1.rlib" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib/libcore-17c40695a24c32df.rlib" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib/libcompiler_builtins-c289d2ec413f9926.rlib" "-Bdynamic" "-z" "noexecstack" "-L" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib" "-o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855" "--gc-sections" "-z" "max-page-size=4096" "-T" "/home/poxerial/repos/xv6-rs/kernel/kernel.ld"
#"riscv64-linux-gnu-ld" "/tmp/rustcoi8tqi/symbols.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.17t0d3t5rl9d4klo.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.2epvc8yirayy3qd7.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.2ol0f1dcda9c3y2f.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.5a8rjmtg5k3vazpf.rcgu.o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855.ua6ld8oaa3jvpyd.rcgu.o" "--as-needed" "-L" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps" "-L" "/home/poxerial/repos/xv6-rs/kernel/target/debug/deps" "-L" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib" "-Bstatic" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib/librustc_std_workspace_core-3cc102c0d4b27bb1.rlib" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib/libcore-17c40695a24c32df.rlib" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib/libcompiler_builtins-c289d2ec413f9926.rlib" "-Bdynamic" "-z" "noexecstack" "-L" "/home/poxerial/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/riscv64gc-unknown-none-elf/lib" "-o" "/home/poxerial/repos/xv6-rs/kernel/target/riscv64gc-unknown-none-elf/debug/deps/kernel-3ffed6a84526a855" "--gc-sections" "-z" "max-page-size=4096" "-T" "/home/poxerial/repos/xv6-rs/kernel/kernel.ld"