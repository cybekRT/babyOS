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
fdd_irq db 0
fdd_motor db 0
fdd_cylinder db 0xff

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

%macro fdd_wait_irq_begin 0
	mov	[fdd_irq], byte 0
%endmacro

%macro fdd_wait_irq_end 0
	mov	[fdd_irq], byte 0
	;pushf
	;sti
%%wait:
	hlt
	cmp	[fdd_irq], byte 1
	jz	%%wait
	;popf
%endmacro

Floppy_WaitIRQ:
	fdd_wait_irq_end
	ret

	push	ecx
	mov	ecx, 5000
.loop:
	cmp	[fdd_irq], byte 1
	je	.exit

	push	dword 1
	call	Timer_Delay
	add	esp, 4

	dec	ecx
	test	ecx, ecx
	jz	.error

.exit:
	pop	ecx
	ret

.error:
	print "FDD error...1"
	cli
	hlt
	jmp	.error

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Initializes FDD subsystem
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Floppy_Init:
	print	"FDC interrupts"
	push	IRQ2INT(IRQ_FLOPPY)
	push	Floppy_IRQ
	call	IDT_RegisterISR
	add	esp, 8
	sti

	print	"FDC reset"
	call	Floppy_Reset
	print	"FDC recalibrate"
	call	Floppy_Recalibrate
	print	"FDC lock"
	call	Floppy_Lock
	ret

Floppy_MotorOn:
	push	eax
	push	edx

	mov	dx, 0x3f2
	mov	al, 0x1c
	out	dx, al

	push	dword 200
	call	Timer_Delay
	add	esp, 4

	mov	[fdd_motor], byte 1

	pop	edx
	pop	eax
	ret

Floppy_MotorOff:
	push	eax
	push	edx

	mov	dx, 0x3f2
	mov	al, 0
	out	dx, al

	mov	[fdd_motor], byte 0

	pop	edx
	pop	eax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Wait for FDD to be ready for OUT command
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro fdd_wait_ready_out 0
	push	eax
	push	ecx
	push	edx
	mov	ecx, 1000
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
	mov	ecx, 1000
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

Floppy_SendByte:
	fdd_write al
	ret

Floppy_ReadByte:
	fdd_read al
	ret

Floppy_Reset:

	mov	dx, 0x3f2
	mov	al, 00001000b
	out	dx, al

	push	dword 1000
	call	Timer_Delay
	add	esp, 4

	mov	dx, 0x3f7
	mov	al, 00000000b
	out	dx, al

	mov	dx, 0x3f2
	mov	al, 00001100b
	out	dx, al

	mov	[fdd_irq], byte 0
	call	Floppy_WaitIRQ

	mov	ecx, 4
.status:
	mov	al, 0x08
	call	Floppy_SendByte
	call	Floppy_ReadByte
	call	Floppy_ReadByte
	loop	.status

	mov	al, 0x03
	call	Floppy_SendByte
	mov	al, 0xDF
	call	Floppy_SendByte
	mov	al, 0x02
	call	Floppy_SendByte

	ret

fdd_cylinder_prev db 0
Floppy_Seek:
	push	ebx
	mov	bl, [fdd_track]

	mov	al, [fdd_cylinder_prev]
	cmp	bl, al
	jz	.exit

	mov	[fdd_cylinder_prev], bl

	print	"Seeking track!"

	mov	al, 0x0F
	call	Floppy_SendByte
	mov	al, 0x00
	call	Floppy_SendByte
	mov	al, bl
	call	Floppy_SendByte

	mov	[fdd_irq], byte 0
	call	Floppy_WaitIRQ

	mov	al, 0x08
	call	Floppy_SendByte
	call	Floppy_ReadByte
	mov	ah, al
	call	Floppy_ReadByte

	test	ah, 00100000b
	jz	.error
	test	ah, 10000000b
	jnz	.error

	print	"Seek ok!"

.exit:
	pop	ebx
	ret
.error:
	print "Seek error..."
	cli
	hlt
	jmp	.error

Floppy_Recalibrate:

	call	Floppy_MotorOn

	mov	al, 0x07
	call	Floppy_SendByte
	mov	al, 0x00
	call	Floppy_SendByte

	mov	[fdd_irq], byte 0
	call	Floppy_WaitIRQ

	mov	al, 0x08
	call	Floppy_SendByte
	call	Floppy_ReadByte
	mov	ah, al
	call	Floppy_ReadByte

	test	ah, 00100000b
	jz	.error
	test	ah, 00010000b
	jnz	.error

.exit:
	mov	[fdd_track], byte 0
	ret

.error:
	print "Fdd recalibrate error..."
	cli
	hlt
	jmp	.error

Floppy_Lock:
	ret

align 32
db "================"
fdd_buffer times 512 db 0
db "================"

