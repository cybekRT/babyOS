[bits 16]
[org 0x500]
[cpu 386]

KERNEL_BEGIN:
	cli
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
	push	word 0
	mov	bx, sp
	call	far [ss:bx]
	add	sp, 4

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
	sti
.loop:
	hlt
	ApiCall	INT_API_KEYBOARD, 0
	test	ax, ax
	jz	.loop
	ApiCall	INT_API_KEYBOARD, 1
	push	ax
	push	ax
	push	.x
	call	printf
	add	sp, 6

	cmp	ax, '0'
	je	Panic
	jne	.loop
.x db "Pressed: %x (%c)",0xA,0


align 16
stackEnd: times 128 db 0 ; If stack is too small, callStackEndMsg will be overwritten... 32 is too small
stackBegin:
KERNEL_END equ $-$$ + 0x500
