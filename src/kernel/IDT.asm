;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Interrupt Description Table
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IDT_data:
times 256*IDT_size db 0
IDT_data_end:

IDT_Handle:
	dw (IDT_data_end - IDT_data)
	dd IDT_data

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; IDT pre-init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[bits 16]
IDT_PreInit:
	lidt	[IDT_Handle]

	ret
[bits 32]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; IDT init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IDT_Init:
	; Set general protection fault ISR
	mov	eax, IDT_data
	add	eax, IDT_size * INT_GENERAL_PROTECTION_FAULT

	mov	ebx, ISR_GeneralProtectionFault

	mov	word [eax + IDT.offset_0_15], bx
	shl	ebx, 16
	mov	word [eax + IDT.offset_16_31], bx

	mov	word [eax + IDT.selector], 0x8
	mov	byte [eax + IDT.flags], (IDT_FLAG_32BIT_INT_GATE | IDT_FLAG_STORAGE_SEGMENT | IDT_FLAG_RING_0 | IDT_FLAG_ENTRY_PRESENT)

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; ISR - General Protection Fault
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISR_GeneralProtectionFault:
	xchg	bx, bx

	push	.msg
	call	Terminal_Print
	add	esp, 4

	mov	al, 12
	; top
	mov	edi, 0xa0000
	mov	ecx, 320
	rep	stosb
	; bottom
	mov	edi, 0xa0000 + 199*320
	mov	ecx, 320
	rep	stosb
	; left
	mov	edi, 0xa0000
	mov	ecx, 200
.left_loop:
	mov	[edi], al
	add	edi, 320
	loop	.left_loop
	; right
	mov	edi, 0xa0000 + 319
	mov	ecx, 200
.right_loop:
	mov	[edi], al
	add	edi, 320
	loop	.right_loop

	call	Panic

	cli
	hlt
	jmp	$-1
.msg db 0xA,"General protection fault!",0xA,0
