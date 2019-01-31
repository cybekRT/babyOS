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
kernelEndStr db "Kernel end at: %x",0xA,0
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
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	mov	ss, ax
	mov	sp, 2048

	push	KERNEL_END
	push	kernelEndStr
	call	printf
	add	sp, 4

	; Init FAT12
	call	FAT12_Init
	call	FAT12_OpenRoot

	mov	cx, 8
.readLoop:
	call	FAT12_ReadDirectory

	mov	bx, [cs:fatEntry]
	shl	bx, 4
	mov	byte [bx + FAT12_DirectoryEntry.attributes], 0
	push	bx
	push	printEntryStr
	call	printf
	add	sp, 4

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

	sti
.kbdTest:
	ApiCall	INT_API_KEYBOARD, 0
	test	ax, ax
	jz	.kbdTest
	ApiCall	INT_API_KEYBOARD, 1
	push	ax
	push	.x
	call	printf
	add	sp, 4

	cmp	ax, '0'
	je	halt
	jne	.kbdTest

.x db "Pressed: %c",0xA,0

halt:
	call	Panic

Panic:
	; [bp] - ip
	push	bp
	mov	bp, sp

	; dump
	push	word [bp]
	push	cs
	push	es
	push	ds
	push	sp
	push	ss
	push	di
	push	si
	push	dx
	push	cx
	push	bx
	push	ax
	push	panicMsg
	call	printf

	call	Memory_PrintMap

	; Print callstack msg
	push	callStackMsg
	call	printf
	add	sp, 2

	; Print callstack entries
.csLoop:
	mov	ax, [bp+2]
	sub	ax, 0x500
	push	ax
	push	word [bp+2]
	push	word [bp+4]
	push	callStackEntryMsg
	call	printf
	add	sp, 8

	;jmp $

	mov	sp, bp
	pop	bp
	test	bp, bp
	jnz	.csLoop

	; Print footer
	push	callStackEndMsg
	call	printf
	add	sp, 2

	cli
	hlt
	jmp	Panic

panicMsg db 0xA,'Kernel halted!',0xA,\
	'Registers:',0xA,\
	'	AX: %x	BX: %x',0xA,\
	'	CX: %x	DX: %x',0xA,\
	'	SI: %x	DI: %x',0xA,\
	'	SS: %x	SP: %x',0xA,\
	'	DS: %x	ES: %x',0xA,\
	'	CS: %x	IP: %x',0xA,0xA,0

callStackMsg db 0xA,'Call stack:',0xA,0
callStackEntryMsg db "    ^   (%X:)%X ( %X )",0xA,0
callStackEndMsg db   "    --     bootloader     --",0xA,0

stackEnd: times 32 db 0
stackBegin:
KERNEL_END equ $-$$ + 0x500
