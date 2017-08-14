[bits 16]
[org 0x7c00]
[cpu 286]

init:
	mov	[DRIVE_NUMBER], dl

	; Read whole kernel
	mov	ah, 02h
	mov	al, (KERNEL_SIZE + 511) / 512
	mov	cx, 2
	mov	dh, 0
	mov	dl, [DRIVE_NUMBER]

	mov	bx, 0
	mov	es, bx
	mov	bx, 0x500

	int	0x13
	jc	error

	jmp	0x0:0x500

error:
	mov	bx, 0xb800
	mov	es, bx
	mov	bx, 0
	mov	byte [es:bx+0], 'X'
	mov	byte [es:bx+2], 'X'
	mov	byte [es:bx+4], 'X'

	int	0x18

DRIVE_NUMBER: db 0

times 510 - ($ - $$) db 0
dw 0xAA55