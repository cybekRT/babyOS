cursorColor db 0xA
backgroundColor db 0x18

CURSOR_OFFSET_X_CFG equ 5
CURSOR_OFFSET_Y_CFG equ 1

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
CURSOR_OFFSET_X equ (CURSOR_OFFSET_X_CFG * 2 + fontWidth - 1) / fontWidth * fontWidth / 2
CURSOR_OFFSET_Y equ (CURSOR_OFFSET_Y_CFG * 2 + fontHeight - 1) / fontHeight * fontHeight / 2
cursorX dw 0
cursorY dw 0

%include "data/font.def"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Terminal init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Terminal_Init:
	rpush	eax, ecx, edi

	mov	word [cursorX], 0
	mov	word [cursorY], 0

	mov	al, [backgroundColor]
	mov	ecx, SCREEN_WIDTH * SCREEN_HEIGHT
	mov	edi, 0xa0000
	rep stosb

	push	.helloMsg
	call	Terminal_Print
	add	esp, 4

	push	Terminal_Cursor
	call	Kernel_Register
	add	esp, 4

	rpop
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
	pushf
	cli

	call	Terminal_ClearCursor

	; Special chars
	mov	al, byte [ebp + 8]

	cmp	al, 0x08 ; backspace
	je	.BS
	cmp	al, 0x0D ; carriage return
	je	.CR
	cmp	al, 0x0A ; line feed
	je	.LF
	cmp	al, 0x09 ; tab
	je	.Tab
	jmp	.normalChar

.BS:
	call	Terminal_BS
	jmp	.exit
.CR:
	call	Terminal_CR
	jmp	.exit
.LF:
	call	Terminal_LF
	jmp	.exit
.Tab:
	call	Terminal_Tab
	jmp	.exit

.normalChar:
	mov	ax, [cursorY]
	mov	bx, fontHeight
	mul	bx
	add	ax, CURSOR_OFFSET_Y

	mov	bx, SCREEN_WIDTH
	mul	bx

	push	dx
	push	ax

	mov	ax, [cursorX]
	mov	bx, fontWidth
	mul	bx
	add	ax, CURSOR_OFFSET_X

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
	add	edi, SCREEN_WIDTH - fontWidth
	loop	.yLoop

	inc	word [cursorX]
	cmp	word [cursorX], (SCREEN_WIDTH - CURSOR_OFFSET_X * 2) / fontWidth
	jb	.exit

	call	Terminal_LF
.exit:
	popf
	rpop
	ret

Terminal_BS:
	mov	ax, word [cursorX]
	cmp	ax, 0
	jz	.x_zero

	dec	word [cursorX]
.exit:
	ret
.x_zero:
	mov	word [cursorX], (SCREEN_WIDTH - CURSOR_OFFSET_X * 2) / fontWidth - 1
	mov	ax, [cursorY]
	cmp	ax, 0
	jz	.y_zero

	dec	word [cursorY]
	jmp	.exit
.y_zero:
	mov	word [cursorX], 0
	jmp	.exit

Terminal_CR:
	mov	word [cursorX], 0
	ret

Terminal_LF:
	mov	word [cursorX], 0
	inc	word [cursorY]
	mov	ax, [cursorY]
	cmp	ax, (SCREEN_HEIGHT - CURSOR_OFFSET_Y * 2) / fontHeight
	jb	.exit

	dec	word [cursorY]
	call	Terminal_Scroll
.exit:
	ret

Terminal_Tab:
	rpush	ax, bx, ecx, dx

	mov	dx, 0
	mov	ax, word [cursorX]
	mov	bx, 8
	div	bx

	test	dx, dx
	jz	.exit

	movzx	ecx, dx
	push	dword ' '
.loop:
	call	Terminal_Put
	loop	.loop
	add	esp, 4

.exit:
	rpop
	ret

