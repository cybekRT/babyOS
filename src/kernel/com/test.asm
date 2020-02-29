[bits 32]
main_std:
	;mov	byte [col], 0
	;mov	al, 0
main:
	;xchg	bx, bx
	push	eax
	mov	al, [eax + col]
	sti
	std
	mov	edi, 0xa0000 + 320*100
	;lea	esi, [rel col]
	;mov	al, [esi]
	;mov	al, [rel col]
	mov	ecx, 320*100
	rep	stosb
	cld
	;std
	;inc	byte [col]
	;inc	al
	;cld

	;mov	ecx, 0xffffff;ff

	push	2000
	call	ebx
	add	esp, 4

	;loop	$
	pop	eax
	inc	byte [eax + col]
	jmp	main

	ret

col db 0