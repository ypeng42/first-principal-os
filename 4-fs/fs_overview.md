# File Systems — Reinventing OS Abstractions

**Core Idea:** A File System is a software abstraction built on top of raw block storage.

Each new abstraction emerges to solve a problem that the previous design could not handle well.

The goal is to understand **why each abstraction exists**, not to memorize how a particular File System implements it.

---

# Part 1 — From Hardware to File Systems

### Q1. What primitives does storage hardware provide?

**Answer:** Conceptually, a disk provides a persistent array of blocks.

Abstract API:

```text
read(block_id)
write(block_id, data)
```

Hardware does not understand Files, Directories, or Paths.

### Q2. Why can't we just use raw blocks?

**Answer:** We can! If the location and size of the data are known in advance, we don't need a File System.

For example, a bootloader might know:

```text
Kernel:
    start = Block 10
    size = 20 Blocks
```

It can directly read Blocks 10–29.

**Remaining Problem:** What happens when the size or location of the data changes?

### Q3. How do we know where a file is stored and how large it is?

**Answer:** Introduce Metadata.

```text
File Descriptor:
    start = 10
    size = 10000 bytes
```

However, this design assumes the file occupies contiguous blocks.

### Q4. What if a file is not stored contiguously?

**Answer:** Use a Block List.

```text
blocks = [10, 25, 7, 42]
```

A logically contiguous file can occupy physically non-contiguous blocks.

**Key Abstraction: Logical File ≠ Physical Layout.**

### Q5. What if the Block List becomes too large?

**Answer:** Use hierarchical indexing, such as Indirect Blocks.

```text
inode
  ↓
Indirect Block
  ↓
[Block 10, Block 25, Block 42, ...]
```

Small files can use direct pointers, while large files can use multiple levels of indexing.

### Q6. What problem does an inode solve?

**Answer:** An inode provides a file with an identity and a metadata record.

For example:

```text
inode #42:
    size
    permissions
    timestamps
    data block references
```

An inode does not contain the file's name.

**Key Abstraction: File Identity ≠ File Name.**

Note: An inode is a particular filesystem design. Not every filesystem uses Unix-style on-disk inodes.

### Q7. How do we know which blocks are free?

**Answer:** Use Free Space Management, such as a Bitmap.

```text
Block:  0 1 2 3 4 5
Bitmap: 1 0 1 0 0 1

0 = Free
1 = Used
```

This is fundamentally the same allocation problem faced by a RAM Physical Page Allocator.

The allocation algorithm can be reused.

However, disk allocation metadata must persist across reboots, whereas RAM allocation state is typically reconstructed during boot.

### Q8. Why do we need Directories?

**Answer:** Users want to find files by name rather than inode number.

A Directory is essentially a mapping:

```text
Name → inode

"hello.txt" → inode #42
```

A Directory can itself be represented by an inode whose data blocks contain directory entries.

### Q9. Why are Rename and Move operations often fast?

**Answer:** Because a file's name and identity are separate.

Rename:

```text
Before:
    "a.txt" → inode #42

After:
    "b.txt" → inode #42
```

Move within the same File System:

```text
/home/a.txt → inode #42

Becomes:

/tmp/a.txt → inode #42
```

Only Directory Entries need to change.

The actual file contents do not need to move.

Moving files across different File Systems usually requires copying the data and deleting the original.

### Q10. How does Path Resolution work?

**Answer:** Parse + Lookup.

```text
/home/alex/a.txt
       ↓
Root Directory
       ↓
home
       ↓
alex
       ↓
a.txt → inode #42
```

Each directory lookup resolves one path component into the next filesystem object.

### Q11. What exactly is Mount?

**Answer:** Mount attaches the root of a File System to a unified path namespace.

Suppose we have two independent File Systems:

```text
FS A:
/
├── home
└── mnt
    └── usb

FS B:
/
└── photo.jpg
```

Execute:

```text
mount(FS_B, "/mnt/usb")
```

Now the file becomes accessible through:

```text
/mnt/usb/photo.jpg
```

**Key Abstraction: Mount = Namespace Composition.**

Multiple independent File Systems appear as one unified Directory Tree.

### Q12. Why do we need VFS (Virtual File System)?

**Answer:** Different File Systems use different storage formats, but applications should not need to understand those differences.

```text
Application
    ↓
open / read / write
    ↓
VFS
    ↓
ext4 / FAT / Btrfs implementation
    ↓
Disk
```

