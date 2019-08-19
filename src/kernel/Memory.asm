MEM_MAP times 32 * 24 db 0
MEM_MAP_entries dd 0

struc MEMMap_t
	.base resq 1
	.length resq 1
	.type resd 1
	.attributes resd 1
	.unused resb 8
endstruc

struc MEM_Handle_t
	;.start resd 1		; address after header
	;.length resd 1		; length without header
	;.total_length resd 1	; length including header
	;.next resd 1		; address of next entry

	.length resd 1		; length without header
	.next resd 1
endstruc

MEM_Handle dd 0
MEM_Total dd 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory pre-init
; TODO: PCem doesn't support this int function, add support to legacy ones
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[bits 16]
Memory_PreInit:
	xor	ebx, ebx
	mov	edx, 0x534d4150

	mov	di, 0
	mov	es, di
	mov	di, MEM_MAP
.loop:
	;xchg	bx, bx
	mov	ecx, 24
	mov	eax, 0xe820
	int	0x15

	;xchg	bx, bx
	jc	.legacy
	test	ebx, ebx
	jz	.exit

	add	di, MEMMap_t_size ;24
	inc	dword [MEM_MAP_entries]
	jmp	.loop

.exit:
	ret

.legacy:
	; TODO: detect memory size, reserve standard BIOS and GPU ranges
	mov	dword [MEM_MAP_entries], 1
	mov	eax, MEM_MAP
	mov	dword [eax + MEMMap_t.base], 0x0
	mov	dword [eax + MEMMap_t.length], 0xfffff
	mov	byte [eax + MEMMap_t.type], 0x1
	jmp	.exit
[bits 32]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memory_Init:
	push	.helloMsg
	call	Terminal_Print
	add	esp, 4	

	push	dword [MEM_MAP_entries]
	push	.entriesCount
	call	Terminal_Print
	add	esp, 8

	cmp	dword [MEM_MAP_entries], 0
	jz	.error

	call	Memory_InitSort

	mov	eax, [MEM_MAP + MEMMap_t.base]
	test	eax, eax
	jnz	.no_zero
	;add	dword [MEM_MAP + MEMMap_t.base], 32
	;sub	dword [MEM_MAP + MEMMap_t.length], 32
	
	mov	dword [MEM_MAP + MEMMap_t.base], KERNEL_END
	sub	dword [MEM_MAP + MEMMap_t.length], KERNEL_END

.no_zero:
	mov	ecx, [MEM_MAP_entries]
	mov	eax, MEM_MAP
.loop:
	push	dword [eax + MEMMap_t.type]
	push	dword [eax + MEMMap_t.length + 0]
	;push	dword [eax + MEMMap_t.length + 4]
	push	dword [eax + MEMMap_t.base + 0]
	;push	dword [eax + MEMMap_t.base + 4]
	push	.entry
	call	Terminal_Print
	;add	esp, 24
	add	esp, 16
	add	eax, MEMMap_t_size

	loop	.loop

	; Fill internal linked-list
	call	Memory_InitInternal

	;mov	ax, 0xE881
	;int	0x15
	;jc	.error

	;int	0x12
	;jc	.error

	push	.okMsg
	call	Terminal_Print
	add	esp, 4

	ret
.error:
	push	.errorMsg
	call	Terminal_Print
	add	esp, 4
	jmp	Panic

.entriesCount db "Entries: %u",0xA,0
.entry db "Base: %x", 0xA, "  Length: %p, Type: %x",0xA,0
.errorMsg db "Failed!",0xA,0
.okMsg db "OK!",0xA,0
.helloMsg db "Initializing memory manager... ",0,0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory sort - sort memory map entries and disable non-free ones
; TODO: if exist overlapping entries, divide them...
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memory_InitSort:
	;xchg	bx, bx
	rpush	eax, ecx, esi, edi
.start:
	mov	ecx, 0
	mov	ebx, 0
