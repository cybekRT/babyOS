%include "FAT12.inc"

bpb dw 0
fat dw 0

FAT12_Init:
	rpush	ax, bx, cx, dx, es
	;push	FAT12_BPB_size
	;push	.test
	;call	printf
	;add	sp, 4

	; Alloc bpb
	push	512
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	mov	[bpb], ax
	add	sp, 2
	;pop	word [bpb]

	; Alloc fat array
	mov	ax, [0x7c00 + FAT12_BPB.sectorsPerFat]
	mov	bx, 32; [0x7c00 + FAT12_BPB.bytesPerSector]
	mul	bx
	push	ax
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_SEGMENTS
	add	sp, 2
	mov	[fat], ax

	; Some debug info, ignore...
	push	word [fat]
	push	word [bpb]
	push	.test
	call	printf
	add	sp, 6

	; Read BPB
	push	word [bpb]
	push	word 1
	push	word 0
	call	ReadSector
	add	sp, 6

	; Read FAT
	push	word [fat]
	push	word [0x7c00 + FAT12_BPB.sectorsPerFat]
	mov	ax, [0x7c00 + FAT12_BPB.reservedSectors]
	add	ax, [0x7c00 + FAT12_BPB.hiddenSectors]
	push	ax
	call	ReadSector
	add	sp, 6

	rpop
	ret
	;.test  db "FAT size: %xB",0xA,0
	.test db "BPB/FAT pointer: %x / %x",0xA,0

;;;;;
; Return:
;	ax		-	directory handle
;;;;;
FAT12_OpenRoot:
	rpush	es

	push	FAT12_Directory_size
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	add	sp, 2

	mov	es, ax
	mov	word [es:FAT12_Directory.firstCluster], 0
	mov	word [es:FAT12_Directory.currentCluster], 0
	mov	word [es:FAT12_Directory.currentOffset], 0

	;push	512
	;ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	;add	sp, 2
	;mov	word [es:FAT12_Directory.bufferPtr], ax

	mov	ax, es
	rpop
	ret

;;;;;
; Arguments:
;	(bp + 4)	-	directory handle
;;;;;
FAT12_CloseDirectory:
	rpush	bp

	push	word [bp + 4]
	ApiCall	INT_API_MEMORY, API_MEMORY_FREE
	add	sp, 2

	rpop
	ret

;;;;;
; Arguments:
;	(bp + 4)	-	directory handle
;	(bp + 6)	-	directory entry handle
; Return:
;;;;;
FAT12_ReadDirectory:
.DIR_HANDLE equ 4
.DIR_ENTRY equ 6
	rpush	bp

	mov	bx, [bp + .DIR_HANDLE]
	mov	es, bx
	cmp	word [es:FAT12_Directory.currentOffset], 0
	jnz	.noRead

	; Read current sector

.noRead:
	mov	ax, [bp + .DIR_HANDLE]
	mov	ax, [bp + .DIR_ENTRY]

	mov	es, [bp + 4]

	rpop
	ret

;;;;;
; (bp+8) - dst
; (bp+6) - sectors count
; (bp+4) - sector
;;;;;
ReadSector:
	rpush	bp, ax, bx, cx, dx, es

	; LBA 2 CHS
	mov	bl, [0x7c00 + FAT12_BPB.sectorsPerTrack]
	div	bl

	mov	cl, ah ; Sectors
	inc	cl
	xor	ah, ah

	mov	bl, [0x7c00 + FAT12_BPB.headsCount]
	div	bl

	mov	dh, ah ; Heads
	mov	ch, al ; Cylinders

	mov	bx, [bp + 8]
	mov	es, bx
	mov	bx, 0

	;;;;;
	mov	ah, 02h
	mov	al, [bp + 6]
	mov	dl, [0x7c00 + FAT12_BPB.driveNumber]

	int	13h
	jc	Panic

	;call	Panic
	rpop
	ret
