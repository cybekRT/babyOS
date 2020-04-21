%include "PIT.inc"

_ticks dq 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Timer init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Timer_Init:
	; On VirtualBox, you must set IRQ handler before setting PIT... !?
	push	dword IRQ2INT(IRQ_TIMER)
	push	dword ISR_PIT
	call	IDT_RegisterISR
	add	esp, 8

	mov	al, PIT_COMMAND_CHANNEL_0 | PIT_COMMAND_AMODE_LOHIBYTE | PIT_COMMAND_OPMODE_3 | PIT_COMMAND_BMODE_BINARY
	out	PIT_PORT_COMMAND, al

	mov	ax, 0x4A9
	out	PIT_PORT_CHANNEL_0, al
	xchg	al, ah
	out	PIT_PORT_CHANNEL_0, al

	;in	al, 0x61
	;or	al, 3
	;out	0x61, al

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

	;push	dword [ebp + 8]
	;push	.msg1
	;call	Terminal_Print
	;add	esp, 8

	mov	eax, dword [_ticks]
	add	eax, [ebp + 8]

	pushf
	sti
.loop:
	push	eax
	;hlt
	pushf
	;push	dword cs
	mov	eax, cs
	push	eax
	;call	.loop2
;.loop2:
	;xchg	bx, bx
	call	Process_Scheduler
	pop	eax
	cmp	eax, [_ticks]
	ja	.loop

	;push	.msg2
	;call	Terminal_Print
	;add	esp, 4

	popf
	rpop
	ret
.msg1 db "Waiting %u ms... ",0
.msg2 db "OK",0xA,0

Timer_Get:
	mov	eax, [_ticks]
	ret

ISR_PIT:
	pushf

	add	dword [_ticks + 0], 1
	adc	dword [_ticks + 4], 0

	push	ax
	mov	al, 0x20
	out	0x20, al
	pop	ax

	popf
	call	Process_SchedulerFromIRQ

	; this should never return...
	xchg	bx, bx
	jmp	$
	iret
