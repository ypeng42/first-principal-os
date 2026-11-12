# Why Do We Need Boot Stages?

## Two Fundamental Questions

1. **Why Stage 1 → Stage 2 → Kernel?** Why not simply call `load_kernel()` and load everything at once?
2. **Why does BIOS initially load only a 512-byte boot sector?** Why so little? Why not load 4 KB, 64 KB, or even 1 MB?

These questions reveal three fundamental concepts in system design:

- **Physical Constraints** — What hardware can actually do.
- **Interface Contracts** — What different components agree to do.
- **Design Choices** — How engineers choose to implement a solution.

The most important principle:

> **Understand why a system is designed a certain way, rather than assuming that a historical implementation is the only possible design.**

---

# Part 1 — Why Stage 1 → Stage 2 → Kernel?

## 1. The Ideal World: Just `load_kernel()`

Imagine BIOS provides a simple API:

```text
BIOS.load_kernel()
```

How convenient!

```text
Power On
   ↓
BIOS
   ↓
Kernel
```

Why introduce Stage 1 and Stage 2 at all?

**The answer: We absolutely can load a Kernel directly. Stage 2 is not fundamentally required for booting an OS. It is an additional abstraction introduced when Stage 1 becomes insufficient.**

But first, there is a deeper question:

**How does BIOS know what a Kernel is?**

Imagine you are designing BIOS.

Your users might install:

- Windows
- Linux
- FreeBSD
- A custom operating system

Their Kernels might have different:

- Disk locations
- File systems
- Executable formats
- Memory requirements
- Boot protocols

BIOS cannot assume that every OS stores its Kernel in the same place or uses the same loading procedure.

This leads to two possible designs.

### Option A: BIOS understands every OS

BIOS would need to understand different file systems, Kernel formats, loading protocols, and potentially future operating systems.

This creates an enormous amount of complexity and compatibility work inside the firmware.

### Option B: BIOS provides minimal bootstrapping capabilities

BIOS only needs to find an initial boot program, load it, and execute it.

The boot program is then responsible for determining how to load the actual OS.

**Traditional BIOS booting follows Option B.**

This is a fundamental systems-design principle:

> **Lower layers provide general-purpose primitives. Higher layers combine these primitives to solve specific problems.**

BIOS does not need to understand Linux, Windows, or our custom OS.

It only needs to provide a sufficiently simple and stable mechanism for starting another program.

## 2. Why Do We Need Stage 2?

Because traditional BIOS initially loads only one 512-byte boot sector.

Suppose our Kernel is extremely small.

We could use:

```text
BIOS
  ↓
Stage 1
  ↓  Read 10 sectors
Kernel
```

This is perfectly valid!

If Stage 1 knows:

- Where the Kernel is stored on disk
- How many sectors it occupies
- Where to place it in RAM
- How to transfer execution to it

Then Stage 1 can load the Kernel directly using BIOS disk services.

**No Stage 2 required.**

But now imagine our Kernel becomes several megabytes and is stored inside a real file system.

The bootloader may need to:

1. Understand the file system to locate `kernel.bin`.
2. Read multiple disk regions.
3. Understand the memory layout and avoid reserved regions.
4. Prepare the CPU execution mode.
5. Load the Kernel and pass the necessary boot information.

Implementing all these capabilities in 512 bytes becomes extremely difficult.

So we introduce a simple solution:

> **Use a small program to load a more capable program, which then loads the real operating system.**

That gives us:

```text
BIOS
  ↓
Stage 1
  ↓
Stage 2
  ↓
Kernel
```

Stage 1 only needs to know how to load Stage 2.

Stage 2 has more space and can implement sophisticated loading mechanisms.

**Stage 2 exists because it solves a problem, not because every OS must have two bootloader stages.**

## 3. Single-Stage vs. Two-Stage Bootloader

### Single-Stage

```text
BIOS
  ↓
Stage 1
  │
  │ Load Kernel
  ↓
Kernel
```

Advantages:

- Simple architecture
- Fewer components
- Easy to understand
- Excellent for small experimental operating systems

Limitation:

- Stage 1 must fit within the available boot-sector space and handle the necessary loading work.

### Two-Stage

```text
BIOS
  ↓
Stage 1
  │
  │ Load Stage 2
  ↓
Stage 2
  │
  │ Prepare system
  │ Load Kernel
  ↓
Kernel
```

Advantages:

- More room for sophisticated loading code
- File system support
- More flexible memory management
- Ability to load larger or more complex Kernels

Tradeoff:

- Additional components and coordination

Neither architecture is universally superior.

**Choose the simplest design that solves the current problem.**

## 4. The Deeper Concept: Bootstrapping

This is an example of a fundamental concept in computer science:

**Bootstrapping — using a small system that already works to construct or start a more capable system.**

```text
A small program
      ↓ loads
A more capable program
      ↓ loads
A full operating system
```

We do not introduce layers simply because layered architectures look elegant.

We introduce them when the existing system reaches a limitation.

The natural progression is:

**Existing Primitive → New Problem → New Abstraction**

For our custom QEMU OS, we should probably begin with:

```text
BIOS → Stage 1 → Tiny C Kernel
```

Only introduce Stage 2 when we actually encounter a problem that justifies it.

This way, we discover the need for the abstraction ourselves rather than blindly following a tutorial.

---

# Part 2 — Why Does BIOS Initially Load Only 512 Bytes?

## 1. The Historical Context

Let's go back to the original IBM PC era in 1981.

Early PCs commonly booted from floppy disks.

The IBM PC's floppy disk format used sectors containing 512 bytes.

A natural boot design was:

> **BIOS reads the first sector of the boot disk, loads it into memory, and executes its code.**

