[bits 16]
[org 0x500]
[cpu 386]

KERNEL_BEGIN:
	mov	[driveNumber], dl
	jmp	Init16

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
Init16:
	cli

	mov	bx, 0
	mov	ds, bx
	mov	es, bx
	mov	ss, bx
	mov	sp, stackBegin

	; Init mode 13h
	mov	ax, 0x13
	int	0x10

	; 16-bit initialization
	call	Memory_PreInit
	call	GDT_PreInit
	call	IDT_PreInit

	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	jmp	0x8:Init32

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Protected Mode - entry
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[bits 32]
tmpBuffer times 1024 db 0
Init32:
	cli

	mov	bx, 0x10
	mov	ds, bx
	mov	es, bx
	mov	fs, bx
	mov	gs, bx
	mov	ss, bx
	mov	esp, stackBegin

	; Init CPU
	call	GDT_Init
	call	IDT_Init

	; Initialize kernel main services
	call	Terminal_Init
	print	"Memory init"
	call	Memory_Init

	; Alloc stack
	print	"Allocating stack!"
	push	8192
	call	Memory_Alloc
	add	eax, 8192
	mov	esp, eax

	call	Timer_Init
	call	Floppy_Init

	print "=== Reading A ==="
	mov	ch, 0
	mov	cl, 1
	mov	dh, 0
	mov	dl, 0
	mov	di, bufferA
	call	Floppy_Read

	push	bufferA
	call	Terminal_Print
	add	esp, 4

	print "=== Reading B ==="
	mov	ch, 0
	mov	cl, 2
	mov	dh, 0
	mov	dl, 0
	mov	di, bufferB
	call	Floppy_Read

	print "=== OK ==="
	cli
	hlt
	jmp	Panic

align 16
db "================"
db "====Sector A===="
db "================"
bufferA times 512 db 0
db "================"
db "====Sector B===="
db "================"
bufferB times 512 db 0
db "================"

Panic:
	pushf
	push	dword [esp + 4] ; eip

	;mov	eax, [esp + 4]
	;xchg	bx, bx

	push	esp
	push	ebp
	push	edi
	push	esi
	push	edx
	push	ecx
	push	ebx
	push	eax
	push	.panicMsg

.fill_background:
	mov	al, 10
	mov	edi, 0xa0000
	mov	ecx, 320*200
	;rep	stosb

	;call	Terminal_Init
	call	Terminal_Print
	add	esp, 11*4

.background:
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

	; Halt
	cli
	hlt
	jmp	$-1

.panicMsg db "Kernel panic...",0xA,0xA
db "  EAX:   %p",0xA
db "  EBX:   %p",0xA
db "  ECX:   %p",0xA
db "  EDX:   %p",0xA
db "  ESI:   %p",0xA
db "  EDI:   %p",0xA
db "  EBP:   %p",0xA
db "  ESP:   %p",0xA
db "  EIP:   %p",0xA
db "  Flags: %x"
db 0

align 16
times 32 db 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF
stackEnd:
times 512 db 0
stackBegin:
times 32 db 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF

%include "GDT.asm"
%include "IDT.asm"
%include "Terminal.asm"
%include "Memory.asm"
%include "Floppy.asm"
%include "Timer.asm"

align 32

KERNEL_END equ $-$$ + 0x500 ;+ (512 * 20)

%if KERNEL_END >= 0x7c00
	%error "Kernel too big!"
%endif