%include "global.inc"
%include "Interrupt.inc"

InterruptInfo Keyboard_Init, Keyboard_GetBufferLength, Keyboard_GetChar

;;;;;;;;;;
; Interrupt installer
;;;;;;;;;;
Keyboard_Init:
	rpush	bx, ds

	; Install handler
	InstallInterrupt	IRQ2INT(IRQ_KEYBOARD), Keyboard_IRQ_Handler
	InstallInterrupt	INT_API_KEYBOARD
	;mov	bx, 0
	;mov	ds, bx

	;mov	bx, 9*4
	;mov	word [ds:bx+0], Keyboard_Handler
	;mov	word [ds:bx+2], 0

	rpop
	ret

;;;;;;;;;;
; Interrupt handler
;;;;;;;;;;
Keyboard_IRQ_Handler:
	rpush	ax, bx, ds
	pushf
	mov	bx, 0
	mov	ds, bx

	mov	al, [kbdBufferBeg]
	mov	ah, [kbdBufferEnd]
	inc	ah
	and	ah, (kbdBufferSize - 1)
	cmp	al, ah
	je	.notEnoughMemory

	in	al, 0x60
	test	al, 0x80
	jne	.keyReleased

	movzx	bx, byte [kbdBufferEnd]
	add	bx, kbdBuffer
	mov	[bx], al
	inc	byte [kbdBufferEnd]
	and	byte [kbdBufferEnd], (kbdBufferSize - 1)

.notEnoughMemory: ; TODO beep
.keyReleased:
	mov	al, 0x20
	out	0x20, al

	popf
	rpop
	iret

;;;;;;;;;;
; Get character
; Return:
;	al	-	scancode
;;;;;;;;;;
Keyboard_GetChar:
	rpush	bx

	mov	al, [kbdBufferBeg]
	mov	ah, [kbdBufferEnd]
	je	.bufferEmpty

	movzx	bx, byte [kbdBufferBeg]
	add	bx, kbdBuffer
	mov	al, [bx]

	inc	byte [kbdBufferBeg]
	and	byte [kbdBufferBeg], (kbdBufferSize - 1)

.ret:
	xor	ah, ah
	rpop
	ret
.bufferEmpty:
	stc
	;mov	ax, 0
	jmp	.ret

;;;;;;;;;;
; Get characters in buffer
; Return:
;	ax	-	characters in buffer
;;;;;;;;;;
Keyboard_GetBufferLength:
	xor	ah, ah
	mov	al, [kbdBufferEnd]
	sub	al, [kbdBufferBeg]
	and	ax, (kbdBufferSize - 1)
	ret

kbdBufferBeg db 0
kbdBufferEnd db 0
kbdBuffer times 8 db 0
kbdBufferSize equ ($ - kbdBuffer) ; Must be power of two