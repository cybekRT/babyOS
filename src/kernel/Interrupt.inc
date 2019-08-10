;%include "interrupt_codes.inc"

;;;;;;;;;;;;;;;;;;;;
;
; IRQs list
;
;;;;;;;;;;;;;;;;;;;;

%define IRQ_TIMER	0
%define IRQ_KEYBOARD	1
%define IRQ_UNUSED	2
%define IRQ_COM2	3
%define IRQ_COM1	4
%define IRQ_LPT2	5
%define IRQ_FLOPPY	6
%define IRQ_LPT1	7
%define IRQ_RTC		8
%define IRQ_PERIPHERAL1	9
%define IRQ_PERIPHERAL2	10
%define IRQ_PERIPHERAL3	11
%define IRQ_MOUSE	12
%define IRQ_FPU		13
%define IRQ_ATA1	14
%define IRQ_ATA2	15

%define IRQ2INT(x) INT_IRQ %+ x

INT_IRQ0	equ 0x08
INT_IRQ1	equ 0x09
INT_IRQ2	equ 0x0A
INT_IRQ3	equ 0x0B
INT_IRQ4	equ 0x0C
INT_IRQ5	equ 0x0D
INT_IRQ6	equ 0x0E
INT_IRQ7	equ 0x0F

INT_IRQ8	equ 0x70
INT_IRQ9	equ 0x71
INT_IRQ10	equ 0x72
INT_IRQ11	equ 0x73
INT_IRQ12	equ 0x74
INT_IRQ13	equ 0x75
INT_IRQ14	equ 0x76
INT_IRQ15	equ 0x77

;;;;;;;;;;;;;;;;;;;;
;
; Interrupts list
;
;;;;;;;;;;;;;;;;;;;;

INT_DIVISION_BY_ZERO			equ 0x00
INT_SINGLE_STEP				equ 0x01
INT_NONMASKABLE				equ 0x02
INT_BREAKPOINT				equ 0x03
INT_OVERFLOW				equ 0x04
INT_BOUNDS				equ 0x05
INT_INVALID_OPCODE			equ 0x06
INT_NO_FPU				equ 0x07
INT_DOUBLE_FAULT			equ 0x08
INT_FPU_SEGMENT_OVERRUN			equ 0x09
INT_INVALID_TASK_STATE_SEGMENT		equ 0x0A
INT_INVALID_SEGMENT			equ 0x0B
INT_STACK_FAULT				equ 0x0C
INT_GENERAL_PROTECTION_FAULT		equ 0x0D
INT_PAGE_FAULT				equ 0x0E
INT_RESERVED				equ 0x0F
INT_MATH_FAULT				equ 0x10
INT_ALIGNMENT_CHECK			equ 0x11
INT_MACHINE_CHECK			equ 0x12
INT_FPU_EXCEPTION			equ 0x13
INT_VIRTUALIZATION_EXCEPTION		equ 0x14
INT_CONTROL_PROTECTION_EXCEPTION	equ 0x15

;;;;;;;;;;;;;;;;;;;;
;
; InterruptInfo
;
;;;;;;;;;;;;;;;;;;;;

%macro InterruptInfo 1-*
%define INT_MAIN_HANDLER MainHandler_ %+ %1

; Jump to interrupt installer
jmp	%1

;%$MainHandler:
INT_MAIN_HANDLER:
	cmp	al, (%0 - 1)
	jae	%%.fail

	;xchg	al, ah
	xor	ah, ah
	shl	ax, 2
	add	ax, %%.jmpTable
	push	ax
	ret
%%.jmpTable:
%rep (%0-1)
%rotate 1
	jmp	%1
	nop
%endrep
%%.fail:
	stc
	iret
%endmacro

;;;;;;;;;;;;;;;;;;;;
;
; InstallInterrupt
;
;;;;;;;;;;;;;;;;;;;;
%macro InstallInterrupt 1-2
	push	bx
	push	es

	mov	bx, 0
	mov	es, bx
%if %0 = 1
	mov	bx, INT_MAIN_HANDLER
%undef INT_MAIN_HANDLER
%elif %0 = 2
	mov	bx, %2
%else
%fatal Invalid interrupt installer
%endif

	mov	word [es:0 + (%1 * 4) + 0], bx
	mov	bx, cs
	mov	word [es:0 + (%1 * 4) + 2], bx

%if %0 = 1
	push	ds
	push	cs
	pop	ds
	push	%1
	push	%%.msg
	push	1
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT_ARGS
	add	sp, 6
	pop	ds

	jmp	%%.msg_g
%%.msg:
%if __BASE_FILENAME__ == "kernel"
%substr __FILE_BASE__ __FILE__ 12, -5
db "ISR: ", __FILE_BASE__, " (%X)", 0xA, 0
%else
db "ISR: ", __BASE_FILENAME__, " (%X)", 0xA, 0
%endif
%%.msg_g:

%endif

	pop	es
	pop	bx
%endmacro

;;;;;;;;;;;;;;;;;;;;
;
; ApiCall
;
;;;;;;;;;;;;;;;;;;;;

%macro ApiCall 1-2
%if %0 = 1
	mov	al, 0
%else
	mov	al, %2
%endif
	int	%1
%endmacro
