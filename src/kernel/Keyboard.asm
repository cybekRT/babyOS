Keyboard_Init:
	rpush	bx, ds

	; Install handler
	mov	bx, 0
	mov	ds, bx

	mov	bx, 9*4
	mov	word [ds:bx+0], Keyboard_Handler
	mov	word [ds:bx+2], 0

	rpop
	ret

Keyboard_Handler:
	rpush	ax, bx, ds
	pushf
	mov	bx, 0
	mov	ds, bx

	mov	al, [kbdBufferBeg]
	mov	ah, [kbdBufferEnd]
	inc	al
	cmp	al, ah
	;je	.notEnoughMemory

	in	al, 0x60
	test	al, 0x80
	jne	.keyReleased

	mov	bx, kbdBuffer
	add	bx, [kbdBufferEnd]
	mov	[bx], al
	inc	byte [kbdBufferEnd]
	and	byte [kbdBufferEnd], 0x0f

.keyReleased:
.notEnoughMemory:
	mov	al, 0x20
	out	0x20, al

	popf
	rpop
	iret

Keyboard_GetChar:
	mov	ax, 0
	ret

	rpush	bx

	mov	al, [kbdBufferBeg]
	mov	ah, [kbdBufferEnd]
	je	.bufferEmpty

	mov	bx, kbdBuffer
	add	bx, [kbdBufferBeg]
	mov	al, [bx]

	inc	byte [kbdBufferBeg]
	and	byte [kbdBufferBeg], 0x0f

.bufferEmpty:
	xor	ah, ah
	rpop
	ret

Keyboard_GetBufferLength:
	xor	ah, ah
	mov	al, [kbdBufferEnd]
	sub	al, [kbdBufferBeg]
	and	ax, 0x0f
	ret

kbdBuffer times 16 db 0
kbdBufferBeg db 0
kbdBufferEnd db 0