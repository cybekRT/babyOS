Panic:
	pushf
	push	dword [esp + 4] ; eip

	push	esp
	push	ebp
	push	edi
	push	esi
	push	edx
	push	ecx
	push	ebx
	push	eax
	push	.panicMsg

.fill_background:
	mov	al, 10
	mov	edi, 0xa0000
	mov	ecx, 320*200
	;rep	stosb

	;call	Terminal_Init
	call	Terminal_Print
	add	esp, 11*4

.background:
	mov	al, 12
	; top
	mov	edi, 0xa0000
	mov	ecx, 320
	rep	stosb
	; bottom
	mov	edi, 0xa0000 + 199*320
	mov	ecx, 320
	rep	stosb
	; left
	mov	edi, 0xa0000
	mov	ecx, 200
.left_loop:
	mov	[edi], al
	add	edi, 320
	loop	.left_loop
	; right
	mov	edi, 0xa0000 + 319
	mov	ecx, 200
.right_loop:
	mov	[edi], al
	add	edi, 320
	loop	.right_loop

	; Halt
	cli
	hlt
	jmp	$-1

.panicMsg db "Kernel panic...",0xA,0xA
	db "  EAX:   %p",0xA
	db "  EBX:   %p",0xA
	db "  ECX:   %p",0xA
	db "  EDX:   %p",0xA
	db "  ESI:   %p",0xA
	db "  EDI:   %p",0xA
	db "  EBP:   %p",0xA
	db "  ESP:   %p",0xA
	db "  EIP:   %p",0xA
	db "  Flags: %x"
	db 0
