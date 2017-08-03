[bits 16]
org 0x500
KERNEL_BEGIN:

jmp	init

%include "Terminal.asm"
%include "Memory.asm"

wwait:
	push	cx

	mov	cx, 0xffff
.a:
	cmp	cx, 0
	dec	cx
	jnz	.a

	pop	cx
	ret

init:
	; 
	cli
	mov	bx, cs
	mov	ds, bx
	mov	es, bx
	mov	ss, bx
	mov	sp, stackBegin

	call	Terminal_Init
	call	Memory_Init

	; init stack
	;push	1024
	;call	Memory_Alloc
	;mov	ss, ax
	;mov	sp, 1024

	; Say hello
	push	hello
	push	0x1234
	push	65535
	push	-1234
	push	hello
	call	printf
	add	sp, 6

	call	Panic

Panic:
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
	push	si,
	push	dx
	push	cx
	push	bx
	push	ax
	push	panicMsg
	call	printf

	cli
	hlt
	jmp	Panic

hello: db 'babyOS v0.1: %d %u % %% %x %a %s',0xA,0
panicMsg: db 0xA,'Kernel halted!',0xA,\
	'Registers:',0xA,\
	'	AX: %x	BX: %x',0xA,\
	'	CX: %x	DX: %x',0xA,\
	'	SI: %x	DI: %x',0xA,\
	'	SS: %x	SP: %x',0xA,\
	'	DS: %x	ES: %x',0xA,\
	'	CS: %x	IP: %x'

stackEnd: times 128 db 0
stackBegin:
KERNEL_END: