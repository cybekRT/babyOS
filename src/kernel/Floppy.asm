FDD_REG_STATUS_A	equ 0x3F0 ; RO
FDD_REG_STATUS_B	equ 0x3F1 ; RO
FDD_REG_DIGITAL_OUT	equ 0x3F2
FDD_REG_TAPE_DRIVE	equ 0x3F3
FDD_REG_MAIN_STATUS	equ 0x3F4 ; RO
FDD_REG_DATARATE_SELECT	equ 0x3F4 ; WO
FDD_REG_DATA_FIFO	equ 0x3F5
FDD_REG_DIGITAL_IN	equ 0x3F7 ; RO
FDD_REG_CONF_CONTROL	equ 0x3F7 ; WO

FDD_DOR_DSELA		equ (0b00 << 0)
FDD_DOR_DSELB		equ (0b01 << 0)
FDD_DOR_DSELC		equ (0b10 << 0)
FDD_DOR_DSELD		equ (0b11 << 0)

FDD_DOR_RESET		equ (1 << 2)
FDD_DOR_IRQ		equ (1 << 3)
FDD_DOR_MOTA		equ (1 << 4)
FDD_DOR_MOTB		equ (1 << 5)
FDD_DOR_MOTC		equ (1 << 6)
FDD_DOR_MOTD		equ (1 << 7)

FDD_MSR_ACTA		equ (1 << 0) ; Drive 0 is seeking
FDD_MSR_ACTB		equ (1 << 1) ; Drive 1 is seeking
FDD_MSR_ACTC		equ (1 << 2) ; Drive 2 is seeking
FDD_MSR_ACTD		equ (1 << 3) ; Drive 3 is seeking
FDD_MSR_CB		equ (1 << 4) ; Command Busy: set when command byte received, cleared at end of Result phase
FDD_MSR_NDMA		equ (1 << 5) ; Set in Execution phase of PIO mode read/write commands only
FDD_MSR_DIO		equ (1 << 6) ; Set if FIFO IO port expects an IN opcode
FDD_MSR_RQM		equ (1 << 7) ; Set if it's OK (or mandatory) to exchange bytes with the FIFO IO port

FDD_DSR_TYPE_144	equ (0b00 << 0) ; 1.44MB
FDD_DSR_TYPE_288	equ (0b11 << 0) ; 2.88MB

FDD_DIR_MEDIA_CHANGED	equ (1 << 7) ; media changed



FDD_CMD_READ_TRACK equ                 2;	// generates IRQ6
FDD_CMD_SPECIFY equ                    3;      // * set drive parameters
FDD_CMD_SENSE_DRIVE_STATUS equ         4;
FDD_CMD_WRITE_DATA equ                 5;      // * write to the disk
FDD_CMD_READ_DATA equ                  6;      // * read from the disk
FDD_CMD_RECALIBRATE equ                7;      // * seek to cylinder 0
FDD_CMD_SENSE_INTERRUPT equ            8;      // * ack IRQ6; get status of last command
FDD_CMD_WRITE_DELETED_DATA equ         9;
FDD_CMD_READ_ID equ                    10;	// generates IRQ6
FDD_CMD_READ_DELETED_DATA equ          12;
FDD_CMD_FORMAT_TRACK equ               13;     // *
FDD_CMD_DUMPREG equ                    14;
FDD_CMD_SEEK equ                       15;     // * seek both heads to cylinder X
FDD_CMD_VERSION equ                    16;	// * used during initialization; once
FDD_CMD_SCAN_EQUAL equ                 17;
FDD_CMD_PERPENDICULAR_MODE equ         18;	// * used during initialization; once; maybe
FDD_CMD_CONFIGURE equ                  19;     // * set controller parameters
FDD_CMD_LOCK equ                       20;     // * protect controller params from a reset
FDD_CMD_VERIFY equ                     22;
FDD_CMD_SCAN_LOW_OR_EQUAL equ          25;
FDD_CMD_SCAN_HIGH_OR_EQUAL equ         29;

FDD_CMD_OPTION_MULTITRACK		equ 0x80
FDD_CMD_OPTION_MFM			equ 0x40
FDD_CMD_OPTION_SKIP			equ 0x20

%macro fdd_wait_irq 0
pushf
sti
%%wait:
	hlt
	cmp	[fdd_irq], byte 0
	jz	%%wait
	mov	[fdd_irq], byte 0
popf
%endmacro

%macro fdd_wait_ready_out 0
	push	eax
	push	edx
%%loop:
	mov	dx, FDD_REG_MAIN_STATUS
	in	al, dx
	test	al, FDD_MSR_RQM
	jz	%%loop
	test	al, FDD_MSR_DIO
	jnz	%%loop
	jmp	%%ok
%%ok:
	pop	edx
	pop	eax
%endmacro

%macro fdd_wait_ready_in 0
	push	eax
	push	edx
%%loop:
	mov	dx, FDD_REG_MAIN_STATUS
	in	al, dx
	test	al, FDD_MSR_RQM
	jz	%%loop
	test	al, FDD_MSR_DIO
	jz	%%loop
	;test	al, FDD_MSR_CB
	;jnz	%%loop
	jmp	%%ok
%%ok:
	pop	edx
	pop	eax
%endmacro

%macro fdd_exec 1-*
	fdd_wait_ready_out

	mov	ebx, 0
	mov	edx, 0

	mov	dx, FDD_REG_DATA_FIFO
	mov	al, %1
	out	dx, al

	; push	eax
	; push	edx
	; push	outo
	; call	Terminal_Print
	; add	esp, 12

	%rep %0-1
		%rotate 1
		fdd_wait_ready_out
		mov	al, %1
		out	dx, al

		; push	eax
		; push	edx
		; push	outo
		; call	Terminal_Print
		; add	esp, 12
	%endrep
%endmacro

%macro fdd_read 1
	;push	eax
	push	edx

	fdd_wait_ready_in
	mov	dx, FDD_REG_DATA_FIFO
	in	%1, dx

	pop	edx
	;pop	eax
%endmacro

outo db "Port: %x, Out: %x",0xA,0

;buffer dd 0
buffer times 1024 db 0
fdd_irq db 0

Floppy_Init:
	;push	512 * 2880
	;call	Memory_Alloc
	;add	esp, 4
	;mov	[buffer], eax

	push	IRQ2INT(IRQ_FLOPPY)
	push	Floppy_IRQ
	call	IDT_RegisterISR
	add	esp, 8
	sti

	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, 0x00
	out	dx, al

	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, 0x0C
	out	dx, al

;.reset_loop:
;	hlt
;	cmp	[fdd_irq], byte 0
;	jz	.reset_loop
;	mov	[fdd_irq], byte 0
	;fdd_wait_irq
	fdd_wait_ready_out

	; select data rate
	mov	dx, FDD_REG_DATARATE_SELECT
	mov	al, FDD_DSR_TYPE_144
	out	dx, al

	; select
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, FDD_DOR_DSELA | FDD_DOR_MOTA
	
	;push	30000
	;call	Timer_Delay
	;add	esp, 4

	mov	eax, 0
	mov	dx, FDD_REG_MAIN_STATUS
	in	al, dx

	push	eax
	push	.status
	call	Terminal_Print
	add	esp, 8

	; version
	;mov	dx, FDD_REG_DATA_FIFO
	;mov	al, FDD_CMD_VERSION
	;out	dx, al

	mov	eax, 0
	;in	al, dx
	fdd_exec FDD_CMD_VERSION
	fdd_read al

	push	eax
	push	.version
	call	Terminal_Print
	add	esp, 8

	; configure
	fdd_exec FDD_CMD_CONFIGURE, 0, (1 << 6) | (0 << 5) | (0 << 4) | (8), 0
	; lock
	fdd_exec FDD_CMD_OPTION_MULTITRACK | FDD_CMD_LOCK
	mov	eax, 0
	fdd_read al
	push	eax
	push	.lock
	call	Terminal_Print
	add	esp, 8
	; reset
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, 0x00
	out	dx, al
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, 0x0C
	out	dx, al
	;fdd_wait_irq
	; recalibrate
	fdd_exec FDD_CMD_RECALIBRATE, 0
	;fdd_read al

	;fdd_wait_irq




	; select data rate
	mov	dx, FDD_REG_DATARATE_SELECT
	mov	al, FDD_DSR_TYPE_144
	out	dx, al

	; select
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, FDD_DOR_DSELA | FDD_DOR_MOTA


	ret

.status db "FDD Status: %b",0xA,0
.version db "FDD Version: %x",0xA,0
.lock db "FDD Lock: %x",0xA,0

Floppy_IRQ:
	mov	[fdd_irq], byte 1

	mov	al, 0x20
	out	0x20, al

	iret

Floppy_Read:
	fdd_wait_ready_out

	push	.msg
	call	Terminal_Print
	add	esp, 4

	fdd_exec FDD_CMD_OPTION_MFM | FDD_CMD_OPTION_MULTITRACK | FDD_CMD_READ_DATA, (0 << 2) | 0, 0, 0, 1, 2, 2, 0x1b, 0xff

	mov	eax, buffer
.loop:
	fdd_wait_ready_in

	mov	dx, FDD_REG_DATA_FIFO
	in	al, dx

	mov	[eax], al
	inc	eax

	movzx	ebx, al
	push	ebx
	push	.msg2
	call	Terminal_Print
	add	esp, 8

	;hlt
	jmp	.loop

	ret
.msg db "Reading: ",0
.msg2 db "%x ",0