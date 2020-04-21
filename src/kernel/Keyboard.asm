KBD_BUFFER_SIZE equ 32
kbd_buffer times KBD_BUFFER_SIZE db 0
kbd_w db 0
kbd_r db 0

Keyboard_Handler:
	call	Keyboard_ReadKey
	jc	.exit

	print	"keyboard"

.exit:
	ret

Keyboard_Init:
	push	dword IRQ2INT(IRQ_KEYBOARD)
	push	dword Keyboard_IRQ
	call	IDT_RegisterISR
	add	esp, 8

	push	Keyboard_Handler
	call	Kernel_Register

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

	xor	eax, eax
.read_code:
	in	al, 0x60
	;and	al, 01111111b
	cmp	al, 0x60
	jne	.whole_code

	shl	eax, 8
	jmp	.read_code

.whole_code:
	call	Keyboard_ScanCode2KeyCode
	jc	.exit

	mov	[edi], al

	mov	al, [kbd_w]
	inc	al
	and	al, KBD_BUFFER_SIZE - 1

	mov	[kbd_w], al

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

.msg db "Pressed: %p - %p - %c",0xA,0

Keyboard_ScanCode2KeyCode:
	push	esi

	mov	esi, KBD_KeyCodes
.loop:
	cmp	[esi + KBD_KEYCODE_t.scanCode], ax
	je	.found

	add	esi, KBD_KEYCODE_t_size
	cmp	esi, KBD_KeyCodes_end
	je	.not_found
	jmp	.loop

.found:
	movzx	eax, byte [esi + KBD_KEYCODE_t.keyCode]
	clc
	jmp	.exit

.not_found:
	movzx	eax, ax
	push	eax
	push	.msg
	;call	Terminal_Print
	add	esp, 8

	mov	eax, KBD_NONE
	stc
.exit:
	pop	esi
	ret
.msg db "Pressed: %x",0xA,0

Keyboard_ReadKey:
	; Check if buffer is not empty
	mov	al, [kbd_w]
	mov	ah, [kbd_r]
	cmp	al, ah
	je	.empty

	movzx	eax, byte [kbd_r]
	movzx	eax, byte [kbd_buffer + eax]

	inc	byte [kbd_r]
	and	byte [kbd_r], KBD_BUFFER_SIZE - 1
.exit:
	ret
.empty:
	mov	al, 0
	stc
	jmp	.exit

Keyboard_Key2AsciiLow:
	movzx	eax, al
	mov	al, [KBD_KeyCodes + eax * KBD_KEYCODE_t_size + KBD_KEYCODE_t.asciiLow]
	ret

Keyboard_Key2AsciiHigh:
	movzx	eax, al
	mov	al, [KBD_KeyCodes + eax * KBD_KEYCODE_t_size + KBD_KEYCODE_t.asciiHigh]
	ret
