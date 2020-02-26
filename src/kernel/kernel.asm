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

	; Initialize rest of kernel services
	print	"Init scheduler"
	call	Process_Init
	print	"Init timer"
	call	Timer_Init
	
	print	"Init floppy"
	call	Floppy_Init
	print	"Floppy inited!"

	call	FAT12_Init
	call	FAT12_OpenRoot

	call	FAT12_ReadDirectory
	call	FAT12_ReadDirectory
	call	FAT12_ReadDirectory
	call	FAT12_ReadDirectory
	call	FAT12_ReadDirectory
	call	FAT12_ReadDirectory
	call	FAT12_ReadDirectory
	call	FAT12_ReadWholeFile

	;call	eax
	;push	eax
	;call	Process_Spawn
	;add	esp, 4

	push	eax
	call	Terminal_Print
	add	esp, 4
sti
	; ; Alloc
	; push	2048
	; call	Memory_Alloc
	; add	esp, 4
	; call	Memory_PrintInfo

	; ; Alloc
	; push	1024
	; call	Memory_Alloc
	; add	esp, 4
	; call	Memory_PrintInfo

	; ; Free
	; push	32+8
	; call	Memory_Free
	; add	esp, 4
	; call	Memory_PrintInfo

	; ; Free
	; push	32+8+2048+8
	; call	Memory_Free
	; add	esp, 4
	; call	Memory_PrintInfo

	;push	.yolo
	;call	Terminal_Print
	;add	esp, 4

	sti
	; Spawn some processes...
	print	"Start A"
	push	dword PidA
	xchg	bx, bx
	call	Process_Spawn
	add	esp, 4

	print	"Start B"
	push	PidB
	call	Process_Spawn
	add	esp, 4

	;xchg bx, bx
	print	"Started inactivity loop..."
	sti
.xxx:
	push	dword [tmp_value2]
	push	dword [tmp_value1]
	push	dword [tmp_value]
	push	.tmp
	call	Terminal_Print
	add	esp, 16

	;xchg bx, bx
	push	dword 1000
	;call	Timer_Delay
	add	esp, 4

	inc	dword [tmp_value]

	hlt
	jmp	.xxx

	; End of kernel, halt :(
	push	.end_of_kernel
	call	Terminal_Print
	hlt
	jmp	$-1
.end_of_kernel db 0xA,"Kernel halted... :(",0
.tmp db "Value: (%p) %u - %u",0xD,0
.yolo db 0xA,"====================",0xA,"=       SPAWN      =",0xA,"====================",0xA,0xA,0
tmp_value dd 0
tmp_value1 dd 0
tmp_value2 dd 0

PidA:
	;sti
	push	1000
	;call	Timer_Delay
	add	esp, 4

	inc	dword [tmp_value1]
	jmp	PidA

PidB:
	;sti
	push	3000
	;call	Timer_Delay
	add	esp, 4

	inc	dword [tmp_value2]
	jmp	PidB

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
%include "Timer.asm"
%include "Process.asm"
%include "Floppy.asm"
%include "FAT12.asm"

align 32

;yoloBuffer times 512*20 db 0
;yoloBuffer db 0

KERNEL_END equ $-$$ + 0x500 ;+ (512 * 20)

%if KERNEL_END >= 0x7c00
	%error "Kernel too big!"
%endif