Terminal_Scroll:
	; Scroll
	mov	esi, 0xa0000 + SCREEN_WIDTH * (fontHeight + CURSOR_OFFSET_Y)
	mov	edi, 0xa0000 + SCREEN_WIDTH * (CURSOR_OFFSET_Y)
	mov	ecx, SCREEN_WIDTH * (SCREEN_HEIGHT / fontHeight - 1) * fontHeight
	rep movsb
	; Clear line
	mov	al, [backgroundColor]
	mov	edi, 0xa0000 + SCREEN_WIDTH * (SCREEN_HEIGHT / fontHeight - 1) * fontHeight
	mov	ecx, SCREEN_WIDTH * fontHeight
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
	cmp	al, 'b'
	je	.special_b
	cmp	al, 'c'
	je	.special_c
	cmp	al, 's'
	je	.special_s

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
	jmp	.special_d_no_minus

.special_d:
	mov	eax, [ebp + edi]

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

.special_b:
	mov	eax, [ebp + edi]

	mov	ecx, 1
	test	eax, eax
	jz	.special_b_zero

	mov	ecx, 32
.special_b_dec_ecx:
	test	eax, 1 << 31
	jnz	.special_b_loop
	dec	ecx
	shl	eax, 1
	jmp	.special_b_dec_ecx

.special_b_loop:
	test	eax, 1 << 31
	jz	.special_b_zero
	jnz	.special_b_one

.special_b_zero:
	push	dword '0'
	call	Terminal_Put
	add	esp, 4
	jmp	.special_b_next_bit

.special_b_one:
	push	dword '1'
	call	Terminal_Put
	add	esp, 4
	jmp	.special_b_next_bit

.special_b_next_bit:
	shl	eax, 1
	loop	.special_b_loop

	push	dword 'b'
	call	Terminal_Put
	add	esp, 4

	add	edi, 4
	jmp	.loop

.special_c:
	mov	eax, [ebp + edi]
	movzx	eax, al

	push	eax
	call	Terminal_Put
	add	esp, 4
	add	edi, 4

	jmp	.loop

.special_s:
	mov	eax, [ebp + edi]
	add	edi, 4
	push	edi

.special_s_loop:
	movzx	edi, byte [eax]
	push	edi
	call	Terminal_Put
	add	esp, 4

	inc	eax
	cmp	[eax], byte 0
	jnz	.special_s_loop

	pop	edi
	jmp	.loop

.exit:
	rpop
	ret

;.hex_0x db "0x",0
.hex_ascii db "0123456789ABCDEF"


cursor_loop_id db 0

cursorTimer dd 0
Terminal_Cursor:
	pushf
	cli

	mov	eax, [_ticks]
	cmp	eax, [cursorTimer]
	jb	.exit

	call	Terminal_CursorLoop
	xor	byte [cursor_loop_id], 1

	mov	eax, [_ticks]
	add	eax, 200
	mov	[cursorTimer], eax

.exit:
	popf
	ret

Terminal_DrawCursor:
	cmp	byte [cursor_loop_id], 1
	je	.exit

	call	Terminal_CursorLoop
.exit:
	mov	byte [cursor_loop_id], 1
	ret

Terminal_ClearCursor:
	cmp	byte [cursor_loop_id], 0
	je	.exit

	call	Terminal_CursorLoop
.exit:
	mov	byte [cursor_loop_id], 0
	ret

Terminal_CursorLoop:
	rpush	eax, ebx, edx

	mov	ax, word [cursorY]
	mov	bx, fontHeight
	mul	bx
	add	ax, CURSOR_OFFSET_Y

	mov	bx, SCREEN_WIDTH
	mul	bx

	push	ax
	mov	ax, word [cursorX]
	mov	bx, fontWidth
	mul	bx

	add	ax, CURSOR_OFFSET_X
	pop	bx
	add	ax, bx

	movzx	eax, ax
	add	eax, 0xa0000
	xchg bx, bx

	mov	ecx, fontHeight
.loop_y:
	push	ecx
	mov	ecx, fontWidth
.loop_x:
	xor	byte [eax], 0x3
	inc	eax

	dec	ecx
	jnz	.loop_x

	pop	ecx
	add	eax, SCREEN_WIDTH - fontWidth

	dec	ecx
	jnz	.loop_y

	rpop
	ret

