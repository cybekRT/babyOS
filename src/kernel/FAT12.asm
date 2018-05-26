

fat dw 0
;currentFat dw 0

FAT12_Init:
	push	BPB_size
	push	.test
	call	printf
	add	sp, 4

	mov	ax, 0x7c00 + BPB.sectorsPerFat
	;mov	bx, [0x7c00 + BPB.bytesPerSector]
	;mul	bx
	push	ax
	;call	Memory_AllocBytes
	;mov	[fat], ax

	push	.test
	call	printf
	add	sp, 4

	ret
	.test  db "FAT size: %xB",0xA,0

;;;;;
; (bp+8) - dst
; (bp+6) - sectors count
; (bp+4) - sector
;;;;;
ReadSector:
	push	bp
	mov	bp, sp
	rpush	ax, cx, dx, bx, ds, es

	mov	ah, 02h
	mov	al, [0x7c00 + BPB.reservedSectors] ;(KERNEL_SIZE + 511) / 512
	mov	cx, 2
	mov	dh, 0
	mov	dl, [0x7c00 + BPB.driveNumber]

	mov	bx, 0
	mov	es, bx
	mov	bx, 0x500

	int	0x13
	jc	Panic

	rpop
	pop	bp
	ret