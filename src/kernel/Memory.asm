struc MemoryInfo
	.base	resq 1
	.length	resq 1
	.type	resd 1
	.unused	resd 1
endstruc

memoryPoolMaxSize equ 8
; why memoryPoolMaxSize+1? because if we would like to detect overflow... we must
memoryPool times ((memoryPoolMaxSize+1) * MemoryInfo_size) db 0
memoryPoolSize db 0
%define memPoolAt(x) (memoryPool + x * MemoryInfo_size)

Memory_Init:
	mov	di, 0
	mov	es, di
	mov	di, memPoolAt(0)
	mov	ebx, 0
	mov	edx, 0x534D4150

.loop:
	mov	eax, 0xE820
	mov	ecx, 24
	int	0x15

	jc	.ret
	cmp	ebx, 0
	jz	.ret

	; checks if we have enough memory for entries...
	movzx	ax, [memoryPoolSize]
	cmp	ax, memoryPoolMaxSize
	jae	.fail

	; checks if <1MB
	cmp	dword [di + MemoryInfo.base+4], 0
	ja	.loop
	cmp	dword [di + MemoryInfo.base], 0xfffff
	ja	.loop

	; if base < KERNEL_END, fix it!
	cmp	dword [di + MemoryInfo.base], KERNEL_END
	jae	.no_base_fix
	mov	dword [di + MemoryInfo.base], KERNEL_END

.no_base_fix:
	push	word [memPoolAt(0) + MemoryInfo.type+0]
	push	word [memPoolAt(0) + MemoryInfo.type+2]
	push	word [memPoolAt(0) + MemoryInfo.length+0]
	push	word [memPoolAt(0) + MemoryInfo.length+2]
	push	word [memPoolAt(0) + MemoryInfo.length+4]
	push	word [memPoolAt(0) + MemoryInfo.length+6]
	push	word [memPoolAt(0) + MemoryInfo.base+0]
	push	word [memPoolAt(0) + MemoryInfo.base+2]
	push	word [memPoolAt(0) + MemoryInfo.base+4]
	push	word [memPoolAt(0) + MemoryInfo.base+6]
	push	.text
	call	printf
	add	sp, 22

	inc	byte [memoryPoolSize]
	add	di, MemoryInfo_size
	jmp	.loop
.text db 'Base: %x%X%X%X, Length: %x%X%X%X, Type: %x%X',0xA,0
.hello db 'Memory manager initialized!',0xA,0

.ret:
	push	.hello
	call	printf
	add	sp, 2
	ret
.fail:
	call	Panic

Memory_Alloc:
	ret

Memory_Free:
	ret

Memory_Reserve:
	ret