[org 0]
[bits 16]

%include "global.inc"
%include "Interrupt.inc"

InterruptInfo GUI_Init

GUI_Init:
	rpush	ax, bx, cx, es

	mov	ax, 0x13
	int	0x10

	mov	bx, 0xa000
	mov	es, bx
	mov	bx, 0

	mov	al, 0
	mov	cx, 320*200
.loop:
	mov	[es:bx], al
	inc	al
	inc	bx
	loop	.loop

	rpop
	retf
