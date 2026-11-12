# Lesson 1: Hello World — Understanding Conventions

## 1. The Big Idea: Conventions Are Everywhere

When building an OS from scratch, one of the first things to understand is **conventions (contracts between components)**.

A convention is an agreed-upon rule that different components follow so they can work together.

These rules are not universal laws. They are defined by a particular system or interface.

**The key is not to memorize every rule, but to understand who defines it and who must follow it.**

## 2. BIOS: Our First Example

When we start a virtual x86 computer using QEMU, it uses **SeaBIOS** as its default legacy BIOS firmware.

SeaBIOS is responsible for finding and loading our boot program.

To boot successfully, our program must follow the legacy BIOS boot conventions:

| Convention | Meaning |
|---|---|
| 512 bytes | The traditional boot sector is 512 bytes long. |
| `55 AA` | The boot signature must appear at byte offsets 510–511. |
| `0x7C00` | BIOS loads the boot sector at this memory address. |

These are conventions of the legacy BIOS boot process, **not universal rules for all computers or operating systems**.

## 3. Who Chooses the Rules?

Our bootloader does not choose how BIOS works.

The boot sequence is:

```text
QEMU (virtual hardware)
    ↓
SeaBIOS (firmware)
    ↓
Bootloader (our code)
    ↓
OS Kernel (future)
```

QEMU provides the virtual computer and its firmware.

SeaBIOS runs first and decides how to load our bootloader.

**We follow BIOS conventions because BIOS is already in control of the boot process — not because following those conventions causes QEMU to select BIOS.**

## 4. The Most Important Takeaway

When encountering unfamiliar code or a mysterious constant, ask:

1. **Who defines this rule?**
2. **Who must follow it?**
3. **What happens if we break it?**

We don't need to memorize all the magic numbers.

We need to understand **the contracts between components**.

**Mental Model: An operating system is built by connecting components that interact through well-defined interfaces and conventions.**