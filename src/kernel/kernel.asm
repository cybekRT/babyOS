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

;.a:
;	push	.zzz
;	call	Terminal_Print
;	add	esp, 4
;
;	push	1000
;	call	Timer_Delay
;	add	esp, 4
;
;	jmp	.a
;.zzz db ".",0
	
	print	"Init floppy"
	;call	Floppy_Init
	print	"Floppy inited!"

	;call	FAT12_Init
	;call	FAT12_OpenRoot

	;call	FAT12_ReadDirectory
	;call	FAT12_ReadDirectory
	;call	FAT12_ReadDirectory
	;call	FAT12_ReadDirectory
	;call	FAT12_ReadDirectory
	;call	FAT12_ReadDirectory
	;call	FAT12_ReadDirectory
	;call	FAT12_ReadWholeFile

	call	Floppy_MotorOff

	;push	eax
	;call	Process_Spawn
	;add	esp, 4

	call	Keyboard_Init

	; Spawn some processes...
	print	"Start A"
	push	dword PidA
	call	Process_Spawn
	add	esp, 4

	print	"Start B"
	push	PidB
	call	Process_Spawn
	add	esp, 4

	print	"Start C"
	push	PidC
	call	Process_Spawn
	add	esp, 4

	print	"Start D"
	push	PidD
	call	Process_Spawn
	add	esp, 4

	print	"Started inactivity loop..."
	
	sti
.inactivity:
	hlt
	call	Kernel_ExecuteHandlers
	jmp	.inactivity

	; End of kernel, halt :(
	push	.end_of_kernel
	;call	Terminal_Print
	hlt
	jmp	$-1
.end_of_kernel db 0xA,"Kernel halted... :(",0
tmp_value dd 0
tmp_value1 dd 0
tmp_value2 dd 0

PidA:
	push	1000
	call	Timer_Delay
	add	esp, 4

	inc	dword [tmp_value1]
	jmp	PidA

PidB:
	push	3000
	call	Timer_Delay
	add	esp, 4

	inc	dword [tmp_value2]
	jmp	PidB

PidC:
	push	dword [tmp_value2]
	push	dword [tmp_value1]
	push	dword [tmp_value]
	push	.tmp
	call	Terminal_Print
	add	esp, 16

	push	dword 1000
	call	Timer_Delay
	add	esp, 4

	inc	dword [tmp_value]
	jmp	PidC
.tmp db "Value: (%p) %u - %u",0xD,0

PidD:
.loop:
	hlt

	call	Keyboard_ReadKey
	jc	.loop

	call	Keyboard_Key2AsciiLow
	movzx	eax, al
	push	eax
	push	.tmp
	call	Terminal_Print
	add	esp, 8

	jmp	PidD
.tmp db "%c",0
.upper db 0

align 16
times 32 db 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF
stackEnd:
times 512 db 0
stackBegin:
times 32 db 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF

struc KernelHandlerItem
	.handler	resd 1,
	.next	resd 1
endstruc

kernelHandlers dd 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Register kernel function
; Arguments:
; 	;eax	- handler
;	(ebp + 8)	- handler
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Kernel_Register:
	rpush	ebp, ebx

	mov	ebx, [ebp + 8]
	;mov	ebx, eax

	push	KernelHandlerItem_size
	call	Memory_Alloc
	add	esp, 4

	mov	dword [eax + KernelHandlerItem.handler], ebx
	mov	dword [eax + KernelHandlerItem.next], 0

	cmp	dword [kernelHandlers], 0
	jnz	.addToList

	mov	dword [kernelHandlers], eax
	jmp	.exit

.addToList:
	xchg bx, bx
	mov	ebx, eax
	mov	eax, [kernelHandlers]
.searchLastEntry:
	cmp	dword [eax + KernelHandlerItem.next], 0
	jz	.insertEntry
	push	dword [eax + KernelHandlerItem.next]
	pop	eax
	jmp	.searchLastEntry

.insertEntry:
	mov	dword [eax + KernelHandlerItem.next], ebx

	push	eax
	push	ebx
	push	.msg
	call	Terminal_Print
	add	esp, 12

.exit:
	rpop
	ret
.msg db "Inserted: %p at %p",0xA,0

Kernel_ExecuteHandlers:
	xchg bx, bx
	;print	"Executing handlers..."
	mov	eax, [kernelHandlers]

.loop:
	cmp	eax, 0
	jz	.exit

	push	dword [eax + KernelHandlerItem.next]
	mov	ebx, dword [eax + KernelHandlerItem.handler]

	;push	ebx
	;push	.msg
	;call	Terminal_Print
	;add	esp, 8

	call	ebx

	pop	eax
	jmp	.loop

.exit:
	ret
.msg db "Address: %p",0xA,0


%include "GDT.asm"
%include "IDT.asm"
%include "Terminal.asm"
%include "Memory.asm"
%include "Timer.asm"
%include "Process.asm"
%include "Floppy.asm"
%include "FAT12.asm"
%include "Panic.asm"

%include "Keyboard.inc"
%include "Keyboard.asm"

align 32

KERNEL_END equ $-$$ + 0x500 ;+ (512 * 20)

%if KERNEL_END >= 0x7c00
	%error "Kernel too big!"
%endif