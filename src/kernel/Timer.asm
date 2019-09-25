%include "PIT.inc"

_ticks dq 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Timer init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Timer_Init:
	mov	al, PIT_COMMAND_CHANNEL_0 | PIT_COMMAND_AMODE_LOHIBYTE | PIT_COMMAND_OPMODE_3 | PIT_COMMAND_BMODE_BINARY
	out	PIT_PORT_COMMAND, al

	mov	ax, 0x4A9
	out	PIT_PORT_CHANNEL_0, al
	xchg	al, ah
	out	PIT_PORT_CHANNEL_0, al

	;in	al, 0x61
	;or	al, 3
	;out	0x61, al

	push	dword IRQ2INT(IRQ_TIMER)
	push	dword ISR_PIT
	call	IDT_RegisterISR
	add	esp, 8

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Timer delay
; Arguments:
; 	(ebp + 8)	- delay in ms
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Timer_Delay:
	rpush	ebp, eax

	mov	eax, dword [_ticks]
	add	eax, [ebp + 8]

	pushf
	sti
.loop:
	hlt
	cmp	eax, [_ticks]
	ja	.loop

	popf
	rpop
	ret

omg dd 0
ISR_PIT:
	;xchg bx, bx
	;jmp $

	;pushf

	add	dword [_ticks + 0], 1
	adc	dword [_ticks + 4], 0

	;push	eax
	;mov	eax, [_ticks]
	;mov	[tmp_value], eax

	;pop	eax

	mov	al, 0x20
	out	0x20, al

	;inc	dword [omg]
	;cmp	dword [omg], 200
	;jne	x
	;mov	dword [omg], 0
	;popf
	;iret
	call	Process_Scheduler

x:
	;mov	al, 0x20
	;out	0x20, al
	iret

	; this should never return...
	xchg bx, bx
	jmp $
	iret