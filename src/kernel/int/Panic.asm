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

	retf

z db "Panic test!",0xA,0
Panic_Panic:
	push	bp
	mov	bp, sp

	;push	cs
	;pop	ds
	;push	z
	;ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	;add	sp, 2

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
	;call	printf
	;ApiCall	INT_API_TERMINAL, API_TERMINAL_PRINT

	;call	Memory_PrintMap

	; Print callstack msg
	push	callStackMsg
	;call	printf
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
	;call	printf
	add	sp, 8

	mov	sp, bp
	pop	bp
	test	bp, bp
	jnz	.csLoop

	; Print footer
	push	callStackEndMsg
	;call	printf
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

.hlt:
	cli
	hlt
	jmp	.hlt

panicMsg db 0xA,'Kernel halted!',0xA,\
	'Registers:',0xA,\
	'	AX: %x	BX: %x',0xA,\
	'	CX: %x	DX: %x',0xA,\
	'	SI: %x	DI: %x',0xA,\
	'	SS: %x	SP: %x',0xA,\
	'	DS: %x	ES: %x',0xA,\
	'	CS: %x	IP: %x',0xA,0xA,0

callStackMsg db 0xA,'Call stack:',0xA,0
callStackEntryMsg db "    ^   (%X:)%X ( %X )",0xA,0
callStackEndMsg db   "    --     bootloader     --",0xA,0