.loop:
	inc	ecx
	cmp	ecx, [MEM_MAP_entries]
	jae	.exit
	dec	ecx

	mov	eax, MEM_MAP
	mov	esi, ecx
	shl	esi, 5
	mov	edi, esi
	add	edi, MEMMap_t_size

	; TODO: qemu's entries don't overlap... if you find overlapping, implement sorting and diving them... :|
	; TODO FIXME: omg... I should exclude kernel's memory from 'unused' area... T__T
	;mov	eax, [MEM_MAP + esi + MEMMap_t.base]
	;cmp	eax, [MEM_MAP + edi + MEMMap_t.base]
	mov	al, [MEM_MAP + esi + MEMMap_t.type]
	cmp	al, [MEM_MAP + edi + MEMMap_t.type]
	jbe	.nosort

	mov	ebx, 1
	push	ecx
	push	esi
	push	edi

	mov	ecx, MEMMap_t_size
.sort_loop:
	mov	al, [MEM_MAP + esi + MEMMap_t.base]
	mov	ah, [MEM_MAP + edi + MEMMap_t.base]
	mov	[MEM_MAP + esi + MEMMap_t.base], ah
	mov	[MEM_MAP + edi + MEMMap_t.base], al
	inc	esi
	inc	edi
	dec	ecx
	jnz	.sort_loop
	pop	edi
	pop	esi
	pop	ecx
.nosort:
	inc	ecx
	jmp	.loop

.exit:
	test	ebx, ebx
	jnz	.start

	; TODO: no overlapping, just disable reserved entries
	mov	ecx, 0
	mov	eax, [MEM_MAP_entries]
.disable_loop:
	cmp	ecx, eax
	je	.disable_exit

	mov	esi, ecx
	shl	esi, 5
	cmp	byte [MEM_MAP + esi + MEMMap_t.type], 1
	je	.disable_loop_ok
	dec	dword [MEM_MAP_entries]
.disable_loop_ok:
	inc	ecx
	jmp	.disable_loop

.disable_exit:
	rpop
	ret

Memory_InitInternal:
	rpush	eax, esi, edi

	; Init first entry
	mov	eax, [MEM_MAP + MEMMap_t.base]
	mov	[MEM_Handle], eax

	; Init headers
	mov	ecx, 0
.loop:
	cmp	ecx, [MEM_MAP_entries]
	je	.exit

	mov	esi, ecx
	shl	esi, 5

	test	ecx, ecx
	jz	.no_next

	mov	eax, [MEM_MAP + esi + MEMMap_t.base]
	mov	[edi + MEM_Handle_t.next], eax
.no_next:
	mov	edi, [MEM_MAP + esi + MEMMap_t.base]
	mov	eax, [MEM_MAP + esi + MEMMap_t.length]
	sub	eax, MEM_Handle_t_size

	add	[MEM_Total], eax
	;xchg	bx, bx
	mov	[edi + MEM_Handle_t.length], eax
	mov	dword [edi + MEM_Handle_t.next], 0

	inc	ecx
	jmp	.loop

.exit:
	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory alloc
; Arguments:
; 	(ebp + 8)	-	size
; Return:
;	eax		-	pointer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memory_Alloc:
	rpush	ebp, ebx, edx, esi, edi

	mov	edx, [ebp + 8]
	add	edx, MEM_Handle_t_size

	mov	esi, 0
	mov	edi, [MEM_Handle]

.try:
	mov	ebx, [edi + MEM_Handle_t.length]
	cmp	edx, [edi + MEM_Handle_t.length]
	jbe	.try_alloc ; FIXME
	;je	.try_alloc_equal
.try_next:
	mov	esi, edi
	mov	edi, [edi + MEM_Handle_t.next]
	test	edi, edi
	jz	.error
	jmp	.try

.try_alloc:
	; edx - length to alloc
	; esi - prev handle
	; edi - current handle
	push	edi
	; Update allocated header
	mov	eax, [edi + MEM_Handle_t.length]
	mov	[edi + MEM_Handle_t.length], edx
	sub	dword [edi + MEM_Handle_t.length], MEM_Handle_t_size

	;mov	ebx, [edi + MEM_Handle_t.next]
	;mov	dword [edi + MEM_Handle_t.next], 0

	; Create next header
	mov	[edi + edx + MEM_Handle_t.length], eax
	sub	[edi + edx + MEM_Handle_t.length], edx

	xor	eax, eax
	xchg	eax, [edi + MEM_Handle_t.next]
	mov	[edi + edx + MEM_Handle_t.next], eax

	; Update previous header
	add	edi, edx
	test	esi, esi
	jz	.try_alloc_first_entry

	mov	[esi + MEM_Handle_t.next], edi
	jmp	.ok
