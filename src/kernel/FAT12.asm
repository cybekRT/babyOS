%include "FAT12.inc"

bpbPtr dd 0 
fatPtr dd 0
fatDirectoryPtr dd 0
fatEntry dd 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Initialize FAT12 routines
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FAT12_Init:
	rpush	eax, ebx, ecx, edx

	; Alloc BPB buffer
	push	dword 512
	call	Memory_Alloc
	add	esp, 4
	mov	[bpbPtr], eax

	; Read BPB
	push	dword [bpbPtr]
	push	dword 0
	call	Floppy_Read
	add	esp, 8

	; Alloc FAT buffer
	push	dword 512*9 ; FIXME from BPB
	call	Memory_Alloc
	mov	[fatPtr], eax
	add	esp, 4

	; Read FAT
	mov	ecx, 9
	push	dword [fatPtr]
	push	dword 1 ; FIXME from BPB
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
	mov	[fatDirectoryPtr], eax
	add	esp, 4

	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Open root directory
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FAT12_OpenRoot:
	rpush	esi

	mov	esi, [fatDirectoryPtr]

	mov	word [esi + FAT12_Directory.firstCluster], 0
	mov	word [esi + FAT12_Directory.currentCluster], 0
	mov	word [esi + FAT12_Directory.currentOffset], 0

	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Close directory handle
;
; Arguments:
;	[ebp + 8]	-	directory handle
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FAT12_CloseDirectory:
	rpush	ebp

	push	word [ebp + 8]
	call	Memory_Free
	add	esp, 4

	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Internal
;
; Converts cluster id to LBA
; Arguments:
;	eax	-	cluster id
; Returns:
;	eax	-	LBA
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClusterToSector:
	rpush	ebx, esi, edi
	;mov	eax, 0x20

	mov	esi, [bpbPtr]

	;movzx	ebx, word [esi + FAT12_BPB.sectorsPerFat]
	;movzx	ecx, word [esi + FAT12_BPB.reservedSectors]
	;mov	edx, dword [esi + FAT12_BPB.hiddenSectors]
	;cli
	;hlt

	movzx	ebx, word [esi + FAT12_BPB.sectorsPerFat]
	shl	ebx, 1
	add	bx, word [esi + FAT12_BPB.reservedSectors]
	add	ebx, dword [esi + FAT12_BPB.hiddenSectors]
	add	eax, ebx

	; is root?
	mov	edi, [fatDirectoryPtr]
	cmp	word [edi + FAT12_Directory.firstCluster], 0
	jz	.exit

	; not root :(
	;movzx	ebx, word [esi + FAT12_BPB.rootEntriesCount]
	;shr	ebx, 4
	;sub	ebx, 2
	;add	eax, ebx
	mov	bx, [esi + FAT12_BPB.rootEntriesCount]
	shr	bx, 4
	sub	bx, 2
	add	ax, bx

.exit:
	rpop
	ret

ClusterToSector_NonRoot:
	rpush	ebx, esi, edi

	mov	esi, [bpbPtr]

	movzx	ebx, word [esi + FAT12_BPB.sectorsPerFat]
	shl	ebx, 1
	add	bx, word [esi + FAT12_BPB.reservedSectors]
	add	ebx, dword [esi + FAT12_BPB.hiddenSectors]
	add	eax, ebx

	movzx	ebx, word [esi + FAT12_BPB.rootEntriesCount]
	shr	ebx, 4
	sub	ebx, 2
	add	eax, ebx

.exit:
	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Internal
;
; Gets next cluster id
; Arguments:
;	eax	-	current cluster
; Returns:
;	eax	-	next cluster
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NextCluster:
	rpush	ebx, esi

	; bx - fat_offset
	movzx	ebx, ax
	shr	bx, 1
	add	bx, ax

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
	movzx	eax, bx
	rpop
	ret

;;;;;;;;;;
;
; Reads whole file from current directory entry
;
;;;;;;;;;;
; FIXME reads wrong sectors!
FAT12_ReadWholeFile:
	rpush	ebx, esi

	mov	esi, [fatEntry]

	movzx	eax, word [esi + FAT12_DirectoryEntry.size]
	add	eax, 511
	and	eax, 0xfe00
	push	eax
	call	Memory_Alloc
	add	esp, 4

	mov	edi, eax
	push	edi
	movzx	eax, word [esi + FAT12_DirectoryEntry.cluster]

.readLoop:
	push	eax
	call	ClusterToSector_NonRoot

	push	edi
	push	eax
	call	Floppy_Read
	add	esp, 8

	add	edi, 512
	pop	eax
	call	NextCluster

	cmp	eax, CLUSTER_LAST
	jb	.readLoop

; Return
	pop	eax
	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Reads next entry from current directory
; moves to next entry and reads sector if needed
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FAT12_ReadDirectory:
	rpush	eax, esi, edi

	mov	esi, [fatDirectoryPtr]

	cmp	word [esi + FAT12_Directory.currentOffset], 0
	jnz	.dontReadNextSector

	; Reading data sector
	push	esi
	add	[esp], dword FAT12_Directory.buffer
	
	movzx	eax, word [esi + FAT12_Directory.currentCluster]
	call	ClusterToSector
	push	eax
xchg bx, bx
	call	Floppy_Read
	add	esp, 8
xchg bx, bx

.dontReadNextSector:
	movzx	eax, word [esi + FAT12_Directory.currentOffset]
	add	eax, FAT12_Directory.buffer
	add	eax, esi

	mov	[fatEntry], eax
	add	word [esi + FAT12_Directory.currentOffset], FAT12_DirectoryEntry_size

	mov	edi, [fatEntry]
	mov	byte [edi + FAT12_DirectoryEntry.attributes], 0
	push	dword [fatEntry]
	push	dword .msg
	call	Terminal_Print
	add	esp, 8

	rpop
	ret
.msg db "Current file: '%s'",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Moves directory entry pointer to currently selected entry
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
FAT12_ChangeDirectory:
	rpush	ebp, eax, esi

	mov	esi, [fatEntry]
	mov	ax, [esi + FAT12_DirectoryEntry.cluster]

	mov	esi, [fatDirectoryPtr]
	mov	[esi + FAT12_Directory.firstCluster], ax
	mov	[esi + FAT12_Directory.currentCluster], ax
	mov	word [esi + FAT12_Directory.currentOffset], 0

	rpop
	ret
