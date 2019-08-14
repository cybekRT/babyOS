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

	push	.helloMsg
	call	Terminal_Print
	add	esp, 4

	push	dword 0xbaadf00d
	push	dword 0xabcdef12
	push	dword 0x4321
	push	dword 2137
	push	dword -2137
	push	dword -2137
	push	.testMsg
	call	Terminal_Print
	add	esp, 28

	ret
.helloMsg db OS_NAME,0xA,0xA,0
.testMsg db "Test: %d, %u, %u, %x, %x, %p",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Terminal - Put
; Arguments:
; 	(ebp + 8)	-	char
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Terminal_Put:
	rpush	ebp, eax, ebx, ecx, edx, esi, edi

	; Special chars
	mov	al, byte [ebp + 8]

	cmp	al, 0xD ; carriage return
	je	.CR
	cmp	al, 0xA ; line feed
	je	.LF
	jmp	.normalChar

.CR:
	call	Terminal_CR
	jmp	.exit
.LF:
	call	Terminal_LF
	jmp	.exit

.normalChar:
	mov	ax, [cursorY]
	mov	bx, fontHeight
	mul	bx
	add	ax, fontHeight / 2

	mov	bx, 320
	mul	bx

	push	dx
	push	ax

	mov	ax, [cursorX]
	mov	bx, fontWidth
	mul	bx
	add	ax, fontWidth / 2

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

	inc	word [cursorX]
	cmp	word [cursorX], 320 / fontWidth - 1
	jne	.exit

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
	rpush	ebp, eax, ebx, ecx, esi, edi

	mov	esi, [ebp + 8]
	mov	edi, 12
	;xchg	bx, bx
.loop:
	movzx	eax, byte [esi]

	; null
	test	al, al
	jz	.exit
	; percent
	cmp	al, '%'
	je	.special

	push	eax
	call	Terminal_Put
	add	esp, 4

	inc	esi
	jmp	.loop

.special:
	inc	esi
	mov	al, [esi]

	inc	esi
	cmp	al, 'p'
	je	.special_p
	cmp	al, 'P'
	je	.special_p_no_0x
	cmp	al, 'x'
	je	.special_x
	cmp	al, 'X'
	je	.special_x_no_0x
	cmp	al, 'd'
	je	.special_d
	cmp	al, 'u'
	je	.special_u

	push	word '%'
	call	Terminal_Put
	add	esp, 2

	dec	esi
	jmp	.loop

.special_x:
	push	dword '0'
	call	Terminal_Put
	push	dword 'x'
	call	Terminal_Put
	add	esp, 8
.special_x_no_0x:
	mov	eax, [ebp + edi]
	test	eax, eax
	jz	.special_x_zero

	mov	ecx, 8
.special_x_shift_loop:
	test	eax, 0xf0000000
	jnz	.special_p_loop

	shl	eax, 4
	dec	ecx
	jmp	.special_x_shift_loop

.special_x_zero:
	mov	ecx, 1
	jmp	.special_p_loop

.special_p_no_0x:
	mov	eax, [ebp + edi]
	mov	ecx, 8
	jmp	.special_p_loop

.special_p:
	mov	eax, [ebp + edi]
	xchg	bx, bx

	push	dword '0'
	call	Terminal_Put
	push	dword 'x'
	call	Terminal_Put
	add	esp, 8

	mov	ecx, 8
.special_p_loop:
	mov	ebx, eax
	shr	ebx, 28

	mov	bl, [.hex_ascii + ebx]
	push	ebx
	call	Terminal_Put
	add	esp, 4

	shl	eax, 4
	loop	.special_p_loop

	add	edi, 4
	jmp	.loop

.special_u:
	mov	eax, [ebp + edi]
	xchg	bx, bx
	jmp	.special_d_no_minus

.special_d:
	mov	eax, [ebp + edi]
	xchg	bx, bx

	cmp	eax, 0
	jge	.special_d_no_minus

	push	dword '-'
	call	Terminal_Put
	add	esp, 4
	neg	eax
.special_d_no_minus:
	push	eax
	push	edx
	mov	ecx, 0
.special_d_div_loop:
	mov	ebx, 10
	xor	edx, edx

	div	ebx

	add	edx, '0'
	push	edx
	inc	ecx

	test	eax, eax
	jnz	.special_d_div_loop

.special_d_no_minus_put_loop:
	call	Terminal_Put
	add	esp, 4
	loop	.special_d_no_minus_put_loop

	add	edi, 4

	pop	edx
	pop	eax
	jmp	.loop

.exit:
	rpop
	ret

;.hex_0x db "0x",0
.hex_ascii db "0123456789ABCDEF"