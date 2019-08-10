IDT_FLAG_32BIT_TASK_GATE equ (0x5 << 0)
IDT_FLAG_16BIT_INT_GATE equ (0x6 << 0)
IDT_FLAG_16BIT_TRAP_GATE equ (0x7 << 0)
IDT_FLAG_32BIT_INT_GATE equ (0xE << 0)
IDT_FLAG_32BIT_TRAP_GATE equ (0xF << 0)

IDT_FLAG_STORAGE_SEGMENT equ (0 << 4) ; ??
IDT_FLAG_RING_0 equ (0b00 << 5)
IDT_FLAG_RING_1 equ (0b01 << 5)
IDT_FLAG_RING_2 equ (0b10 << 5)
IDT_FLAG_RING_3 equ (0b11 << 5)
IDT_FLAG_ENTRY_PRESENT equ (1 << 7)

struc IDT
	.offset_0_15 resw 1
	.selector resw 1
	.unused resb 1
	.flags resb 1
	.offset_16_31 resw 1
endstruc
