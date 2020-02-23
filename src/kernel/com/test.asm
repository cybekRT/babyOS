[bits 32]
main:
	mov	edi, 0xa0000
	mov	al, 1
	mov	ecx, 320*200
	rep	stosb

	ret
