[org 0]
[bits 16]

%include "global.inc"
%include "Interrupt.inc"

InterruptInfo PMode_Init

helloMsg db "Trying to set protected mode...",0xA,0

PMode_Init:
	push	cs
	pop	ds
	push	helloMsg
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	retf