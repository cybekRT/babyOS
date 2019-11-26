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

timeoutMsg db "Floppy timeout...",0xA,0

%macro fdd_wait_irq 0
mov	[fdd_irq], byte 0
pushf
sti
%%wait:
	hlt
	cmp	[fdd_irq], byte 1
	jz	%%wait
popf
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Wait for FDD to be ready for OUT command
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro fdd_wait_ready_out 0
	push	eax
	push	ecx
	push	edx
	mov	ecx, 100
%%loop:
	mov	dx, FDD_REG_MAIN_STATUS
	in	al, dx
	and	al, 11000000b
	cmp	al, 10000000b
	jz	%%ok
	hlt
	loop	%%loop

	push	timeoutMsg
	call	Terminal_Print
	add	esp, 4
%%ok:
	pop	edx
	pop	ecx
	pop	eax
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Wait for FDD to be ready for IN command
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro fdd_wait_ready_in 0
	push	eax
	push	ecx
	push	edx
	mov	ecx, 100
%%loop:
	mov	dx, FDD_REG_MAIN_STATUS
	in	al, dx
	and	al, 11000000b
	cmp	al, 11000000b
	je	%%ok

	loop	%%loop

	push	timeoutMsg
	call	Terminal_Print
	add	esp, 4
%%ok:
	pop	edx
	pop	ecx
	pop	eax
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Writes one byte to FDD fifo buffer
; Arguments:
;	source/value of data byte
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro fdd_write 1
	fdd_wait_ready_out
	mov	dx, FDD_REG_DATA_FIFO
	%ifnidni %1, al
		mov	al, %1
	%endif
	out	dx, al
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Reads one byte from FDD fifo buffer
; Arguments:
;	destination of data byte
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro fdd_read 1
	fdd_wait_ready_in
	mov	dx, FDD_REG_DATA_FIFO
	in	al, dx
	%ifnidni %1, al
		mov	%1, al
	%endif
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Executes FDD command with specified parameters
; Arguments:
;	Command code
;	Arguments to command
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro fdd_exec 1-*
	push	eax
	push	edx

	%rep %0
		%if %1 = al || %1 = dl || %1 = dh
			%error Invalid register!
		%endif

		fdd_write %1
		%rotate 1
	%endrep

	pop	edx
	pop	eax
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Floppy IRQ
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_IRQ:
	or	[fdd_irq], byte 1

	push	ax
	mov	al, 0x20
	out	0x20, al
	pop	ax

	iret

outo db "Port: %x, Out: %x",0xA,0

;buffer dd 0
buffer times 512 db 0
fdd_irq db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Initializes FDD subsystem
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

	call	Floppy_Reset
	call	Floppy_Recalibrate
	call	Floppy_Lock
	ret

.status db "FDD Status: %b",0xA,0
.version db "FDD Version: %x",0xA,0
.lock db "FDD Lock: %x",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Internal
;
; Resets the floppy controller
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_Reset:
	; reset
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, !FDD_DOR_RESET; | FDD_DOR_IRQ
	out	dx, al

	; wait 10ms
	push	dword 10
	call	Timer_Delay
	add	esp, 4

	; datarate
	mov	dx, FDD_REG_DATARATE_SELECT
	mov	al, FDD_DSR_TYPE_144
	out	dx, al

	; un-reset
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, FDD_DOR_RESET; | FDD_DOR_IRQ
	out	dx, al


	mov	ecx, 4
.senseIrq:
	fdd_exec FDD_CMD_SENSE_INTERRUPT
	fdd_read al
	fdd_read al
	dec	ecx
	jnz	.senseIrq

	; Specify
	fdd_exec FDD_CMD_SPECIFY, 0xDF, 0x02
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Internal
;
; Recalibrates the FDD
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_Recalibrate:
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, FDD_DOR_RESET | FDD_DOR_MOTA | FDD_DOR_DSELA
	out	dx, al

	; wait for motor to start
	push	dword 100
	call	Timer_Delay
	add	esp, 4

	mov	eax, 0
	fdd_exec FDD_CMD_RECALIBRATE, 0x00

	fdd_exec FDD_CMD_SENSE_INTERRUPT
	fdd_read al
	xchg	al, ah
	fdd_read al

	push	eax
	push	.status
	call	Terminal_Print
	add	esp, 8

	ret
