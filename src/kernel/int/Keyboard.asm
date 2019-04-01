[org 0]
[bits 16]

%include "global.inc"
%include "Interrupt.inc"

InterruptInfo Keyboard_Init, Keyboard_GetBufferLength, Keyboard_GetChar

;;;;;;;;;;
;
; Interrupt installer
;
;;;;;;;;;;
Keyboard_Init:
	rpush	bx, ds

	; Install handler
	InstallInterrupt	IRQ2INT(IRQ_KEYBOARD), Keyboard_IRQ_Handler
	InstallInterrupt	INT_API_KEYBOARD

	rpop
	retf

;;;;;;;;;;
;
; Interrupt handler
;
;;;;;;;;;;
Keyboard_IRQ_Handler:
	rpush	ax, bx, cx
	pushf

	mov	al, [cs:kbdBufferBeg]
	mov	ah, [cs:kbdBufferEnd]
	inc	ah
	and	ah, (kbdBufferSize - 1)
	cmp	al, ah
	je	.notEnoughMemory

	in	al, 0x60
	test	al, 0x80
	jne	.keyReleased

	movzx	bx, byte [cs:kbdBufferEnd]
	add	bx, kbdBuffer
	mov	[cs:bx], al
	inc	byte [cs:kbdBufferEnd]
	and	byte [cs:kbdBufferEnd], (kbdBufferSize - 1)

	jmp	.keyReleased

.notEnoughMemory: ; TODO beep

	in	al, 0x60
.keyReleased:
	mov	al, 0x20
	out	0x20, al

	popf
	rpop
	iret

;;;;;;;;;;
;
; Get character
; Return:
;	al	-	scancode
;
;;;;;;;;;;
Keyboard_GetChar:
	rpush	bx

	mov	al, [cs:kbdBufferBeg]
	mov	ah, [cs:kbdBufferEnd]
	cmp	al, ah
	je	.bufferEmpty

	movzx	bx, byte [cs:kbdBufferBeg]
	add	bx, kbdBuffer
	mov	al, [cs:bx]

	inc	byte [cs:kbdBufferBeg]
	and	byte [cs:kbdBufferBeg], (kbdBufferSize - 1)

.ret:
	xor	ah, ah
	rpop
	iret
.bufferEmpty:
	stc
	;mov	ax, 0
	jmp	.ret

;;;;;;;;;;
;
; Get characters in buffer
; Return:
;	ax	-	characters in buffer
;
;;;;;;;;;;
Keyboard_GetBufferLength:
	rpush	ds

	push	cs
	pop	ds

	xor	ah, ah
	mov	al, [cs:kbdBufferEnd]
	sub	al, [cs:kbdBufferBeg]
	and	ax, (kbdBufferSize - 1)

	rpop
	iret

kbdBufferBeg db 0
kbdBufferEnd db 0
kbdBufferSize equ 16 ; Must be power of two
kbdBuffer times kbdBufferSize db 0