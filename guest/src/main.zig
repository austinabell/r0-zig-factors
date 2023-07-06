const std = @import("std");

const ECALL_HALT = 0;
const ECALL_SHA = 3;
const HALT_TERMINATE = 0;
const FILENO_JOURNAL = 3;
const FILENO_STDIN = 0;
const ECALL_SOFTWARE = 2;

const INITIAL_SHA_STATE = [_]u32{
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
};

comptime {
    asm (
        \\ .section .text._start
        \\ .globl _start
        \\ _start:
        \\ .option push
        \\ .option norelax
        \\ la gp, __global_pointer$
        \\ .option pop
		// Sets stack top to 0x0BFFFC00 (or should)
		\\ lui sp, 0x0BFFF
        \\ addi sp, sp, 1024
		\\ lui t0, 0xF
		\\ addi t0, t0, 768
		\\ or sp, sp, t0
        // \\ lw sp, 0(sp)
        \\ jal ra, __start
    );
}

export fn __start() callconv(.Naked) noreturn {
    // Create buffer large enough for two u64 values.
    // This could be done separately, but it saves a syscall to read all words at once.
    var buffer = [_]u8{0} ** 16;
    sys_read(FILENO_STDIN, 16, &buffer);
    const a: u64 = std.mem.bytesAsValue(u64, buffer[0..8]).*;
    const b: u64 = std.mem.bytesAsValue(u64, buffer[8..16]).*;
    if (a == 1 or b == 1) {
        @panic("Trivial factors");
    }

    // var product: u64 = a;
    var product: u64 = undefined;
    if (@mulWithOverflow(u64, a, b, &product)) {
        @panic("Integer overflow");
    }

    const serialized_value = std.mem.asBytes(&product);
    sys_write(serialized_value);
    var sha_state = sys_sha_buffer(serialized_value, INITIAL_SHA_STATE);

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

fn sys_sha_buffer(data: []u8, in_state: [8]u32) [8]u32 {
    // TODO this assumes that the data is unaligned and that there is not enough for a full block
    // for the sake of this program it's fine, but logic will be different if the data is larger
    // than the block size.
    var buffer: [8]u32 = undefined;

    // TODO this is assuming a single block, without length terminated padding, zero padded.
    // This works for this program, but will need to be changed if used ambiguously.
    var hash_block: [16]u32 = [_]u32{0} ** 16;
    // TODO see if can just use a u8 buffer and send pointer as if u32 array
    var bytes = @ptrCast([*]u8, &hash_block);

    // Copy whole bytes
    var len = std.math.min(data.len, hash_block.len * 4);
    std.mem.copy(u8, bytes[0..len], data[0..len]);

    asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_SHA),
          [buffer] "{a0}" (&buffer),
          [in_state] "{a1}" (&in_state),
          [block_1_ptr] "{a2}" (&hash_block),
          [block_2_ptr] "{a3}" (&hash_block[8..]),
          [count] "{a4}" (1),
        : "memory"
    );

    return buffer;
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
