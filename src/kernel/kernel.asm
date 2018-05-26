[bits 16]
[org 0x500]
[CPU 386]

KERNEL_BEGIN:
	jmp	init

%include "../global.inc"
%include "Interrupt.inc"
%include "Terminal.asm"
%include "Memory.asm"
;%include "FAT12.asm"
;%include "Keyboard.asm"

init:
	cli
	mov	bx, 0;cs
	mov	ds, bx
	mov	es, bx
	mov	ss, bx
	mov	sp, stackBegin

	call	Terminal_Init
	call	Memory_Init

	; Alloc memory for stack
	push	2048
	;call	Memory_AllocBytes
	ApiCall	INT_API_MEMORY, MEMORY_API_ALLOC_BYTES
	mov	ss, ax
	mov	sp, 2048

	; Init FAT12
	;call	FAT12_Init

	; Keyboard
	;call	Keyboard_Init

	sti
.test:
	hlt
	;call	Keyboard_GetBufferLength
	cmp	ax, 0
	jz	.test

	mov	bx, ax
	;call	Keyboard_GetChar
	jc	.test
	push	ax
	push	bx
	push	.buff
	call	printf
	add	sp, 6
	jmp	.test
.bufsizestr db 'Buffer: %d  ', 0xD,0
.buff db "Buffer %d, %c",0xA,0

	call	Panic

Panic:
	call	Memory_PrintMap

	; [bp] - ip
	mov	bp, sp

	; dump
	push	word [bp]
	push	cs
	push	es
	push	ds
	push	sp
	push	ss
	push	di
	push	si
	push	dx
	push	cx
	push	bx
	push	ax
	push	panicMsg
	call	printf

	cli
	hlt
	jmp	Panic

panicMsg: db 0xA,'Kernel halted!',0xA,\
	'Registers:',0xA,\
	'	AX: %x	BX: %x',0xA,\
	'	CX: %x	DX: %x',0xA,\
	'	SI: %x	DI: %x',0xA,\
	'	SS: %x	SP: %x',0xA,\
	'	DS: %x	ES: %x',0xA,\
	'	CS: %x	IP: %x'

stackEnd: times 64 db 0
stackBegin:
KERNEL_END equ $-$$ + 0x500
