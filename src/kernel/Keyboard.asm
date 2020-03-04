KBD_BUFFER_SIZE equ 32
kbd_buffer times KBD_BUFFER_SIZE db 0
kbd_w db 0
kbd_r db 0

Keyboard_Init:
	push	dword IRQ2INT(IRQ_KEYBOARD)
	push	dword Keyboard_IRQ
	call	IDT_RegisterISR
	add	esp, 8

	; Clear internal buffer
	; TODO some reset logic?
	mov	ecx, 32
.clear_loop:
	in	al, 0x60
	loop	.clear_loop

	ret

Keyboard_IRQ:
	push	eax
	push	ebx
	push	edx
	push	edi

	; Check buffer capacity
	mov	al, [kbd_w]
	inc	al
	and	al, KBD_BUFFER_SIZE - 1
	mov	ah, [kbd_r]
	cmp	al, ah
	je	.full

	; Read dst pointer
	mov	edi, kbd_buffer
	movzx	eax, byte [kbd_w]
	add	edi, eax

	in	al, 0x60
	and	al, 01111111b
	mov	[edi], al

	mov	al, [kbd_w]
	inc	al
	and	al, KBD_BUFFER_SIZE - 1
	;movzx	eax, byte [kbd_w]
	;inc	eax
	;mov	edx, 0
	;mov	ebx, KBD_BUFFER_SIZE
	;xchg bx, bx
	;div	ebx

	;mov	[kbd_w], dl
	mov	[kbd_w], al

	movzx	eax, byte [edi]
	push	eax
	push	.msg
	;print	"."
	call	Terminal_Print
	add	esp, 8

.exit:
	mov	al, 0x20
	out	0x20, al

	pop	edi
	pop	edx
	pop	ebx
	pop	eax
	iret
.full:
	print	"Kbd buffer full!"
	call	Panic
	in	al, 0x60
	jmp	.exit

.msg db "Pressed: %x",0xA,0