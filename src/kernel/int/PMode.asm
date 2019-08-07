[org 0]
[bits 16]

%include "global.inc"
%include "Interrupt.inc"

InterruptInfo PMode_Init

helloMsg db "Trying to set protected mode...",0xA,0

GDT_FLAG_CODE_READ		equ (1 << 1)
GDT_FLAG_DATA_WRITE		equ (1 << 1)
GDT_FLAG_CONFORMING		equ (1 << 2)
GDT_FLAG_SEG_DATA		equ (0 << 3)
GDT_FLAG_SEG_CODE		equ (1 << 3) ; executable bit
GDT_FLAG_SEG_CODE_OR_DATA	equ (1 << 4)

GDT_FLAG_RING_0			equ (0b00 << 5)
GDT_FLAG_RING_1			equ (0b01 << 5)
GDT_FLAG_RING_2			equ (0b10 << 5)
GDT_FLAG_RING_3			equ (0b11 << 5)

GDT_FLAG_ENTRY_PRESENT		equ (1 << 7)

GDT_ATTRIBUTE_UNUSED		equ (1 << 4)
GDT_ATTRIBUTE_32BIT_SIZE	equ (1 << 6)
GDT_ATTRIBUTE_GRANULARITY	equ (1 << 7)

struc GDT
	.limit_0_15 resw 1,
	.base_0_15 resw 1,
	.base_16_23 resb 1,
	.flags resb 1,
	.limit_16_19_attributes resb 1,
	.base_24_31 resb 1
endstruc

v_gdt:
dq 0
istruc GDT
	at GDT.limit_0_15, dw 0xffff
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_CODE_READ | GDT_FLAG_SEG_CODE | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend

istruc GDT
	at GDT.limit_0_15, dw 0xffff;
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_DATA_WRITE | GDT_FLAG_SEG_DATA | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend
v_gdt_end

gdt_desc:
	dw (v_gdt_end - v_gdt)
	dd v_gdt

PMode_Init:
	;retf
	rpush	ds

	push	cs
	pop	ds
	push	helloMsg
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	cli
	mov	ax, 0
	int	10h

	mov	ax, 0
	mov	ds, ax

	xchg	bx, bx

	;lgdt	[gdt_desc]
	mov	eax, cs
	shl	eax, 4
	add	eax, gdt_desc
	lgdt	[eax]
	jmp	0x8:PMode

	rpop
	retf

[bits 32]
PMode:
	mov	eax, 0xb8000

	mov	byte [eax+0], 'e'
	mov	byte [eax+2], 'P'
	mov	byte [eax+4], 'm'
	mov	byte [eax+6], ' '

	hlt
	jmp	PMode