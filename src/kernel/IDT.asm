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
	; Initialize PICs
	mov	al, 0x11
	out	PIC0_PORT_CMD, al

	mov	al, INT_PIC0_OFFSET
	out	PIC0_PORT_DATA, al

	mov	al, 4
	out	PIC0_PORT_DATA, al

	mov	al, 1
	out	PIC0_PORT_DATA, al

	mov	al, 0x11
	out	PIC1_PORT_CMD, al

	mov	al, INT_PIC0_OFFSET
	out	PIC1_PORT_DATA, al

	mov	al, 2
	out	PIC1_PORT_DATA, al

	mov	al, 1
	out	PIC1_PORT_DATA, al

	; Set general protection fault ISR
	push	dword INT_GENERAL_PROTECTION_FAULT
	push	ISR_GeneralProtectionFault
	call	IDT_RegisterISR
	add	esp, 8

	push	dword 0x27
	push	ISR_DUMMY
	call	IDT_RegisterISR
	add	esp, 8

	
	push	dword INT_INVALID_OPCODE
	push	ISR_DUMMY2
	call	IDT_RegisterISR
	add	esp, 8

	push	dword IRQ2INT(IRQ_KEYBOARD)
	push	ISR_DUMMY
	call	IDT_RegisterISR
	add	esp, 8

	ret

ISR_DUMMY:
	mov	al, 0x20
	out	0x20, al
	iret

ISR_DUMMY2:
	cli
	xchg bx, bx
	hlt
	jmp ISR_DUMMY2

	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Register ISR
; Arguments:
; 	(ebp + 12)	- interrupt id
; 	(ebp + 8)	- handler
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IDT_RegisterISR:
	rpush	ebp, eax, ebx, edx

	;xchg	bx, bx
	mov	eax, [ebp + 12]
	mov	ebx, IDT_size
	mul	ebx
	add	eax, IDT_data

	mov	ebx, [ebp + 8]

	mov	word [eax + IDT.offset_0_15], bx
	shl	ebx, 16
	mov	word [eax + IDT.offset_16_31], bx

	mov	word [eax + IDT.selector], 0x8
	mov	byte [eax + IDT.flags], (IDT_FLAG_32BIT_INT_GATE | IDT_FLAG_STORAGE_SEGMENT | IDT_FLAG_RING_0 | IDT_FLAG_ENTRY_PRESENT)

	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; ISR - General Protection Fault
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISR_GeneralProtectionFault:
	rpush	ebp, eax, ecx, esi, edi
	xchg	bx, bx
	;jmp	Panic

	push	.msg
	call	Terminal_Print
	add	esp, 4

	; Selector index
	mov	eax, [ebp + 4]
	;jmp $
	shr	eax, 3
	push	eax

	; IDT/GDT/LDT table
	mov	eax, [ebp + 4]
	shr	eax, 1
	and	eax, 0b11
	push	eax

	; External
	mov	eax, [ebp + 4]
	and	eax, 1
	push	eax

	push	.msgCode
	call	Terminal_Print
	add	esp, 16

	;jmp $

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

	rpop
	add	esp, 4 ; remove error code from stack
	jmp	Panic

	cli
	hlt
	jmp	$-1
.msg db 0xA,"General protection fault!",0xA,0
.msgCode db "  Ext: %b, Type: %b, Index: %u",0xA,0
