[BITS 16]
[ORG 0x7C00]

	cli

	xor ax, ax
	mov ds, ax

	lgdt	[gdt_desc]

	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	jmp	0x8:PMode
	
gdt:
gdt_null:
   dq 0

gdt_code:
   dw 0FFFFh
   dw 0
   db 0
   db 10011010b
   db 11001111b
   db 0
gdt_data:
   dw 0FFFFh
   dw 0
   db 0
   db 10010010b
   db 11001111b
   db 0
gdt_end
gdt_desc:
   db gdt_end - gdt
   dw gdt
	
[bits 32]
PMode:
	jmp $
	
times 510-($-$$) db 0
dw 0xAA55