**Key Abstraction: VFS = Unified Interface + Runtime Dispatch.**

### Q13. Who interprets the rules of a specific File System?

**Answer:** The corresponding File System Driver or Implementation.

Responsibilities:

- **VFS:** Provides the common interface, path resolution, and operation dispatch.
- **FS Driver:** Interprets filesystem-specific metadata and block layouts.

Most filesystem implementations run inside the Kernel.

However, mechanisms such as FUSE allow filesystems to be implemented in User Space.

### Q14. How does an FS Driver get into the Kernel? Is it installed during Mount?

**Answer:** Driver Loading and Mounting are separate operations.

```text
Load Driver
    ↓
Kernel learns how to handle an FS format

Mount
    ↓
Open a particular FS instance
    ↓
Attach it to the namespace
```

A driver can be compiled directly into the Kernel or loaded dynamically as a Kernel Module.

One driver implementation can serve multiple mounted File System instances.

**Key Distinction: Implementation ≠ Instance.**

---

# Part 2 — Crash Consistency

### Q15. Creating a file requires updating the Bitmap, inode, and Directory. What if power fails halfway through?

**Answer:** Multiple independent writes can leave the File System in an inconsistent state.

For example:

```text
1. Allocate inode       ✓
2. Initialize inode     ✓
3. Add directory entry  ✗  Power loss
```

The inode is allocated, but no filename points to it.

We need a way to make multiple modifications behave as one recoverable transaction.

### Q16. How does Journaling solve this problem?

**Answer:** Use Write-Ahead Logging.

```text
1. Prepare
   ↓
Write planned modifications to Journal

2. Commit
   ↓
Persist the Commit Record

3. Apply
   ↓
Update actual filesystem metadata
```

Crash Recovery:

- **Before Commit:** Discard the incomplete transaction.
- **After Commit:** Redo the transaction until the modifications are complete.

This requires a reliable commit record and correct persistence ordering.

**Key Abstraction: Transaction = Multiple Writes Treated as One Logical Operation.**

### Q17. Isn't the Journal itself a file? 😂

**Answer:** Not necessarily. The Journal can occupy a reserved region of the disk.

```text
Disk:
    Superblock
    Journal Region
    Metadata
    Data Blocks
```

The Journal can be located using fixed disk addresses.

It does not require Directory Lookup, inode allocation, or dynamic block allocation.

This stops the apparent infinite recursion.

### Q18. What if power fails while writing the Journal itself?

**Answer:** Use a reliable Commit Record to determine whether the transaction was fully committed.

```text
Journal Records
    ↓
Commit Record
```

Only complete, committed transactions are replayed.

The entire Journal does not need to be written atomically.

It only needs a reliable way to distinguish committed transactions from incomplete ones.

Real systems must also account for partial writes, write ordering, caching, and checksums.

### Q19. What happens when the Journal becomes full?

**Answer:** Use Checkpointing.

After committed modifications have been safely applied to their final locations, their Journal space can be reused.

Therefore, the Journal can be a fixed-size circular log.

### Q20. Does Journaling guarantee that file contents cannot be lost?

**Answer:** Not necessarily.

Metadata Journaling primarily protects filesystem metadata consistency.

It does not automatically guarantee that the latest file contents have been persisted.

**Key Distinction: Crash Consistency ≠ Data Durability.**

---

# Part 3 — Why Do Different File Systems Exist?

Different File Systems solve fundamentally similar problems but optimize for different goals.

Their designs reflect different engineering trade-offs.

## 1. FAT32 / exFAT — Simplicity & Compatibility

**Design Philosophy:** Keep the data structures simple and make it easy to exchange files across different devices.

**Example: FAT Cluster Chain**

```text
Cluster 5 → Cluster 8 → Cluster 12 → END
```

Instead of storing a complete Block List in each file's metadata, the File Allocation Table links clusters together.

**Advantages:**
- Relatively simple design.
- Broad compatibility.
- Suitable for removable storage.

**Trade-offs:**
- FAT32 has file-size and volume-size limitations.
- Lacks many advanced Unix filesystem features.
- Limited built-in crash recovery.

exFAT extends the FAT family to support larger files and storage devices and improves allocation efficiency.

## 2. ext4 — General-Purpose Balance

**Design Philosophy:** Balance performance, reliability, maturity, and implementation complexity.

**Example: Extents**

Instead of recording every block:

```text
blocks = [10, 11, 12, 13]
```

Store a continuous range:

