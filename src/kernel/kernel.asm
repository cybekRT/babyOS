[bits 16]
[org 0x500]
[CPU 386]

KERNEL_BEGIN:
	mov	dl, [0x7C00 + FAT12_BPB.driveNumber]
	mov	[driveNumber], dl
	mov	bp, 0
	call	init

%include "../global.inc"
%include "Interrupt.inc"
%include "Terminal.asm"
%include "Memory.asm"
%include "FAT12.asm"

hdir dw 0
printEntryStr db "File: %s",0xA,0
INT_DIRECTORY db "INT        "
INT_EXTENSION db "INT"
foundIntDirStr db "Found directory: INT",0xA,0
foundIntStr db "  Found interrupt: %u",0xA,0
driveNumber db 0

init:
	push	bp
	mov	bp, sp

	cli
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
	call	FAT12_OpenRoot

	mov	cx, 8
.readLoop:
	call	FAT12_ReadDirectory

	;mov	bx, [cs:fatEntry]
	;shl	bx, 4
	;mov	byte [bx + FAT12_DirectoryEntry.attributes], 0
	;push	bx
	;push	printEntryStr
	;call	printf
	;add	sp, 4

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
	call	printf
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

	push	word [es : FAT12_DirectoryEntry.size]
	push	foundIntStr
	call	printf
	add	sp, 4
	call	ReadWholeFile

	push	ax
	push	0
	mov	bx, sp
	call	far [ss:bx]
	add	sp, 4

.endOfLoop:
	dec	cx
	jnz	.readLoop
	;loop	.readLoop

	;push	word [hdir]
	;call	FAT12_CloseDirectory
	;add	sp, 2

	push	word [cs:fatPtr]
	ApiCall	INT_API_MEMORY, MEMORY_FREE

	;push	4096
	push	4608
	ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES

	push	1
	ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES

	push	17
	ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	push	ax

	push	1
	ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	add	sp, 2

	ApiCall	INT_API_MEMORY, MEMORY_FREE

	push	1
	ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES

	ApiCall INT_API_PANIC

	sti
.kbdTest:
	hlt
	ApiCall	INT_API_KEYBOARD, 0
	test	ax, ax
	jz	.kbdTest
	ApiCall	INT_API_KEYBOARD, 1
	push	ax
	push	ax
	push	.x
	call	printf
	add	sp, 6

	cmp	ax, '0'
	je	Panic
	jne	.kbdTest

.x db "Pressed: %x (%c)",0xA,0

Panic:
	ApiCall INT_API_PANIC


align 16
stackEnd: times 2048 db 0 ; If stack is too small, callStackEndMsg will be overwritten... 32 is too small
stackBegin:
KERNEL_END equ $-$$ + 0x500
