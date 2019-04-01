[org 0]
[bits 16]

%include "global.inc"
%include "Interrupt.inc"

InterruptInfo Panic_Init, Panic_Panic

;;;;;;;;;;
;
; Interrupt installer
;
;;;;;;;;;;
Panic_Init:
	; Install handler
	InstallInterrupt	INT_API_PANIC

	push	ds
	push	cs
	pop	ds

	push	.msg
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	pop	ds
	retf

.msg db "Panic test!",0xA,0

;;;;;;;;;;
;
; Kernel panic
;
;;;;;;;;;;
Panic_Panic:
	push	bp
	mov	bp, sp

	; Dump registers
	push	word [bp+2] ; ip
	push	word [bp+4] ; cs
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
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT_ARGS
	add	sp, 26

	; Print memory map
	ApiCall	INT_API_MEMORY, MEMORY_PRINT_MAP

	; Push address of this ISR
	push	cs
	call	.afterPushingAddress
.afterPushingAddress:
	push	bp
	mov	bp, sp

	; Print callstack msg
	push	callStackMsg
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	; Print callstack entries
.csLoop:
	mov	ax, [bp+2]
	test	ax, ax
	jnz	.notZero
.zero:
	push	ax
	jmp	.zero_notZero
.notZero:
	sub	ax, 0x500
	push	ax
.zero_notZero:
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
	cli
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