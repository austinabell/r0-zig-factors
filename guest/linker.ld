ENTRY(_start)

SECTIONS
{
	. = 0x00200800;
	.text 0x00200800 : ALIGN(4) {
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
