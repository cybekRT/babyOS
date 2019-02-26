[org 0]
[bits 16]

%include "global.inc"
%include "Interrupt.inc"

InterruptInfo Panic_Init, Panic_Panic

;;;;;;;;;;
; Interrupt installer
;;;;;;;;;;
Panic_Init:
	; Install handler
	InstallInterrupt	INT_API_PANIC

	push	ds
	push	cs
	pop	ds

	push	z
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	pop	ds
	iret

z db "Panic test!",0xA,0
Panic_Panic:
	push	bp
	mov	bp, sp

	push	cs
	call	.afterPushingAddress

.afterPushingAddress:
	push	bp
	mov	bp, sp

	; dump
	push	word [bp+2] ; ip
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
	; Fix strings segment
	push	cs
	pop	ds
	push	panicMsg
	push	12
	;call	printf
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT_ARGS
	add	sp, 26

	;call	Memory_PrintMap
	ApiCall	INT_API_MEMORY, MEMORY_PRINT_MAP

	; Print callstack msg
	push	callStackMsg
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	; Print callstack entries
.csLoop:
	mov	ax, [bp+2]
	sub	ax, 0x500
	push	ax
	push	word [bp+2]
	push	word [bp+4]
	push	callStackEntryMsg
	push	3
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT_ARGS
	add	sp, 10

	mov	sp, bp
	pop	bp
	test	bp, bp
	jnz	.csLoop

	; Print footer
	push	callStackEndMsg
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

.hlt:
	;cli
	hlt
	jmp	.hlt

panicMsg db 0xA,'Kernel halted!',0xA,\
	'Registers:',0xA,\
	'	AX: %x	BX: %x	CX: %x	DX: %x',0xA,\
	'	SI: %x	DI: %x	SS: %x	SP: %x',0xA,\
	'	DS: %x	ES: %x	CS: %x	IP: %x',0xA,0xA,0

callStackMsg db 0xA,'Call stack:',0xA,0
callStackEntryMsg db "    ^   (%X:)%X ( %X )",0xA,0
callStackEndMsg db   "    --     bootloader     --",0