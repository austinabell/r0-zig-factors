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

export fn _start() callconv(.Naked) noreturn {
    // TODO logic

    sys_halt();
}

fn sys_halt() noreturn {
    // TODO pull hash state instead of zeroed
    const out_state = [_]u32{0} ** 8;
    asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_HALT),
          // NOTE: rust code does bit OR with the exit code, but in code is always 0, so ignored
          [haltCode] "{a0}" (HALT_TERMINATE),
          [outState] "{a1}" (&out_state),
        : "memory"
    );
    unreachable;
}

fn sys_sha_buffer(data: []u8, in_state: [8]u32) [8]u32 {
    // TODO this assumes that the data is unaligned and that there is not enough for a full block
    // for the sake of this program it's fine, but logic will be different if
    var buffer: [8]u32 = undefined;

    // TODO this is assuming a single block, without length terminated padding, zero padded.
    // This works for this program, but will need to be changed if used ambiguously.
    var hash_block: [16]u32 = [_]u32{0} ** 16;
	// TODO see if can just use a u8 buffer and send pointer as if u32 array
    var bytes = @ptrCast([*]u8, &hash_block);

    // Copy whole bytes
    var len = std.math.min(data.len, bytes.len);
    std.mem.copy(u8, bytes[0..len], data[0..len]);

    asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_HALT),
          [buffer] "{a0}" (&buffer),
          [in_state] "{a1}" (&in_state),
          [block_1_ptr] "{a2}" (&hash_block),
          [block_2_ptr] "{a3}" (&hash_block[8..]),
          [count] "{a4}" (1),
        : "memory"
    );

    return buffer;
}

fn serialize_u64(value: u64) [8]u8 {
    return std.mem.asBytes(&value);
}

fn sys_write(data: []u8) noreturn {
	const syscall_name: [:0]const u8 = "nr::SYS_WRITE";
	asm volatile (
        \\ ecall
        :
        : [syscallNumber] "{t0}" (ECALL_SOFTWARE),
          [from_host] "{a0}" (&undefined),
          [from_host_words] "{a1}" (&0),
          [syscall_name] "{a2}" (syscall_name),
          [file_descriptor] "{a3}" (FILENO_JOURNAL),
          [write_buf] "{a4}" (&data),
          [write_buf_len] "{a5}" (data.len),
        : "memory"
    );
}

fn sys_read(fd: u32, comptime nrequested: usize, buffer: [nrequested]u8) usize {
    const main_words = nrequested / @sizeOf(u32);

	const syscall_name: [:0]const u8 = "nr::SYS_READ";
	asm volatile (
        \\ ecall
		:
        // : [out_a0] "={a0}" (a0) // NOTE: probably don't need to know the amount read
        : [syscallNumber] "{t0}" (ECALL_SOFTWARE),
          [from_host] "{a0}" (&buffer),
          [from_host_words] "{a1}" (main_words),
          [syscall_name] "{a2}" (syscall_name),
          [file_descriptor] "{a3}" (fd),
          [main_requested] "{a4}" (nrequested),
        : "memory"
    );
}
