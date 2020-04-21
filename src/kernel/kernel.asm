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

	call	LinkedList_Create
	mov	[kernelHandlers], eax

	; Initialize rest of kernel services
	print	"Init scheduler"
	call	Process_Init
	print	"Init timer"
	call	Timer_Init

	print	"Init keyboard"
	call	Keyboard_Init
	
	;print	"Init floppy"
	;call	Floppy_Init

	;print	"Init FAT12"
	;call	FAT12_Init

	print	"Started inactivity loop..."
	sti
.inactivity:
	hlt
	call	Kernel_ExecuteHandlers
	jmp	.inactivity

stackEnd:
times 512 db 0
stackBegin:

struc KernelHandlerItem
	.handler	resd 1,
	.next	resd 1
endstruc

kernelHandlers dd 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Register kernel function
; Arguments:
;	(ebp + 8)	- handler
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Kernel_Register:
	rpush	ebp

	push	dword [kernelHandlers]
	push	dword [ebp + 8]
	call	LinkedList_Insert
	add	esp, 8

	rpop
	ret

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

Kernel_Unregister:
	rpush	ebp, ebx

	; TODO

	rpop
	ret

Kernel_ExecuteHandlers:
;	mov	dword [.iteratePointer], 0
;
;	push	dword [kernelHandlers]
;	push	dword .iteratePointer
;.loop:
;	call	LinkedList_Iterate
;	cmp	eax, 0
;	jz	.exit
;
;	print	"Call"
;	call	dword [.iteratePointer]
;	jmp	.loop
;
;.exit:
;	add	esp, 8
;	ret

	mov	eax, [kernelHandlers]
.loop:
	cmp	dword [eax + LinkedList.next], 0
	jz	.exit

	mov	eax, [eax + LinkedList.next]
	mov	ebx, [eax + LinkedList.data]
	push	eax
	call	ebx
	pop	eax
.exit:
	ret

	mov	eax, [kernelHandlers]
;.loop:
	cmp	eax, 0
	jz	.exit

	push	dword [eax + KernelHandlerItem.next]
	mov	ebx, dword [eax + KernelHandlerItem.handler]

	call	ebx

	pop	eax
	jmp	.loop

;.exit:
	ret
.msg db "Address: %p",0xA,0
.iteratePointer dd 0

%include "GDT.asm"
%include "IDT.asm"
%include "Terminal.asm"
%include "Memory.asm"
%include "Timer.asm"
%include "Process.asm"
%include "Floppy.asm"
%include "FAT12.asm"
%include "Panic.asm"
%include "LinkedList.asm"

%include "Keyboard.inc"
%include "Keyboard.asm"

align 32

KERNEL_END equ $-$$ + 0x500 ;+ (512 * 20)

%if KERNEL_END >= 0x7c00
	%error "Kernel too big!"
%endif