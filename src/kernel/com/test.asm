[bits 32]
main:
	sti
	mov	edi, 0xa0000
	mov	al, [col]
	mov	ecx, 320*100
	rep	stosb
	inc	byte [col]

	mov	ecx, 0xffffff;ff
	loop	$
	jmp	main

	ret

col db 0