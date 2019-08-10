[bits 16]
[org 0x500]
[cpu 386]

KERNEL_BEGIN:
	cli

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;xor ax, ax
	;mov ds, ax
;
;	cli
;	lgdt	[gdt_desc]
;;
;	mov	eax, cr0
;	or	eax, 1
;	mov	cr0, eax
;
;	jmp	0x8:X_PMode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	mov	[driveNumber], dl
	mov	bp, 0
	call	Init

%include "../global.inc"
%include "Interrupt.inc"
%include "Terminal.asm"
%include "Memory.asm"
%include "FAT12.asm"

driveNumber db 0

;;;;;;;;;;
;
; Kernel entry point
;
;;;;;;;;;;
Init:
	push	bp
	mov	bp, sp

	mov	bx, 0;cs
	mov	ds, bx
	mov	es, bx
	mov	ss, bx
	mov	sp, stackBegin

	call	Terminal_Init
	call	Memory_Init

	; Alloc memory for stack
	push	2048
	ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	mov	ss, ax
	mov	sp, 2048

	; Init FAT12
	call	FAT12_Init

	call	LoadISR

	;jmp $
	;jmp	KeyboardTester

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax, 3
	int	10h

	xor ax, ax
	mov ds, ax

	cli
	lgdt	[gdt_desc]

	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	push	0x10
	pop	ds

	jmp	0x8:X_PMode

	GDT_FLAG_CODE_READ		equ (1 << 1)
GDT_FLAG_DATA_WRITE		equ (1 << 1)
GDT_FLAG_CONFORMING		equ (1 << 2)
GDT_FLAG_SEG_DATA		equ (0 << 3)
GDT_FLAG_SEG_CODE		equ (1 << 3) ; executable bit
GDT_FLAG_SEG_CODE_OR_DATA	equ (1 << 4)

GDT_FLAG_RING_0			equ (0b00 << 5)
GDT_FLAG_RING_1			equ (0b01 << 5)
GDT_FLAG_RING_2			equ (0b10 << 5)
GDT_FLAG_RING_3			equ (0b11 << 5)

GDT_FLAG_ENTRY_PRESENT		equ (1 << 7)

GDT_ATTRIBUTE_UNUSED		equ (1 << 4)
GDT_ATTRIBUTE_32BIT_SIZE	equ (1 << 6)
GDT_ATTRIBUTE_GRANULARITY	equ (1 << 7)

struc GDT
	.limit_0_15 resw 1,
	.base_0_15 resw 1,
	.base_16_23 resb 1,
	.flags resb 1,
	.limit_16_19_attributes resb 1,
	.base_24_31 resb 1
endstruc

v_gdt:
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
	at GDT.limit_0_15, dw 0xffff;
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_DATA_WRITE | GDT_FLAG_SEG_DATA | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend
v_gdt_end

gdt_desc:
	dw (v_gdt_end - v_gdt)
	dd v_gdt

[bits 32]
X_PMode:
	mov	eax, 0xb8000
	mov	byte [eax+0], 'P'
	mov	byte [eax+2], 'M'
	mov	byte [eax+4], ' '

	xchg	bx, bx
	hlt
	jmp X_PMode
[bits 16]
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	call	KeyboardTester

	jmp	Panic

;;;;;;;;;;
;
; Kernel panic
;
;;;;;;;;;;
Panic:
	ApiCall INT_API_PANIC

;;;;;;;;;;
;
; Load interrupts service routines
;
;;;;;;;;;;
LoadISR:
	call	FAT12_OpenRoot
	mov	cx, 8
.readLoop:
	call	FAT12_ReadDirectory

	push	cx
	mov	bx, 0
	mov	ds, bx
	mov	si, INT_DIRECTORY
	push	word [cs:fatEntry]
	pop	es
	mov	di, FAT12_DirectoryEntry.name
	mov	cx, 11
	repe	cmpsb
	pop	cx

	jne	.invalidName

	push	foundIntDirStr
	;call	printf
	add	sp, 2

	call	FAT12_ChangeDirectory
	mov	cx, 8
	jmp	.readLoop

.invalidName:
	; check for files...
	push	cx
	mov	bx, 0
	mov	ds, bx
	mov	si, INT_EXTENSION
	push	word [cs:fatEntry]
	pop	es
	mov	di, FAT12_DirectoryEntry.name
	add	di, 8
	mov	cx, 3
	repe	cmpsb
	pop	cx
	jne	.endOfLoop

	call	FAT12_ReadWholeFile

	push	ax
	push	word 0x0
	mov	bx, sp
	mov	ds, ax
	call	far [ss:bx]
	add	sp, 4

	;xchg bx, bx

.endOfLoop:
	dec	cx
	jnz	.readLoop

	ret

;hdir dw 0
printEntryStr db "File: %s",0xA,0
INT_DIRECTORY db "INT        "
INT_EXTENSION db "INT"
foundIntDirStr db "Found directory: INT",0xA,0
foundIntStr db "  Found interrupt: %u",0xA,0

;;;;;;;;;;
;
; Keyboard testing routine
;
;;;;;;;;;;
KeyboardTester:
	push	cs
	pop	ds

	sti
.loop:
	hlt
	ApiCall	INT_API_KEYBOARD, 0
	test	ax, ax
	jz	.loop
	ApiCall	INT_API_KEYBOARD, 1
	push ax
	push	ax
	push	ax
	push	.x
	call	printf
	add	sp, 6

	pop ax
	cmp	ax, '0'
	je	Panic
	jne	.loop
.x db "Pressed: %x (%c)",0xA,0


align 16
stackEnd: times 128 db 0 ; If stack is too small, callStackEndMsg will be overwritten... 32 is too small
stackBegin:
KERNEL_END equ $-$$ + 0x500
