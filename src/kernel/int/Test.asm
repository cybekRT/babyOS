%include "global.inc"
%include "Interrupt.inc"

InterruptInfo Test

Test:
	push	ds
	push	cs
	pop	ds

	push	.msg
	ApiCall	INT_API_TERMINAL, 0
	add	sp, 2

	push	.msg_far
	ApiCall	INT_API_TERMINAL, 0
	add	sp, 2

	pop	ds
	retf

.msg db "Testing... ",0

times 1024*1 db 0

.msg_far db "Testing!!!",0xA,0
