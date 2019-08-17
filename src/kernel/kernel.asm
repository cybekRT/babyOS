[bits 16]
[org 0x500]
[cpu 386]

KERNEL_BEGIN:
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
Init32:
	mov	bx, 0x10
	mov	ds, bx
	mov	es, bx
	mov	fs, bx
	mov	gs, bx
	mov	ss, bx
	mov	esp, stackBegin

	call	GDT_Init
	call	IDT_Init

	; Initialize kernel main services
	call	Terminal_Init
	call	Memory_Init

	call	Memory_PrintInfo

	; Alloc
	push	2048
	call	Memory_Alloc
	add	esp, 4
	call	Memory_PrintInfo

	; Alloc
	push	1024
	call	Memory_Alloc
	add	esp, 4
	call	Memory_PrintInfo

	; Free
	push	32
	call	Memory_Free
	add	esp, 4
	call	Memory_PrintInfo

	; Free
	push	32+2048+8
	call	Memory_Free
	add	esp, 4
	call	Memory_PrintInfo

	; End of kernel, halt :(
	push	.end_of_kernel
	call	Terminal_Print
	hlt
	jmp	$-1
.end_of_kernel db 0xA,"Kernel halted... :(",0

Panic:
	pushf
	push	dword [esp + 4]
	push	esp
	push	ebp
	push	edi
	push	esi
	push	edx
	push	ecx
	push	ebx
	push	eax
	push	.panicMsg
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
stackEnd: times 256 db 0
stackBegin:

%include "GDT.asm"
%include "IDT.asm"
%include "Terminal.asm"
%include "Memory.asm"

KERNEL_END equ $-$$ + 0x500
