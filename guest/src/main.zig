const std = @import("std");

const ECALL_HALT = 0;
const HALT_TERMINATE = 0;
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
		[outState] "{a1}" (&out_state)
		: "memory"
	);
	unreachable;
}

fn sys_sha_buffer(_: []u8) [8]u32 {
	var buffer = [_]u32{0} ** 8;

	// TODO do hash
	return buffer;
}

fn serialize_u64(value: u64) [8]u8 {
	return std.mem.asBytes(&value);
}
