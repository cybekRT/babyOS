%include "FAT12.inc"

bpbPtr dw 0 
fatPtr dw 0
fatDirectoryPtr dw 0
fatEntry dw 0

FAT12_Init:
	rpush	ax, bx, cx, dx, es

	; Alloc BPB buffer
	push	512
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	add	sp, 2
	mov	[cs:bpbPtr], ax
	mov	es, ax

	; Read BPB with BIOS function
	mov	ah, 02h
	mov	al, 1
	mov	ch, 0
	mov	cl, 1
	mov	dh, 0
	mov	dl, 0
	mov	bx, 0
	int	13h
	jc	Panic

	; Update BPB about drive number from bootloader
	mov	al, [cs:driveNumber]
	mov	[es:FAT12_BPB.driveNumber], al

	; Alloc FAT buffer
	push	word 512*9 ; FIXME from BPB?
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	mov	[cs:fatPtr], ax
	add	sp, 2

	; Read FAT
	push	ax
	push	word [es : FAT12_BPB.sectorsPerFat]
	mov	ax, [es : FAT12_BPB.reservedSectors]
	add	ax, [es : FAT12_BPB.hiddenSectors]
	push	ax
	call	ReadSector
	add	sp, 6

	; Alloc FAT entry buffer
	push	FAT12_Directory_size
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	mov	[cs:fatDirectoryPtr], ax
	add	sp, 2

	rpop
	ret

;;;;;
; Return:
;	ax		-	directory handle
;;;;;
FAT12_OpenRoot:
	rpush	es

	push	word [fatDirectoryPtr]
	pop	es

	mov	word [es : FAT12_Directory.firstCluster], 0
	mov	word [es : FAT12_Directory.currentCluster], 0
	mov	word [es : FAT12_Directory.currentOffset], 0

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
; (bp+8) - dst
; (bp+6) - sectors count
; (bp+4) - sector
;;;;;
ReadSector:
	rpush	bp, ax, bx, cx, dx, si, es

	;push	word [bp + 8]
	;push	word [bp + 4]
	;push	word [bp + 6]
	;push	word .msg
	;call	printf
	;add	sp, 8

	mov	es, [cs:bpbPtr]

	; LBA 2 CHS
	mov	bl, [es : FAT12_BPB.sectorsPerTrack]
	div	bl

	mov	cl, ah ; Sectors
	inc	cl
	xor	ah, ah

	mov	bl, [es : FAT12_BPB.headsCount]
	div	bl

	mov	dh, ah ; Heads
	mov	ch, al ; Cylinders

	mov	ah, 02h ; Function
	mov	al, [bp + 6] ; Count
	mov	dl, [es : FAT12_BPB.driveNumber] ; Drive number

	mov	bx, [bp + 8]
	mov	es, bx
	mov	bx, 0

	int	13h
	jc	.Panic

	rpop
	ret
.Panic:
	push	word [es : FAT12_BPB.driveNumber]
	push	ax
	push	.statusMsg
	call	printf
	add	sp, 6

	call	Panic
.msg db "Reading sector(s: %u): %u -> %x",0xA,0
.statusMsg db "Status: %x (Drive: %x)",0xA,0

; ax - cluster
ClusterToSector:
	rpush	bx, es
	mov	es, [cs:bpbPtr]

	mov	bx, [es : FAT12_BPB.sectorsPerFat]
	shl	bx, 1
	add	bx, [es : FAT12_BPB.reservedSectors]
	add	bx, [es : FAT12_BPB.hiddenSectors]
	add	ax, bx

	; is root?
	push	es
	push	word [cs:fatDirectoryPtr]
	pop	es
	cmp	word [es : FAT12_Directory.firstCluster], 0
	pop	es
	jz	.exit

	; not root :(
	mov	bx, [es : FAT12_BPB.rootEntriesCount]
	shr	bx, 4
	sub	bx, 2
	add	ax, bx

.exit:
	rpop
	ret

; ax - cluster
NextCluster:
	rpush	bx, es

	; bx - fat_offset
	mov	bx, ax
	shr	bx, 1
	add	bx, ax

	push	word [fatPtr]
	pop	es
	;mov	bx, [fat + bx]
	mov	bx, [es : bx]
	test	ax, 1
	jnz	.odd
	jz	.even

.odd:
	shr	bx, 4
	jmp	.end

.even:
	and	bx, 0x0fff
	jmp	.end

.end:
	mov	ax, bx
	rpop
	ret

ReadWholeFile:
	rpush	bx, es

	push	word [cs:fatEntry]
	pop	es
	mov	ax, [es : FAT12_DirectoryEntry.size]
	add	ax, 511
	and	ax, 0xfe00
	push	ax
	ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	add	sp, 2

	mov	di, ax
	push	di
	mov	ax, [es : FAT12_DirectoryEntry.cluster]
.readLoop:
	push	ax
	call	ClusterToSector

	push	di
	push	1
	push	ax
	call	ReadSector
	add	sp, 6

	add	di, 512/16
	pop	ax
	call	NextCluster

	cmp	ax, CLUSTER_LAST
	jb	.readLoop

; Return
	pop	ax
	rpop
	ret
;.dataPtr dw 0

FAT12_ReadDirectory:
	rpush	ax, es

	;push	.readMsg
	;call	printf
	;add	sp, 2

	push	word [cs:fatDirectoryPtr]
	pop	es

	cmp	word [es : FAT12_Directory.currentOffset], 0
	jnz	.dontReadNextSector

	; Reading data sector
	mov	ax, es
	add	ax, FAT12_Directory.buffer / 16
	;shr	ax, 4
	push	ax
	push	1
	
	mov	ax, [es : FAT12_Directory.currentCluster]
	call	ClusterToSector
	push	ax

	call	ReadSector
	add	sp, 6

.dontReadNextSector:
	mov	ax, [es : FAT12_Directory.currentOffset]
	add	ax, FAT12_Directory.buffer
	shr	ax, 4
	mov	bx, es
	add	ax, bx

	mov	[cs:fatEntry], ax
	add	word [es : FAT12_Directory.currentOffset], FAT12_DirectoryEntry_size

	rpop
	ret
.readMsg db "Read... ",0

;;;;;
; (bp + 4)--- fatEntry	-	directory entry
;;;;;
FAT12_ChangeDirectory:
	rpush	bp, ax, es

	push	word [cs:fatEntry]
	pop	es

	mov	ax, [es : FAT12_DirectoryEntry.cluster]

	push	word [cs:fatDirectoryPtr]
	pop	es

	mov	[es : FAT12_Directory.firstCluster], ax
	mov	[es : FAT12_Directory.currentCluster], ax
	mov	word [es : FAT12_Directory.currentOffset], 0

	rpop
	ret
