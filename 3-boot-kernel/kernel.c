
void kmain(void) {
    // VGA text memory
    volatile unsigned short *screen =
        (volatile unsigned short *)0xB8000;

    const char *message = "Hello from C kernel!";

    // Write characters directly to video memory
    for (int i = 0; message[i] != '\0'; i++) {
        screen[i] = 0x0F00 | (unsigned char)message[i];
    }

    // Stop the CPU
    for (;;) {
        __asm__ volatile ("hlt");
    }
}