.try_alloc_first_entry:
	mov	[MEM_Handle], edi
	jmp	.ok
.try_alloc_equal:

.ok:
	pop	eax

	add	eax, MEM_Handle_t_size
.exit:
	sub	edx, MEM_Handle_t_size
	push	edx
	push	eax
	push	.allocStr
	call	Terminal_Print
	add	esp, 12

	rpop
	ret
.error:
	push	.errorMsg
	call	Terminal_Print
	add	esp, 4

	;call	Panic
	jmp $

	mov	eax, 0
	jmp	.exit
.errorMsg db "Not enough memory...",0xA,0
.allocStr db "Allocated %p - %u bytes",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory free
; Arguments:
; 	(ebp + 8)	-	size
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memory_Free:
	rpush	ebp, eax, ebx, esi, edi

	; Get pointer and move it to header instead of payload
	mov	eax, [ebp + 8]
	sub	eax, MEM_Handle_t_size

	push	dword [eax + MEM_Handle_t.length]
	push	dword [ebp + 8]
	push	.freeStr
	call	Terminal_Print
	add	esp, 12

	mov	esi, 0
	mov	edi, [MEM_Handle]

.search_loop:
	cmp	eax, edi
	jb	.found
	mov	esi, edi
	mov	edi, [edi + MEM_Handle_t.next]
	test	edi, edi
	jz	.last_entry
	jmp	.search_loop

.found:
	test	esi, esi
	jz	.first_entry

	mov	ebx, [esi + MEM_Handle_t.next]
	mov	[eax + MEM_Handle_t.next], ebx
	mov	[esi + MEM_Handle_t.next], eax

	jmp	.exit
.first_entry:
	mov	ebx, [MEM_Handle]
	mov	[eax + MEM_Handle_t.next], ebx
	mov	[MEM_Handle], eax
	jmp	.exit

.last_entry:
	mov	[esi + MEM_Handle_t.next], eax
	mov	[eax + MEM_Handle_t.next], dword 0
	
.exit:
	call	Memory_Merge

	rpop
	ret
.freeStr db "Freeing   %p - %u bytes",0xA,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory Merge - merge entries in linked list
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memory_Merge:
	rpush	eax, esi, edi
	;xchg	bx, bx

	mov	esi, [MEM_Handle]
.loop:
	test	esi, esi
	jz	.exit

	mov	eax, esi
	add	eax, [esi + MEM_Handle_t.length]
	add	eax, MEM_Handle_t_size
	mov	edi, [esi + MEM_Handle_t.next]
	;xchg bx, bx
	cmp	eax, edi
	jne	.next

	mov	eax, [edi + MEM_Handle_t.length]
	add	eax, MEM_Handle_t_size
	add	[esi + MEM_Handle_t.length], eax
	mov	edi, [edi + MEM_Handle_t.next]
	mov	[esi + MEM_Handle_t.next], edi
	jmp	.loop

.next:
	mov	esi, [esi + MEM_Handle_t.next]
	jmp	.loop

.exit:
	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory Print Info
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Memory_PrintInfo:
	rpush	eax, ecx

	;xchg	bx, bx
	mov	ecx, 0
	mov	eax, [MEM_Handle]
.loop:
	push	dword [eax + MEM_Handle_t.next]
	push	dword [eax + MEM_Handle_t.length]
	push	eax
	push	.dbg
	call	Terminal_Print
	add	esp, 16

	add	ecx, [eax + MEM_Handle_t.length]
	mov	eax, [eax + MEM_Handle_t.next]
	
	test	eax, eax
	jnz	.loop

.exit:
	push	dword [MEM_Total]
	push	ecx
	push	.msg
	call	Terminal_Print
	add	esp, 12

	rpop
	ret

.msg db "Memory %u/%u",0xA,0
.dbg db "  %p (%u) -> %p",0xA,0