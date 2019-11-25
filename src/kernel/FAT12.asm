%include "FAT12.inc"

bpbPtr dd 0 
fatPtr dd 0
fatDirectoryPtr dd 0
fatEntry dd 0

;;;;;;;;;;
;
; Initialize FAT12 routines
;
;;;;;;;;;;
FAT12_Init:
	rpush	eax, ebx, ecx, edx

	; Alloc BPB buffer
	push	dword 512
	;ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	call	Memory_Alloc
	add	esp, 4
	mov	[bpbPtr], eax

	push	dword [bpbPtr]
	push	dword 0
	call	Floppy_Read
	add	esp, 8

	;mov	es, ax

	; Read BPB with BIOS function
	;mov	ah, 02h
	;mov	al, 1
	;mov	ch, 0
	;mov	cl, 1
	;mov	dh, 0
	;mov	dl, 0
	;mov	bx, 0
	;int	13h
	;jc	Panic

	; Update BPB about drive number from bootloader
	;mov	al, [cs:driveNumber]
	;mov	[es:FAT12_BPB.driveNumber], al

	; Alloc FAT buffer
	push	dword 512*9 ; FIXME from BPB?
	call	Memory_Alloc
	;ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	mov	[fatPtr], eax
	add	esp, 4

	; Read FAT
	;push	ax
	;push	word [es : FAT12_BPB.sectorsPerFat]
	;mov	ax, [es : FAT12_BPB.reservedSectors]
	;add	ax, [es : FAT12_BPB.hiddenSectors]
	;push	ax
	;call	ReadSector
	;add	sp, 6

	mov	ecx, 9
	push	dword [fatPtr]
	push	dword 1
	mov	ebp, esp
.loop:
	call	Floppy_Read

	inc	dword [ebp + 0]
	add	dword [ebp + 4], 512
	loop	.loop

	add	esp, 8

	; Alloc FAT entry buffer
	push	dword FAT12_Directory_size
	call	Memory_Alloc
	;ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	mov	[fatDirectoryPtr], eax
	add	esp, 4

	rpop
	ret

;;;;;;;;;;
;
; Open root directory
;
; Return:
;	ax		-	directory handle
;
;;;;;;;;;;
FAT12_OpenRoot:
	rpush	esi

	;push	word [fatDirectoryPtr]
	;pop	es
	mov	esi, [fatDirectoryPtr]

	mov	word [esi + FAT12_Directory.firstCluster], 0
	mov	word [esi + FAT12_Directory.currentCluster], 0
	mov	word [esi + FAT12_Directory.currentOffset], 0

	rpop
	ret

;;;;;;;;;;
;
; Close directory handle
;
; Arguments:
;	(ebp + 8)	-	directory handle
;
;;;;;;;;;;
FAT12_CloseDirectory:
	rpush	ebp

	push	word [ebp + 8]
	;ApiCall	INT_API_MEMORY, MEMORY_FREE
	call	Memory_Free
	add	esp, 4

	rpop
	ret

; eax - cluster
ClusterToSector:
	rpush	ebx, esi

	;mov	es, [cs:bpbPtr]
	mov	esi, [bpbPtr]

	movzx	ebx, word [esi + FAT12_BPB.sectorsPerFat]
	shl	ebx, 1
	add	bx, word [esi + FAT12_BPB.reservedSectors]
	add	ebx, dword [esi + FAT12_BPB.hiddenSectors]
	add	eax, ebx

	; is root?
	;push	es
	;push	word [cs:fatDirectoryPtr]
	mov	esi, [fatDirectoryPtr]
	;pop	es
	cmp	word [esi + FAT12_Directory.firstCluster], 0
	;pop	es
	jz	.exit

	; not root :(
	mov	bx, [esi + FAT12_BPB.rootEntriesCount]
	shr	bx, 4
	sub	bx, 2
	add	ax, bx

.exit:
	rpop
	ret

; ax - cluster
NextCluster:
	rpush	ebx, esi

	; bx - fat_offset
	movzx	ebx, ax
	shr	bx, 1
	add	bx, ax

	;push	word [fatPtr]
	;pop	es
	mov	esi, [fatPtr]
	mov	bx, [esi + ebx]
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

;;;;;;;;;;
;
; Reads whole file from current directory entry
;
;;;;;;;;;;
FAT12_ReadWholeFile:
	rpush	bx, es

	push	word [cs:fatEntry]
	pop	es
	movzx	eax, word [es : FAT12_DirectoryEntry.size]
	add	ax, 511
	and	ax, 0xfe00
	push	ax
	;ApiCall	INT_API_MEMORY, MEMORY_ALLOC_BYTES
	call	Memory_Alloc
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
	;call	ReadSector
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

;;;;;;;;;;
;
; Reads next directory entry
;
;;;;;;;;;;
FAT12_ReadDirectory:
	rpush	eax, esi

	;push	word [cs:fatDirectoryPtr]
	;pop	es
	mov	esi, [fatDirectoryPtr]

	cmp	word [esi + FAT12_Directory.currentOffset], 0
	jnz	.dontReadNextSector

	; Reading data sector
	;mov	ax, es
	;add	ax, FAT12_Directory.buffer / 16
	;shr	ax, 4
	;push	ax
	;push	1

	push	esi
	add	[esp], dword FAT12_Directory.buffer
	
	movzx	eax, word [esi + FAT12_Directory.currentCluster]
	call	ClusterToSector
	push	eax

	;call	ReadSector
	call	Floppy_Read
	add	sp, 8

.dontReadNextSector:
	movzx	eax, word [esi + FAT12_Directory.currentOffset]
	add	eax, FAT12_Directory.buffer
	add	eax, esi

	;shr	ax, 4
	;mov	bx, es
	;add	ax, bx

	mov	[fatEntry], eax
	add	word [esi + FAT12_Directory.currentOffset], FAT12_DirectoryEntry_size

	rpop
	ret

;;;;;;;;;;
;
; Changes directory to current entry
;
; Arguments:
;	(bp + 4)--- fatEntry	-	directory entry
;
;;;;;;;;;;
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
