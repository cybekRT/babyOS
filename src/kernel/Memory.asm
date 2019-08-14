MEM_MAP:
times 32 * 24 db 0
MEM_MAP_entries dd 0

struc MEMMap_t
	.base resq 1
	.length resq 1
	.type resd 1
	.attributes resd 1
endstruc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Memory pre-init
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
	jc	.exit
	test	ebx, ebx
	jz	.exit

	add	di, 24
	inc	dword [MEM_MAP_entries]
	jmp	.loop

.exit:
	ret
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

	;mov	ax, 0xE881
	;int	0x15
	;jc	.error

	;int	0x12
	;jc	.error

	ret
.error:
	push	.errorMsg
	call	Terminal_Print
	add	esp, 4
	jmp	Panic

;.entry db "Base: 0x%x%X, Length: %x%X, Type: %x",0xA,0
;.entry db "Base: %p, Length: %u, Type: %x",0xA,0
.entry db "Base: %u", 0xA, "  Length: %p, Type: %x",0xA,0
.errorMsg db "Failed!"
.helloMsg db "Initializing memory manager...",0xA,0; xyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyzxyz",0