The process is extremely simple:

```text
1. Find boot device
2. Read first sector (512 bytes)
3. Jump to the loaded code
```

BIOS does not need to know:

- Which operating system is installed
- How large the operating system is
- Where its Kernel is stored
- How the Kernel should be loaded

This minimizes the amount of OS-specific knowledge required in firmware.

The 512-byte convention comes from the historical disk-sector format and the corresponding boot protocol.

**It is not a fundamental limit on how much data a CPU or BIOS can process.**

## 2. Why Not Load 4 KB, 64 KB, or 1 MB?

Technically, a different boot protocol could absolutely specify a larger initial load.

Imagine we are designing BIOS.

You propose:

> "Why not load 64 KB instead of 512 bytes?"

A natural question is:

**Why 64 KB?**

Consider three operating systems:

| OS | Initial code size | Is 64 KB sufficient? |
|---|---|---|
| OS A | 10 KB | Yes, but more than necessary |
| OS B | 100 KB | No |
| OS C | 10 MB | Definitely not |

Regardless of the fixed size we choose, some programs will eventually need more.

Furthermore, BIOS does not necessarily know what the additional sectors contain.

They might contain:

- Additional bootloader code
- File system metadata
- Ordinary files
- Other disk data

Loading more sectors blindly does not automatically solve the problem of finding the Kernel.

So we can establish a more flexible contract:

> **BIOS loads enough code to start a small program. That program can request additional data as needed.**

This provides a clean separation of responsibilities.

BIOS provides the initial execution environment and basic disk services.

The bootloader decides what additional data is required.

## 3. Does BIOS Really Only Read 512 Bytes?

This is where we must distinguish two completely different operations.

### Initial Boot Load

For the traditional boot-sector path, BIOS automatically loads the first 512-byte sector.

### BIOS Disk Service

Once our bootloader is running, it can invoke BIOS disk services to load additional sectors.

For example, with the traditional BIOS interface:

```asm
mov ah, 0x02
int 0x13
```

Here, `AH = 0x02` selects the sector-reading operation. Other CPU registers specify the disk, location, sector count, and destination in memory.

Conceptually:

```text
BIOS: Here's your first 512 bytes.

Bootloader: Thanks! Read 20 more sectors.

BIOS: Done.

Bootloader: Now read another 20.

BIOS: Done.
```

Real BIOS calls have limits on how much data can be transferred in one operation, so larger reads may need to be split up.

But the important distinction is:

**512 bytes is the size of the initial automatic boot-sector load, not the maximum amount of data BIOS can read.**

## 4. Could We Design a Better Boot Protocol?

Absolutely.

Suppose we are designing a new computer today.

We could define:

```text
Firmware:
    Read the first 4096 bytes
    Jump to bootloader
```

This would give the bootloader 4 KB of initial space instead of 512 bytes.

Or we could define an even more convenient interface:

```text
Firmware:
    Locate the bootloader executable
    Load the entire executable into RAM
    Execute it
```

This eliminates the traditional 512-byte boot-sector restriction.

In fact, modern **UEFI** provides a mechanism much closer to this second design.

UEFI can locate and load EFI executable images, typically from an EFI System Partition.

Instead of forcing the initial boot program into a single 512-byte sector, firmware can load an executable file.

That executable may be an OS loader rather than the Kernel itself.

### Legacy BIOS vs. UEFI

| | Legacy BIOS | UEFI |
|---|---|---|
| Typical boot program | Boot sector | `.efi` executable |
| Initial loading | Conventional boot sector | EFI image loading |
| 512-byte initial boot-sector limit | Yes, for this boot path | No |
| Traditional `55 AA` boot signature | Required for the boot sector | Not required for the EFI executable itself |
| Fixed boot-sector load address `0x7C00` | Yes | No |

UEFI demonstrates that **the 512-byte boot-sector model is a historical interface choice, not a universal requirement of computer architecture.**

## 5. Then Why Did Legacy BIOS Keep the Old Design?

**Backward compatibility.**

Once hardware manufacturers, operating systems, bootloaders, and development tools have been built around a shared interface, changing that interface becomes expensive.

A change can break existing software even when the new design seems objectively more convenient.

This is a recurring phenomenon in computer systems:

> **An early engineering decision can become a long-lived standard because an entire ecosystem depends on it.**

A historical design is not necessarily the optimal design for modern hardware.

Sometimes it survives because maintaining compatibility is more valuable than redesigning everything.

---

# Part 3 — Three Different Types of Constraints

This discussion reveals a critical distinction that we should carry into the rest of our OS development journey.

## 1. Physical Constraint

Something the hardware genuinely cannot do.

Example:

If a computer only has 64 KB of usable RAM, it cannot simultaneously store a 1 MB program entirely in that RAM.

This is a real resource limitation.

## 2. Interface Contract

Something two components have agreed upon.

Example:

Traditional BIOS initially loads a 512-byte boot sector into memory at physical address `0x7C00` and expects the boot signature `55 AA` at the end of the sector.

These are rules of a particular boot interface.

They are not laws of nature.

A different firmware interface may use completely different conventions.

## 3. Design Choice

Something engineers choose while implementing a solution.

Example:

We can implement:

```text
BIOS → Stage 1 → Kernel
```

Or:

```text
BIOS → Stage 1 → Stage 2 → Kernel
```

Both are valid.

Which one makes sense depends on the requirements and constraints of our system.

## Why This Distinction Matters

When we encounter a strange number, an apparently unnecessary step, or a complicated design, we should ask:

**Is this a physical limitation, an interface contract, or simply an implementation choice?**

The answer tells us whether we must accept the constraint, follow an established protocol, or consider a simpler alternative.