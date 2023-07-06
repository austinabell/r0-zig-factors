ENTRY(_start)

SECTIONS
{
	. = 0x07000000;
	.text 0x07000000 : ALIGN(4) {
		*(.text)
	}

	.data : ALIGN(4) {
		*(.rodata)
		*(.rodata.*)
		*(.data)
		*(.data.*)
	}

	.bss : ALIGN( 4 ) {
		*(.bss)
		*(.bss.*)
	}
}
