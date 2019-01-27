[org 0]
[bits 16]

;mov	bx, 0xb800
;mov	es, bx
;mov	bx, 0
;mov	byte [es:bx+0], 'x'
;mov	byte [es:bx+2], 'D'
;mov	byte [es:bx+4], ' '
;jmp $

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

	;mov	ax, IRQ2INT(IRQ_KEYBOARD)
	;jmp	$
	
	;mov	bx, 0
	;mov	ds, bx
	;mov	bx, 9*4
	;mov	word [ds:bx+0], Keyboard_IRQ_Handler
	;mov	ax, cs
	;mov	word [ds:bx+2], ax

xchg bx, bx
	push	cs
	pop	ds
	push	.initMsg
	ApiCall INT_API_TERMINAL, 0
	add	sp, 2

	rpop
	retf
.initMsg db "INT: keyboard!",0xA,0,0,0

;;;;;;;;;;
; Interrupt handler
;;;;;;;;;;
Keyboard_IRQ_Handler:
	rpush	ax, bx
	;, ds
	pushf
	;mov	bx, 0
	;mov	ds, bx

	;push	cs
	;pop	ds

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
	mov	[bx], al
	inc	byte [cs:kbdBufferEnd]
	and	byte [cs:kbdBufferEnd], (kbdBufferSize - 1)

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
	;, ds

	;push	cs
	;pop	ds

	mov	al, [cs:kbdBufferBeg]
	mov	ah, [cs:kbdBufferEnd]
	je	.bufferEmpty

	movzx	bx, byte [cs:kbdBufferBeg]
	add	bx, kbdBuffer
	mov	al, [bx]

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
; Get characters in buffer
; Return:
;	ax	-	characters in buffer
;;;;;;;;;;
Keyboard_GetBufferLength:
	;rpush	ds

	;push	cs
	;pop	ds

	xor	ah, ah
	mov	al, [cs:kbdBufferEnd]
	sub	al, [cs:kbdBufferBeg]
	and	ax, (kbdBufferSize - 1)

	;rpop
	iret

kbdBufferBeg db 0
kbdBufferEnd db 0
kbdBuffer times 8 db 0
kbdBufferSize equ ($ - kbdBuffer) ; Must be power of two