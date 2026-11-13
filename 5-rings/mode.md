
# OS Questions

**The most important asymmetry in the Ring design: Lowering privileges is relatively easy, but raising privileges requires going through a controlled entry point.**

## A. Ring 3 → Ring 0 (Privilege Escalation)

| Mechanism | Triggered By | Description |
|---|---|---|
| `syscall` | User | Fast system call, commonly used in modern 64-bit operating systems |
| `sysenter` | User | Another fast system call mechanism |
| `int n` | User | Software interrupt, e.g., `int 0x80` |
| CPU Exception | CPU | Page faults, division by zero, invalid instructions, etc. |
| Hardware Interrupt | Hardware | Timer interrupts, device interrupts, IPIs, NMIs, etc. |
| Call Gate | User | A controlled entry point configured through CPU protection structures; rarely used in modern operating systems |

**Important:** `int n` does not allow a user program to execute an arbitrary kernel function. The CPU checks whether the specified interrupt entry is accessible from User Mode.

All these mechanisms require valid hardware-defined entry paths. Interrupts, exceptions, and Call Gates rely on protection structures configured by the kernel.

## B. Ring 0 → Ring 3 (Privilege Reduction)

| Mechanism | Purpose |
|---|---|
| `iretq` | Restores or constructs a user execution context, including the first transition into User Mode |
| `sysret` / `sysretq` | Fast return from a system call to User Mode |
| `sysexit` | Fast return mechanism paired with `sysenter` |
| `retf` / `retfq` | Far return, which can transition to a less privileged Ring |

A **Far Return** can also change the current Ring, provided the transition satisfies the CPU's privilege-checking rules.

An ordinary `ret` instruction cannot change the privilege level.