Floppy_Read:
	rpush	ebp, eax, ebx, ecx, edx, esi, edi

	;call	Floppy_Init

	;print "Read reset:"
	;call	Floppy_Reset

	;print "  Activate"
	;mov	dx, FDD_REG_DIGITAL_OUT
	;mov	al, FDD_DOR_RESET | FDD_DOR_MOTA | FDD_DOR_DSELA | FDD_DOR_IRQ
	;out	dx, al

	;call	Floppy_EnableMotor

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

	;print "  Seek"
	;movzx	eax, al
	;push	eax
	;call	Floppy_Seek
	;add	esp, 4

	; Start reading
	;fdd_wait_ready_out

	;push	dword [ebp + 12]
	;push	dword [ebp + 8]
	;push	.msg
	;call	Terminal_Print
	;add	esp, 12

	; head -> ch
	; sector -> cl
	mov	bh, ch
	shl	ch, 2
	or	ch, 0 ; drive number
	mov	ah, al

	;mov	[fdd_head], ch
	mov	[fdd_driveno], bh
	shl	byte [fdd_driveno], 2

	mov	[fdd_head], bh
	mov	[fdd_sector], cl
	mov	[fdd_track], ah

	push	dword [ebp + 8]
	push	.msg
	call	Terminal_Print
	add	esp, 8

	movzx	eax, byte [fdd_sector]
	push	eax
	movzx	eax, byte [fdd_head]
	push	eax
	movzx	eax, byte [fdd_track]
	push	eax
	push	.msg2
	call	Terminal_Print
	add	esp, 16

	print	"Reading floppy"
	call	Floppy_Read2

	print	"Copying buffer..."
	mov	esi, fdd_buffer
	mov	edi, [ebp + 12]
	mov	ecx, 512
	rep	movsb
	print	"Done!"

	rpop
	ret
.msg db "Reading LBA: %u",0xA,0
.msg2 db "Cylinder: %u, Head: %u, Sector: %u",0xA,0

fdd_head db 0
fdd_driveno db 0
fdd_errorcode db 0
fdd_track db 0
fdd_sector db 0
Floppy_Read2:
	and	dh, 1
	;mov	[fdd_head], dh
	shl	dh, 2
	;mov	[fdd_driveno], dh

	mov	[fdd_errorcode], byte 0x04
	;cmp	ch, 0x51
	;mov	[fdd_track], ch

	;mov	[fdd_sector], cl
	test	[fdd_motor], byte 1
	jnz	.l1
	call	Floppy_MotorOn

.l1:
	mov	dx, 0x3f7
	mov	al, 0
	out	dx, al
	mov	[fdd_errorcode], byte 0x80

	call	Floppy_Seek

.l3:
	mov	dx, 0x3f4
	in	al, dx
	test	al, 00100000b
	jnz	.error

.read_fdd:
	mov	bl, 2
	mov	esi, 512
	mov	ecx, 0x80000
	mov	bh, 0
	call	dma_transfer

	mov	al, 0xe6
	call	Floppy_SendByte

.cont:
	mov	al, [fdd_driveno]
	call	Floppy_SendByte
	mov	al, [fdd_track]
	call	Floppy_SendByte

	mov	al, [fdd_head]
	call	Floppy_SendByte
	mov	al, [fdd_sector]
	call	Floppy_SendByte
	mov	al, 0x02
	call	Floppy_SendByte

	mov	al, 0x12
	call	Floppy_SendByte
	mov	al, 0x1b
	call	Floppy_SendByte
	mov	al, 0xff
	call	Floppy_SendByte

	print	"== Waiting IRQ =="
	mov	[fdd_irq], byte 0
	call	Floppy_WaitIRQ
	print	"   OK"

	call	Floppy_ReadByte
	mov	[res_st0], al
	call	Floppy_ReadByte
	mov	[res_st1], al
	call	Floppy_ReadByte
	mov	[res_st2], al
	call	Floppy_ReadByte
	mov	[res_c], al
	call	Floppy_ReadByte
	mov	[res_h], al
	call	Floppy_ReadByte
	mov	[res_r], al
	call	Floppy_ReadByte
	mov	[res_n], al

	test	[res_st0], byte 11000000b
	jnz	.error
	mov	[fdd_errorcode], byte 0

.exit:
	ret

.error:
	print "Read error!"

	movzx	eax, byte [res_st2]
	push	eax
	movzx	eax, byte [res_st1]
	push	eax
	movzx	eax, byte [res_st0]
	push	eax
	push	.msg
	call	Terminal_Print
	add	esp, 16

	;ret
	cli
	hlt
	jmp	.error

.msg db  "Status - st0: %x, st1: %x, st2: %x",0xA,0

res_st0 db 0xff
res_st1 db 0
res_st2 db 0
res_c db 0
res_h db 0
res_r db 0
res_n db 0

dma_transfer:
	push	eax
	;initialize_floppy_DMA:
	; set DMA channel 2 to transfer data from 0x1000 - 0x33ff in memory
	; paging must map this _physical_ memory elsewhere and _pin_ it from paging to disk!
	; set the counter to 0x23ff, the length of a track on a 1.44 MiB floppy - 1 (assuming 512 byte sectors)
	; transfer length = counter + 1
	mov	al, 0x06
	out 0x0a, al      ; mask DMA channel 2 and 0 (assuming 0 is already masked)

	mov	al, 0xFF
	out 0x0c, al      ; reset the master flip-flop

	;mov	ax, di
	mov	ax, fdd_buffer

	;mov	al, 0
	out 0x04, al         ; address to 0 (low byte)

	;mov	al, 0x10
	mov	al, ah
	out 0x04, al      ; address to 0x10 (high byte)

	mov	al, 0xFF
	out 0x0c, al      ; reset the master flip-flop (again!!!)

	mov	al, 0xFF
	out 0x05, al      ; count to 0x00 (low byte)

	mov	al, 0x1
	out 0x05, al      ; count to 0x02 (high byte),

	mov	al, 0
	out 0x81, al         ; external page register to 0 for total address of 00 10 00

	mov	al, 0x02
	out 0x0a, al      ; unmask DMA channel 2

	pop	eax
	ret

.status db "FDD Status: %b",0xA,0
.version db "FDD Version: %x",0xA,0
.lock db "FDD Lock: %x",0xA,0
