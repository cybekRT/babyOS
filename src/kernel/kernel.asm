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

;istruc IDT
;	at IDT.offset_0_15, dw INT_0
;	at IDT.selector, dw 0x8
;	at IDT.unused, db 0
;	at IDT.flags, db (IDT_FLAG_32BIT_INT_GATE | IDT_FLAG_STORAGE_SEGMENT | IDT_FLAG_RING_0 | IDT_FLAG_ENTRY_PRESENT)
;	at IDT.offset_16_31, dw 0
;iend

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

	mov	eax, IDT_data
	add	eax, IDT_size * INT_GENERAL_PROTECTION_FAULT

	mov	ebx, INT_0D

	mov	word [eax + IDT.offset_0_15], bx
	shl	ebx, 16
	mov	word [eax + IDT.offset_16_31], bx

	mov	word [eax + IDT.selector], 0x8
	mov	byte [eax + IDT.flags], (IDT_FLAG_32BIT_INT_GATE | IDT_FLAG_STORAGE_SEGMENT | IDT_FLAG_RING_0 | IDT_FLAG_ENTRY_PRESENT)

	mov	eax, 0xa0000
	mov	ecx, 320*200
	mov	byte [eax+0], 'P'
	mov	byte [eax+2], 'M'
	mov	byte [eax+4], ' '

.loop:
	mov	byte [eax], 0x3
	inc	eax
	loop	.loop

	;xchg	bx, bx
	;int	0

	call	Terminal_Init

	mov	ecx, 64
.x
	push	'0'
	call	Terminal_Put
	push	'1'
	call	Terminal_Put
	push	'2'
	call	Terminal_Put
	push	'3'
	call	Terminal_Put
	push	'4'
	call	Terminal_Put
	push	'5'
	call	Terminal_Put
	push	'6'
	call	Terminal_Put
	push	'7'
	call	Terminal_Put
	push	'8'
	call	Terminal_Put
	push	'9'
	call	Terminal_Put
	push	'A'
	call	Terminal_Put
	push	'B'
	call	Terminal_Put
	push	'C'
	call	Terminal_Put
	push	'D'
	call	Terminal_Put
	push	'E'
	call	Terminal_Put
	push	'F'
	call	Terminal_Put
	add	esp, 64

	dec	ecx
	jnz	.x

	xchg	bx, bx
	hlt
	jmp PMode_main

INT_0:
	rpush	eax

	mov	eax, 0xa0000
	mov	byte [eax], 0

	rpop
	iret

INT_0D:
	mov	eax, 0xa0000
	mov	dword [eax+0], 0
	mov	dword [eax+4], 0
	mov	dword [eax+8], 0
	mov	dword [eax+16], 0

	jmp	$

align 16
stackEnd: times 256 db 0 ; If stack is too small, callStackEndMsg will be overwritten... 32 is too small
stackBegin:

%include "Terminal.asm"

KERNEL_END equ $-$$ + 0x500
