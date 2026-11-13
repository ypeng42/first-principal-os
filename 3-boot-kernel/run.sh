#!/usr/bin/env bash
set -euo pipefail

# Build Stage 1 and Stage 2
nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin

# Use the Homebrew LLVM toolchain
CLANG="$(brew --prefix llvm)/bin/clang"
LINKER="$(brew --prefix lld)/bin/ld.lld"

# Compile C into 32-bit x86 object code
"$CLANG" --target=i386-none-elf -m32 \
  -ffreestanding -fno-stack-protector \
  -fno-pic -fno-pie \
  -fno-asynchronous-unwind-tables \
  -O0 -c kernel.c -o kernel.o

# Link the kernel at address 0x10000
"$LINKER" -m elf_i386 \
  --image-base=0x10000 \
  -Ttext 0x10000 \
  --oformat=binary \
  -o kernel.bin kernel.o

# Verify kernel size is at most 512 bytes
wc -c kernel.bin


# Create a 1.44 MB disk image
dd if=/dev/zero of=os.img bs=512 count=2880

# Place each program into its sector
dd if=boot.bin of=os.img bs=512 seek=0 conv=notrunc
dd if=stage2.bin of=os.img bs=512 seek=1 conv=notrunc
dd if=kernel.bin of=os.img bs=512 seek=2 conv=notrunc

# Boot our OS
qemu-system-i386 -drive file=os.img,format=raw,if=floppy -boot a