```text
Extent:
    start = 10
    length = 4
```

One Extent can represent many contiguous Blocks.

ext4 also uses Journaling to protect filesystem metadata consistency.

**Advantages:**
- Mature and reliable.
- Good general-purpose performance.
- Efficient extent-based storage.

**Trade-offs:**
- Does not provide built-in CoW snapshots.
- Does not prioritize end-to-end data checksumming in the same way as ZFS.

## 3. XFS — Scalability & Throughput

**Design Philosophy:** Optimize for large File Systems, large files, and high-throughput concurrent I/O.

**Example: Concurrent Operations**

Suppose multiple threads are modifying different files:

```text
Thread A → Update file A
Thread B → Update file B
Thread C → Update file C
```

A naive filesystem might force too many unrelated operations to wait on a global lock.

XFS uses scalable metadata structures and concurrency mechanisms to reduce unnecessary contention.

**Advantages:**
- Strong performance for large files and high-throughput workloads.
- Scalable metadata management.
- Efficient use of Extents and B-trees.

**Trade-off:** Greater implementation complexity.

## 4. Btrfs — Copy-on-Write & Snapshots

**Design Philosophy:** Preserve old data while constructing new versions.

Instead of overwriting an existing Block, allocate a new Block and update the references after the new state is ready.

**Example: Copy-on-Write**

```text
Original:
    Block 5 → "Hello"

Update:
    Block 8 → "World"

After Commit:
    Current  → Block 8
    Snapshot → Block 5
```

A Snapshot preserves references to old data rather than immediately copying all file contents.

Unmodified Blocks can be shared between versions.

**Advantages:**
- Snapshots.
- Copy-on-Write.
- Checksums.
- Efficient sharing of unchanged data.

**Trade-offs:**
- More complicated metadata management.
- Potential write amplification and fragmentation.
- Additional space-management complexity.

**Key Idea: Build a New State Before Replacing the Old State.**

## 5. ZFS — Data Integrity First

**Design Philosophy:** Treat data integrity as a fundamental design requirement.

ZFS combines Copy-on-Write, checksums, redundancy mechanisms, and storage management.

**Example: Checksums**

```text
read(block)
    ↓
calculate_checksum(block)
    ↓
compare_with_stored_checksum()
    ↓
Valid? → Return data
Invalid? → Detect corruption
```

Even when the disk reports a successful read, the returned bytes might be corrupted.

Checksums allow ZFS to detect certain forms of silent corruption.

When appropriate redundant copies exist, ZFS can attempt automatic repair.

**Advantages:**
- Strong data integrity mechanisms.
- Snapshots.
- Copy-on-Write.
- Integrated storage management.

**Trade-offs:**
- More complex architecture.
- Additional metadata and resource requirements.

**Key Idea: Successful I/O Does Not Necessarily Mean Correct Data.**

## 6. F2FS — Flash-Aware Design

**Design Philosophy:** Optimize filesystem behavior for the physical characteristics of Flash Storage.

Flash devices have constraints involving erase blocks, write amplification, and wear.

A filesystem designed without considering these costs may generate inefficient write patterns.

**Example: Log-Structured Writes**

Instead of frequently overwriting scattered locations:

```text
Update A → Old location A
Update B → Old location B
Update C → Old location C
```

Organize updates into new sequential regions:

```text
New write region:
    [Update A][Update B][Update C]
```

Old regions can later be reclaimed through cleaning and garbage collection.

F2FS uses a flash-friendly, log-structured approach to organizing data.

**Advantages:**
- Designed with Flash characteristics in mind.
- Can reduce certain inefficient write patterns.

**Trade-offs:**
- Requires cleaning and space-reclamation mechanisms.
- More complex data placement and maintenance.

**Key Idea: The Same Storage API Can Have Different Costs on Different Hardware.**

---

# Part 4 — The Final Mental Model

```text
┌──────────────────────────────────────┐
│            User Program              │
│       File Names, Paths, I/O         │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│                VFS                   │
│   Unified Interface + Namespace      │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│      File System Implementation      │
│                                      │
│  Directory / inode / Allocation      │
│  Metadata / Crash Recovery           │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│     Block Layer + Device Driver      │
│                                      │
│        Read / Write Blocks           │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│             Disk / SSD               │
│                                      │
│       Persistent Block Storage       │
└──────────────────────────────────────┘
```

file system On Disk Format is a contract, for a file, as long as both reader and writer agree, it's good.