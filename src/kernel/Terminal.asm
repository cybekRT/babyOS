cursorX dw 1
cursorY dw 1
cursorColor db 0

%include "data/font.def"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Terminal init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Terminal_Init:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Terminal - Put
; Arguments:
; 	(ebp + 8)	-	char
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Terminal_Put:
	;xchg	bx, bx
	rpush	ebp, eax, ebx, ecx, edx
	xchg bx, bx

	;movzx	eax, word [cursorPos]
	;shl	eax, 1
	;add	eax, 0xb8000
	;mov	bl, [ebp + 8]
	;mov	[eax], bl

	;inc	word [cursorPos]

	mov	ax, [cursorY]
	mov	bx, fontHeight
	mul	bx

	mov	bx, 320
	mul	bx

	push	dx
	push	ax

	mov	ax, [cursorX]
	mov	bx, fontWidth
	mul	bx

	movzx	eax, ax
	pop	edx

	add	eax, edx
	mov	edi, eax
	add	edi, 0xa0000

	movzx	eax, byte [ebp + 8]
	mov	bx, fontHeight
	mul	bx
	add	eax, font
	mov	esi, eax

	mov	ecx, fontHeight
.yLoop:
	push	ecx

	mov	ecx, fontWidth
	mov	al, [esi]
.xLoop:
	test	al, 0x80
	jz	.next

	mov	dl, [cursorColor]
	mov	byte [edi], dl

.next:
	shl	al, 1
	inc	edi
	loop	.xLoop

	pop	ecx
	inc	esi
	add	edi, 320 - fontWidth
	loop	.yLoop

	;movzx	edi, word [cursorPos]
	;shl	edi, 3

	mov	ax, [cursorX]
	mov	bx, [cursorY]
	inc	ax
	cmp	ax, 320 / fontWidth
	jne	.exit

	mov	ax, 0
	inc	bx
.exit:
	mov	[cursorX], ax
	mov	[cursorY], bx
	inc	byte [cursorColor]

	rpop
	ret
.dest dw 0
