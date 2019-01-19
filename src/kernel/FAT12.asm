%include "FAT12.inc"

;bpb dw 0
align 16, db 0
bpb times FAT12_BPB_size db 0
fat times (512 * 9) db 0 ; TODO check if this is correct, better before changing to dynamic memory...
fatDirectory times FAT12_Directory_size db 0
;fatEntry times FAT12_DirectoryEntry_size db 0
;fatData times 512 db 0
;fatEntry times FAT12_DirectoryEntry_size db 0
fatEntry dw 0
;fat dw 0

FAT12_Init:
	rpush	ax, bx, cx, dx, es
	;push	FAT12_BPB_size
	;push	.test
	;call	printf
	;add	sp, 4

	; Alloc bpb
	;push	512
	;ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	;mov	[bpb], ax
	;add	sp, 2

	; Alloc fat array
	;mov	ax, [0x7c00 + FAT12_BPB.sectorsPerFat]
	;mov	bx, 32; [0x7c00 + FAT12_BPB.bytesPerSector]
	;mul	bx
	;push	ax
	;ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_SEGMENTS
	;add	sp, 2
	;mov	[fat], ax

	; Some debug info, ignore...
	;push	word [fat]
	;push	word [bpb]
	;push	.test
	;call	printf
	;add	sp, 6

	; Read BPB
	;mov	ax, bpb
	;shr	ax, 4
	;push	ax ; segment for this pointer...
	;push	word 1
	;push	word 0
	;call	ReadSector
	;add	sp, 6
	; Read BPB with BIOS function
	mov	ah, 02h
	mov	al, 1
	mov	ch, 0
	mov	cl, 1
	mov	dh, 0
	mov	dl, 0
	mov	bx, 0
	mov	es, bx
	mov	bx, bpb
	int	13h
	jc	Panic

	; Read FAT
	;push	word fat
	mov	ax, fat
	shr	ax, 4
	push	ax

	push	word [bpb + FAT12_BPB.sectorsPerFat]
	mov	ax, [bpb + FAT12_BPB.reservedSectors]
	add	ax, [bpb + FAT12_BPB.hiddenSectors]
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
	;rpush	es

	;push	FAT12_Directory_size
	;ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	;add	sp, 2

	;mov	es, ax
	;mov	word [es:FAT12_Directory.firstCluster], 0
	;mov	word [es:FAT12_Directory.currentCluster], 0
	;mov	word [es:FAT12_Directory.currentOffset], 0
	
	mov	word [fatDirectory + FAT12_Directory.firstCluster], 0
	mov	word [fatDirectory + FAT12_Directory.currentCluster], 0
	mov	word [fatDirectory + FAT12_Directory.currentOffset], 0

	;push	512
	;ApiCall	INT_API_MEMORY, API_MEMORY_ALLOC_BYTES
	;add	sp, 2
	;mov	word [es:FAT12_Directory.bufferPtr], ax

	;mov	ax, es
	;rpop
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
;FAT12_ReadDirectory:
;.DIR_HANDLE equ 4
;.DIR_ENTRY equ 6
;	rpush	bp
;
;	mov	bx, [bp + .DIR_HANDLE]
;	mov	es, bx
;	cmp	word [es:FAT12_Directory.currentOffset], 0
;	jnz	.noRead
;
;	; Read current sector
;
;.noRead:
;	mov	ax, [bp + .DIR_HANDLE]
;	mov	ax, [bp + .DIR_ENTRY]
;
;	mov	es, [bp + 4]
;
;	rpop
;	ret

;;;;;
; (bp+8) - dst
; (bp+6) - sectors count
; (bp+4) - sector
;;;;;
ReadSector:
	rpush	bp, ax, bx, cx, dx, es

	; LBA 2 CHS
	mov	bl, [bpb + FAT12_BPB.sectorsPerTrack]
	div	bl

	mov	cl, ah ; Sectors
	inc	cl
	xor	ah, ah

	mov	bl, [bpb + FAT12_BPB.headsCount]
	div	bl

	mov	dh, ah ; Heads
	mov	ch, al ; Cylinders

	mov	bx, [bp + 8]
	mov	es, bx
	mov	bx, 0

	;;;;;
	mov	ah, 02h
	mov	al, [bp + 6]
	mov	dl, [bpb + FAT12_BPB.driveNumber]

	int	13h
	jc	.Panic

	rpop
	ret
.Panic:
	call	Panic

; ax - cluster
ClusterToSector:
	rpush	bx
	mov	bx, [bpb + FAT12_BPB.sectorsPerFat]
	shl	bx, 1
	add	bx, [bpb + FAT12_BPB.reservedSectors]
	add	bx, [bpb + FAT12_BPB.hiddenSectors]
	add	ax, bx

	; is root?
	cmp	word [fatDirectory + FAT12_Directory.firstCluster], 0
	jz	.exit

	; not root :(
	mov	bx, [bpb + FAT12_BPB.rootEntriesCount]
	shr	bx, 4
	sub	bx, 2
	add	ax, bx

.exit:
	rpop
	ret

FAT12_ReadDirectory:
	cmp	word [fatDirectory + FAT12_Directory.currentOffset], 0
	jnz	.dontReadNextSector
	
	; Reading data sector
	mov	ax, fatDirectory + FAT12_Directory.buffer
	shr	ax, 4
	push	ax
	push	1
	
	mov	ax, [fatDirectory + FAT12_Directory.currentCluster]
	call	ClusterToSector
	push	ax

	; TODO if not root, add some sectors count

	call	ReadSector
	add	sp, 6

.dontReadNextSector:
	mov	ax, [fatDirectory + FAT12_Directory.currentOffset]
	add	ax, fatDirectory + FAT12_Directory.buffer
	mov	[fatEntry], ax

	add	word [fatDirectory + FAT12_Directory.currentOffset], FAT12_DirectoryEntry_size

	ret

;;;;;
; (bp + 4)--- fatEntry	-	directory entry
;;;;;
FAT12_ChangeDirectory:
	rpush	bp, ax

	;mov	ax, fatEntry
	mov	bx, [fatEntry]
	add	bx, FAT12_DirectoryEntry.cluster
	mov	ax, [bx]
	mov	[fatDirectory + FAT12_Directory.firstCluster], ax
	mov	[fatDirectory + FAT12_Directory.currentCluster], ax
	mov	word [fatDirectory + FAT12_Directory.currentOffset], 0

	rpop
	ret