.status db "FDD Status: %x",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Internal
;
; Locks the configuration of FDD
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_Lock:
	fdd_exec FDD_CMD_OPTION_MULTITRACK | FDD_CMD_LOCK
	fdd_read al
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Floppy - Seek track
; Parameters:
;	[ebp + 8] - track
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_Seek:
	rpush	ebp, eax

	push	dword [ebp + 8]
	push	.msg
	call	Terminal_Print
	add	esp, 8

	fdd_wait_ready_out

	mov	ah, [ebp + 8]
	fdd_exec FDD_CMD_SEEK, 0, ah

	fdd_exec FDD_CMD_SENSE_INTERRUPT
	fdd_read al
	fdd_read al

	rpop
	ret
.msg db "Seeking track: %d",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Floppy - Read
; Parameters:
;	[ebp +  8] - lba
;	[ebp + 12] - buffer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_Read:
	rpush	ebp, eax, ebx, ecx, edx, edi

	call	Floppy_Reset
	mov	dx, FDD_REG_DIGITAL_OUT
	mov	al, FDD_DOR_RESET | FDD_DOR_MOTA | FDD_DOR_DSELA
	out	dx, al

	;and	[ebp + 8], dword 0b1

	; LBA 2 CHS
	mov	eax, [ebp + 8]
	mov	bl, 18 ; [sectorsPerTrack]
	div	bl

	mov	cl, ah ; Sectors
	inc	cl
	xor	ah, ah

	mov	bl, 2 ; [headsCount]
	div	bl

	mov	ch, ah ; Heads
	;mov	ch, al ; Cylinders

	movzx	eax, al
	push	eax
	call	Floppy_Seek
	add	esp, 4

	;cli
	;hlt

	; Start reading
	;fdd_wait_ready_out

	push	dword [ebp + 12]
	push	dword [ebp + 8]
	push	.msg
	call	Terminal_Print
	add	esp, 12

	; head -> ch
	; sector -> cl
	mov	bh, ch
	shl	ch, 2
	or	ch, 0 ; drive number
	mov	ah, al

	fdd_exec FDD_CMD_OPTION_MFM | FDD_CMD_READ_DATA, ch, ah, bh, cl, 2, 1, 0x1b, 0xff
	;fdd_exec FDD_CMD_OPTION_MFM | FDD_CMD_OPTION_MULTITRACK | FDD_CMD_READ_DATA, 0, 0, 0, 2, 2, 18, 0x1b, 0xff

	mov	edi, [ebp + 12]
	mov	ecx, 512
.loop:
	;fdd_wait_ready_in

	;mov	dx, FDD_REG_DATA_FIFO
	;in	al, dx
	fdd_read al

	mov	[edi], al
	inc	edi

	movzx	ebx, al
	push	ebx
	push	.msg2
	;call	Terminal_Print
	add	esp, 8

	loop	.loop

	;push	dword 100
	;call	Timer_Delay
	;add	esp, 4

;	mov	edi, .statusBuffer
;	mov	ecx, 7
;.loop_status:
;	fdd_wait_ready_in
;
;	mov	dx, FDD_REG_DATA_FIFO
;	in	al, dx
;
;	mov	[edi], al
;	inc	edi
;
;	loop	.loop_status

	; TODO check these values
	fdd_read	[.statusST0]
	fdd_read	[.statusST1]
	fdd_read	[.statusST2]
	fdd_read	[.statusC]
	fdd_read	[.statusH]
	fdd_read	[.statusR]
	fdd_read	[.statusN]

	;push	dword [.statusBuffer]
	;push	dword [.statusBuffer+4]
	;push	.statusMsg
	;call	Terminal_Print
	;add	esp, 12

	xor	eax, eax
	mov	al, [.statusST0]
	push	eax
	mov	al, [.statusST1]
	push	eax
	mov	al, [.statusST2]
	push	eax

	push	.statusMsg2
	call	Terminal_Print
	add	esp, 16

	;test	  [.statusST0], byte 11000000b	      ; test sr0 is 0xC0
	;jnz	  .error

	;push	dword 300
	;call	Timer_Delay
	;add	esp, 4

	rpop
	ret
.error:
	push	.errorMsg
	call	Terminal_Print
	jmp	$

.msg db "Reading sector %u at %p",0xA,0
.msg2 db "%c",0
.statusBuffer times 8 db 0
.statusMsg db 0xA,"Status: %P %P",0xA,0
.errorMsg db "Floppy failed!",0

.statusST0 db 0
.statusST1 db 0
.statusST2 db 0
.statusC db 0
.statusH db 0
.statusR db 0
.statusN db 0
.statusMsg2 db 0xA,"Status: %b %b %b",0xA,0