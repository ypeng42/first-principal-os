nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin

# Create a 1.44 MB floppy disk image
dd if=/dev/zero of=os.img bs=1024 count=1440

# Write Stage 1 to the first sector
dd if=boot.bin of=os.img conv=notrunc

# Write Stage 2 to the second sector
dd if=stage2.bin of=os.img bs=512 seek=1 conv=notrunc

# Boot the virtual PC
qemu-system-i386 -drive file=os.img,format=raw,if=floppy -boot a