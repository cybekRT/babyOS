cursorX dw 0
cursorY dw 0
cursorColor db 0xA
backgroundColor db 0x18

%include "data/font.def"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Terminal init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Terminal_Init:

	mov	al, [backgroundColor]
	mov	ecx, 320*200
	mov	edi, 0xa0000
	rep stosb

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
	rpush	ebp, eax, ebx, ecx, edx, esi, edi
	;xchg bx, bx

	; Special chars
	mov	al, byte [ebp + 8]

	cmp	al, 0xD
	je	.CR
	cmp	al, 0xA
	je	.LF
	jmp	.normalChar

.CR:
	call	Terminal_CR
	jmp	.exit
.LF:
	call	Terminal_LF
	jmp	.exit

	;movzx	eax, word [cursorPos]
	;shl	eax, 1
	;add	eax, 0xb8000
	;mov	bl, [ebp + 8]
	;mov	[eax], bl

	;inc	word [cursorPos]

.normalChar:
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
	jz	.bg

	mov	dl, [cursorColor]
	jmp	.char

.bg:
	mov	dl, [backgroundColor]
.char:
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

	;mov	ax, [cursorX]
	;mov	bx, [cursorY]
	;inc	ax
	inc	word [cursorX]
	cmp	word [cursorX], 320 / fontWidth
	jne	.exit

	;mov	ax, 0
	;inc	bx
	mov	word [cursorX], 0
	inc	word [cursorY]
	mov	ax, [cursorY]
	mov	bx, fontHeight
	mul	bx
	add	ax, fontHeight - 1
	cmp	ax, 200
	jbe	.exit

	dec	word [cursorY]
	call	Terminal_Scroll

.exit:
	;mov	[cursorX], ax
	;mov	[cursorY], bx
	;inc	byte [cursorColor]

	rpop
	ret

Terminal_LF:
	mov	word [cursorX], 0
	inc	word [cursorY]
	mov	ax, [cursorY]
	mov	bx, fontHeight
	mul	bx
	add	ax, fontHeight - 1
	cmp	ax, 200
	jbe	.exit

	call	Terminal_Scroll
.exit:
	ret

Terminal_CR:
	mov	word [cursorX], 0
	ret

Terminal_Scroll:
	; Scroll
	mov	esi, 0xa0000 + 320 * fontHeight
	mov	edi, 0xa0000
	mov	ecx, 320 * (200 / fontHeight - 1) * fontHeight
	rep movsb
	; Clear line
	mov	al, [backgroundColor]
	mov	edi, 0xa0000 + 320 * (200 / fontHeight - 1) * fontHeight
	mov	ecx, 320 * fontHeight
	rep stosb

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Terminal - Print
; Arguments:
; 	(ebp + 8)	-	string pointer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Terminal_Print:
	rpush	ebp, eax, esi

	mov	esi, [ebp + 8]
	xchg	bx, bx
.loop:
	movzx	eax, byte [esi]
	test	al, al
	jz	.exit

	push	eax
	call	Terminal_Put
	add	esp, 4

	inc	esi
	jmp	.loop

.exit:
	rpop
	ret
