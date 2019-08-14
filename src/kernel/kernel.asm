[bits 16]
[org 0x500]
[cpu 386]

KERNEL_BEGIN:
	cli
	mov	[driveNumber], dl
	call	Init

%include "../global.inc"
%include "Interrupt.inc"

%include "GDT.inc"
%include "IDT.inc"

driveNumber db 0

;;;;;;;;;;
;
; Real Mode - entry
;
;;;;;;;;;;
Init:
	mov	bx, 0
	mov	ds, bx
	mov	es, bx
	mov	ss, bx
	mov	sp, stackBegin

	xchg	bx, bx
	call	Memory_PreInit

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax, 0x13
	int	0x10

	lgdt	[GDT_Handle]
	lidt	[IDT_Handle]

	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	jmp	0x8:PMode_main


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Global Descriptor Table
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GDT_data:
dq 0
istruc GDT
	at GDT.limit_0_15, dw 0xffff
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_CODE_READ | GDT_FLAG_SEG_CODE | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend

istruc GDT
	at GDT.limit_0_15, dw 0xffff
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_DATA_WRITE | GDT_FLAG_SEG_DATA | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend
GDT_data_end:

GDT_Handle:
	dw (GDT_data_end - GDT_data)
	dd GDT_data

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
; Protected Mode - entry
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[bits 32]
PMode_main:
	mov	bx, 0x10
	mov	ds, bx
	mov	es, bx
	mov	fs, bx
	mov	gs, bx
	mov	ss, bx
	mov	esp, stackBegin

	; Set general protection fault ISR
	mov	eax, IDT_data
	add	eax, IDT_size * INT_GENERAL_PROTECTION_FAULT

	mov	ebx, INT_0D

	mov	word [eax + IDT.offset_0_15], bx
	shl	ebx, 16
	mov	word [eax + IDT.offset_16_31], bx

	mov	word [eax + IDT.selector], 0x8
	mov	byte [eax + IDT.flags], (IDT_FLAG_32BIT_INT_GATE | IDT_FLAG_STORAGE_SEGMENT | IDT_FLAG_RING_0 | IDT_FLAG_ENTRY_PRESENT)

	; Initialize kernel main services
	call	Terminal_Init
	call	Memory_Init

	; End of kernel, halt :(
	hlt
	jmp PMode_main

INT_0D:
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

	;mov	dword [eax+0], 0
	;mov	dword [eax+4], 0
	;mov	dword [eax+8], 0
	;mov	dword [eax+16], 0

	hlt
	jmp	INT_0D
.msg db 0xA,"General protection fault!",0xA,0

Panic:
	push	.msg
	call	Terminal_Print
.loop:
	cli
	hlt
	jmp	.loop


.msg db "Kernal panic...",0

align 16
stackEnd: times 256 db 0
stackBegin:

%include "Terminal.asm"
%include "Memory.asm"

KERNEL_END equ $-$$ + 0x500
