const SYSCON_REG_ADDR:usize = 0x11100000;
const UART_BUF_REG_ADDR:usize = 0x10000000;

const syscon = @intToPtr(*volatile u32, SYSCON_REG_ADDR);
const uart_buf_reg = @intToPtr(*volatile u8, UART_BUF_REG_ADDR);
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
