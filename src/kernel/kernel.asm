[bits 16]
[org 0x500]
[CPU 386]

KERNEL_BEGIN:
	jmp	init

%include "../global.inc"
%include "Interrupt.inc"
%include "Terminal.asm"
%include "Memory.asm"
%include "FAT12.asm"
;%include "Keyboard.asm"

hdir dw 0
printEntryStr db "File: %s",0xA,0
INT_DIRECTORY db "INT        "
INT_EXTENSION db "INT"
foundIntDirStr db "Found directory: INT",0xA,0
foundIntStr db "  Found interrupt: %u",0xA,0
kernelEndStr db "Kernel end at: %x",0xA,0

init:
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
	;call	Memory_AllocBytes
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
	;mov	[hdir], ax

	mov	cx, 8
.readLoop:
	call	FAT12_ReadDirectory
	;mov	byte [fatEntry + FAT12_DirectoryEntry.attributes], 0
	mov	bx, [fatEntry]
	add	bx, FAT12_DirectoryEntry.attributes
	mov	byte [bx], 0
	push	word [fatEntry]
	push	printEntryStr
	;call	printf
	add	sp, 4

	push	cx
	mov	bx, 0
	mov	es, bx
	mov	ds, bx
	mov	si, INT_DIRECTORY
	mov	di, [fatEntry]
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
	mov	es, bx
	mov	ds, bx
	mov	si, INT_EXTENSION
	mov	di, [fatEntry]
	add	di, 8
	mov	cx, 3
	repe	cmpsb
	pop	cx
	jne	.endOfLoop

	mov	bx, [fatEntry]
	push	word [bx + FAT12_DirectoryEntry.size]
	push	foundIntStr
	call	printf
	add	sp, 4
	call	ReadWholeFile

	;mov	es, ax
	;mov	cs, ax
	;jmp	0
	;jmp	0

	push	ax
	push	0
	;retf
	;call	ax:0
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

	; Keyboard
	;call	Keyboard_Init

	sti
.kbdTest:
	ApiCall	INT_API_KEYBOARD, 0
	test	ax, ax
	;jmp	$
	jz	.kbdTest
	ApiCall	INT_API_KEYBOARD, 1
	push	ax
	push	.x
	call	printf
	;add	sp, 4

	add	sp, 4
	cmp	ax, '0'
	je	halt


;	mov	al, 0xb6
;	out	0x43, al
;
;	mov	al, 0x51
;	out	0x42, al
;
;	mov	al, 0x22
;	out	0x42, al
;
;	in	al, 0x61
;	or	al, 3
;	out	0x61, al

;	mov	cx, 0xffff
;.zz:
;	push	cx
;	mov	cx, 0xf
;.zz2:
;	loop	.zz2
;	pop	cx
;	loop	.zz

;	and	al, ~3
;	out	0x61, al





	
	jmp	.kbdTest

.x db "Pressed: %c",0xA,0

	;sti

halt:
	;cli
	;hlt
	;jmp	halt
	call	Panic
.test:
	hlt
	;call	Keyboard_GetBufferLength
	cmp	ax, 0
	jz	.test

	mov	bx, ax
	;call	Keyboard_GetChar
	jc	.test
	push	ax
	push	bx
	push	.buff
	call	printf
	add	sp, 6
	jmp	.test
.bufsizestr db 'Buffer: %d  ', 0xD,0
.buff db "Buffer %d, %c",0xA,0

	call	Panic

Panic:
	;call	Memory_PrintMap

	; [bp] - ip
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

	cli
	hlt
	jmp	Panic

panicMsg: db 0xA,'Kernel halted!',0xA,\
	'Registers:',0xA,\
	'	AX: %x	BX: %x',0xA,\
	'	CX: %x	DX: %x',0xA,\
	'	SI: %x	DI: %x',0xA,\
	'	SS: %x	SP: %x',0xA,\
	'	DS: %x	ES: %x',0xA,\
	'	CS: %x	IP: %x',0xA,0

stackEnd: times 64 db 0
stackBegin:
KERNEL_END equ $-$$ + 0x500
