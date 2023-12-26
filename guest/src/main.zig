const std = @import("std");

const ECALL_HALT = 0;
const ECALL_SHA = 3;
const HALT_TERMINATE = 0;
const FILENO_JOURNAL = 3;
const FILENO_STDIN = 0;
const ECALL_SOFTWARE = 2;

const WORD_SIZE = 4;
const DIGEST_WORDS = 8;
const DIGEST_BYTES = DIGEST_WORDS * WORD_SIZE;
const BLOCK_WORDS = DIGEST_WORDS * 2;
const MAX_SHA_COMPRESS_BLOCKS = 1000;

// TODO try to use with alloc
// // Symbol defined by the linker script, maybe zig will pick up.
// pub extern "c" const _end: u8;

comptime {
    asm (
        \\ .section .text._start
        \\ .globl _start
        \\ _start:
        \\ .option push
        \\ .option norelax
        \\ la gp, __global_pointer$
        \\ .option pop
        // Sets stack top to 0x0020_0400
        \\ lui sp, 0x0020
        \\ addi sp, sp, 1024
        \\ lui t0, 0x04
        \\ addi t0, t0, 1024
        \\ or sp, sp, t0
        // \\ lw sp, 0(sp)
        \\ call __start
        \\ jal ra, __start
    );
}

export fn __start() callconv(.C) noreturn {
    // Create buffer large enough for two u64 values.
    // This could be done separately, but it saves a syscall to read all words at once.
    var buffer = [_]u8{0} ** 16;
    sys_read(FILENO_STDIN, 16, &buffer);
    const a: u64 = std.mem.bytesAsValue(u64, buffer[0..8]).*;
    const b: u64 = std.mem.bytesAsValue(u64, buffer[8..16]).*;
    if (a == 1 or b == 1) {
        @panic("Trivial factors");
    }

    var product = @mulWithOverflow(a, b);
    if (product[1] == 1) {
        @panic("Integer overflow");
    }

    const serialized_value = std.mem.asBytes(&product[0]);
    sys_write(serialized_value);

    var initial_sha_state = [_]u32{
        0x6a09e667,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
    };

    // Arch is little endian, but these values are expected as big endian for SHA, swap.
    for (&initial_sha_state) |*value| {
        value.* = @byteSwap(value.*);
    }
    var sha_state = sys_sha_buffer(serialized_value, &initial_sha_state);

    // TODO for 0.20 this needs to be sha256(sha256("risc0.Output")+sha_state+<zero digest>+2u16.to_le_bytes()))
    sys_halt(&sha_state);
}

fn sys_halt(out_state: *[8]u32) noreturn {
    asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_HALT),
          // NOTE: rust code does bit OR with the exit code, but in code is always 0, so ignored
          [haltCode] "{a0}" (HALT_TERMINATE),
          [outState] "{a1}" (out_state),
        : "memory"
    );
    unreachable;
}

fn sys_sha_buffer(data: []u8, in_state: *const [8]u32) [8]u32 {
    // TODO this assumes that the data is unaligned and that there is not enough for a full block
    // for the sake of this program it's fine, but logic will be different if the data is larger
    // than the block size.
    var out_state: [8]u32 = [_]u32{0} ** 8;

    // Allocate a buffer to hold all of the data and trailer, aligned to a block boundary.
    const pad_len = compute_u32s_needed(data.len);

    // Note: do not need to deallocate for a zkvm program, wasted cycles
    // TODO reserving a larger but static amount of buffer until I resolve a reasonable way to alloc
    var hash_buffer: [160]u32 = [_]u32{0} ** 160;
    var bytes = @as([*]u8, @ptrCast(&hash_buffer));

    // Copy whole bytes
    var len = @min(data.len, pad_len * 4);
    std.mem.copy(u8, bytes[0..len], data[0..len]);

    // Add END marker since this is always with a trailer
    bytes[len] = 0x80;

    // Add trailer with number of bits written. This needs to be big endian.
    const bits_trailer: u32 = 8 * data.len;
    hash_buffer[pad_len - 1] = @byteSwap(bits_trailer);

    // TODO might need to zero rest of buffer, when actually doing alloc.
    // Note: the rest of the memory should be able to be assumed to be zero.

    // Following logic maps to what happens in the `sys` call in Rust
    // TODO this doesn't split large requests into smaller ones as the Rust impl does, yet
    asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_SHA),
          [out_state] "{a0}" (&out_state),
          [in_state] "{a1}" (in_state),
          [block_1_ptr] "{a2}" (&hash_buffer),
          [block_2_ptr] "{a3}" (hash_buffer[8..]),
          [count] "{a4}" (pad_len / BLOCK_WORDS),
        : "memory"
    );

    return out_state;
}

fn sys_write(data: []u8) void {
    const syscall_name: [:0]const u8 = "risc0_zkvm_platform::syscall::nr::SYS_WRITE";
    asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_SOFTWARE),
          [from_host] "{a0}" (data.ptr),
          [from_host_words] "{a1}" (0),
          [syscall_name] "{a2}" (syscall_name.ptr),
          [file_descriptor] "{a3}" (FILENO_JOURNAL),
          [write_buf] "{a4}" (data.ptr),
          [write_buf_len] "{a5}" (data.len),
        : "memory"
    );
}

fn sys_read(fd: u32, comptime nrequested: usize, buffer: *[nrequested]u8) void {
    const main_words = nrequested / 4;

    const syscall_name: [:0]const u8 = "risc0_zkvm_platform::syscall::nr::SYS_READ";
    asm volatile (
        \\ ecall
        :
        // : [out_a0] "={a0}" (a0) // NOTE: probably don't need to know the amount read
        : [syscallNumber] "{t0}" (ECALL_SOFTWARE),
          [from_host] "{a0}" (buffer),
          [from_host_words] "{a1}" (main_words),
          [syscall_name] "{a2}" (syscall_name.ptr),
          [file_descriptor] "{a3}" (fd),
          [main_requested] "{a4}" (nrequested),
        : "memory"
    );
}

fn compute_u32s_needed(len_bytes: usize) usize {
    // Add one byte for end marker
    var nwords = align_up(len_bytes + 1, WORD_SIZE) / WORD_SIZE;
    // Add two words for length at end (even though we only
    // use one of them, being a 32-bit architecture)
    nwords += 2;

    return align_up(nwords, BLOCK_WORDS);
}

fn align_up(addr: usize, al: usize) usize {
    return (addr + al - 1) & ~(al - 1);
}
