[bits 16]
[org 0x500]
[CPU 386]
KERNEL_BEGIN:
	jmp	init

%include "Terminal.asm"
%include "Memory.asm"

init:
	mov	bx, 0
	mov	gs, bx

	; 
	cli
	mov	bx, cs
	mov	ds, bx
	mov	es, bx
	mov	ss, bx
	mov	sp, stackBegin

	call	Terminal_Init
	call	Memory_Init

	; Alloc memory for stack
	push	2048
	call	Memory_AllocBytes
	mov	ss, ax
	mov	sp, 2048

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

;times 1474560 - ($-$$) - 512 db 0