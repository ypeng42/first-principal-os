# OS Memory: Code, Stack, Registers, and Stack Frames

## 1. The Big Picture

When an OS runs, three main hardware components work together:

| Component | Purpose |
|---|---|
| Disk | Stores programs persistently |
| RAM | Stores code and data while programs run |
| CPU | Fetches and executes instructions |

The basic execution flow:

```text
Disk
  |
  | Bootloader loads the kernel
  v
RAM
  |
  | CPU fetches instructions
  v
CPU
  |
  | Executes instructions
  | Reads and writes data
  v
Registers / RAM
```

**Key insight: Code and Stack are not separate hardware components. They are simply regions of RAM used for different purposes.**

## 2. Where Are Code and Stack?

A simplified memory layout for our QEMU OS:

```text
RAM (Illustrative Physical Addresses)

0x00000   BIOS / hardware data
              |
0x07C00   Stage 1 (Boot Sector)
              |
0x08000   Stage 2 (Bootloader)
              |
0x10000   Kernel Code + Data
              |
              | Available RAM
              |
0x70000   Initial Stack Top
              |
              | Other RAM
```

These addresses illustrate possible choices, not fixed hardware requirements, except for the BIOS boot-sector loading convention at `0x7C00`.

### Code

The bootloader loads machine instructions from disk into RAM.

The CPU then fetches and executes those instructions.

### Stack

The Stack is a region of RAM used for temporary execution state, especially function calls.

We can choose its location as long as:

- The memory is valid and writable.
- There is enough space.
- It does not overlap important memory regions.
- The Stack Pointer is initialized correctly.
- CPU addressing and alignment requirements are satisfied.

**The Stack is not a special piece of hardware. It is ordinary RAM used according to a particular convention.**

On x86, the Stack typically grows toward lower memory addresses.

## 3. Why Do We Need Registers and Stack?

Registers are small, fast storage locations inside the CPU.

| Registers | Stack |
|---|---|
| Inside CPU | In RAM |
| Very fast | Generally slower |
| Limited capacity | Larger, limited by available memory |
| Current calculations | Temporary execution state |

Example (32-bit x86):

```asm
mov eax, 10       ; Store 10 in EAX
mov ebx, 20       ; Store 20 in EBX
add eax, ebx      ; EAX = 30
push eax          ; Save 30 on the Stack
```

The arithmetic happens in CPU registers.

The Stack is only accessed when we execute `push`.

**Not every calculation needs the Stack. The CPU can perform many operations entirely using registers.**

## 4. Why Does the Stack Exist?

Consider nested function calls:

```c
void C() {}

void B() {
    C();
}

void A() {
    B();
}
```

Execution:

```text
A()
  |
  +-- B()
        |
        +-- C()
```

Each function call needs to remember where execution should return.

```text
A calls B:
    Save return address in A

B calls C:
    Save return address in B
```

If we used only one register for return addresses, nested calls would overwrite previous return addresses.

The solution is a **Stack (Last In, First Out)**.

```text
A calls B  -> Push return address to A
B calls C  -> Push return address to B

C returns  -> Pop return address to B
B returns  -> Pop return address to A
```

On x86, `call` and `ret` instructions support this behavior.

## 5. What Is a Stack Frame?

A **Stack Frame** is a region of the Stack associated with one particular function invocation.

A function may need space for:

- Return address
- Local variables
- Saved registers
- Temporary values

Example:

```c
int add(int a, int b) {
    int result = a + b;
    return result;
}
```

A conceptual Stack Frame:

```text
+-------------------+
| Return Address    |
+-------------------+
| Saved Registers   |
+-------------------+
| Local: result     |
+-------------------+
```

When the function returns, its Stack Frame can be reused.

The memory does not need to be cleared; adjusting the Stack Pointer is usually enough.

### Why Does Each Call Need Its Own Frame?

Consider recursion:

```c
int countdown(int n) {
    if (n == 0)
        return 0;

    return countdown(n - 1);
}
```

Execution:

```text
countdown(3) -> Frame: n = 3
  countdown(2) -> Frame: n = 2
    countdown(1) -> Frame: n = 1
      countdown(0) -> Frame: n = 0
```

Each invocation has its own execution state.

**The same Code can be executed repeatedly, while each invocation maintains independent temporary state.**

A compiler may optimize variables into registers or eliminate them entirely, so not every invocation necessarily requires a conventional memory-based Stack Frame.

## 6. How Does the Compiler Use the Stack?

The CPU does not understand C variables.

The compiler translates variables into machine instructions that operate on registers and memory.

For example:

```c
int x = 10;
x = x + 20;
```

A compiler could generate instructions conceptually similar to:

```asm
mov eax, [ebp-4]   ; Load x from its Stack Frame
add eax, 20        ; Calculate x + 20
mov [ebp-4], eax   ; Store the updated x
```

This illustrates memory access, not the exact generated code for the C example. A compiler might simply keep `x` in a register.

### Stack Pointer vs. Frame Pointer

| Register | Purpose |
|---|---|
| SP (Stack Pointer) | Tracks the current top of the Stack |
| FP (Frame Pointer) | Optionally provides a stable reference for the current Stack Frame |

The compiler may access variables using addresses such as:

```text
Frame Pointer - 4
Frame Pointer - 8
Frame Pointer + 8
```

These are offsets relative to a register, not absolute RAM addresses.

A Frame Pointer is optional; optimized code can access stack locations relative to SP instead.

## Mental Model

**Why not put all objects in stack? struct will do**
Because it's gone after function ends! We want some object last longer than that!!

So heap comes into picture.

Why can we just use registers? too few -> so we invent stack

Why not just stack? we want persist longer than function life cycel -> invent heap!

Heap and stack are all RAM!

## Think

SICP ch4 Environment vs. OS function call stack