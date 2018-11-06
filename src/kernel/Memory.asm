; Memory manager
; memBlock - first free block, 0 if no free memory
;	[memBlockPos + 0] -> blockSize
;	[memBlockPos + 2] -> nextBlockPos, 0 if last entry
;

InterruptInfo Memory_Init, Memory_GetFree, Memory_AllocSegments, Memory_AllocBytes, Memory_Free, Memory_PrintMap
API_MEMORY_GET_FREE		equ 0
API_MEMORY_ALLOC_SEGMENTS	equ 1
API_MEMORY_ALLOC_BYTES		equ 2
API_MEMORY_FREE			equ 3
API_MEMORY_PRINT_MAP		equ 4

struc MemBlock
	.size resw 1
	.next resw 1
endstruc

struc MemoryInfo
	.base	resq 1
	.length	resq 1
	.type	resd 1
	.unused	resd 1
endstruc

memoryPoolMaxSize equ 4
; why memoryPoolMaxSize+1? because if we would like to detect overflow... we must
memoryPool db 0;times ((memoryPoolMaxSize+1) * MemoryInfo_size) db 0
memoryPoolSize db 0
%define memPoolAt(x) (memoryPool + x * MemoryInfo_size)

memBlock dw 0

;;;;;
Memory_Init:
	jmp	Memory_InitOld
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

	; check type, if not empty, ignore
	cmp	dword [di + MemoryInfo.type], 1
	jne	.loop

	; if base < KERNEL_END, fix it!
	cmp	dword [di + MemoryInfo.base], KERNEL_END
	jae	.no_base_fix
	mov	dword [di + MemoryInfo.base], KERNEL_END

.no_base_fix:
	; align base to segment
	add	dword [di + MemoryInfo.base], 0xf
	shr	dword [di + MemoryInfo.base], 4
	shr	dword [di + MemoryInfo.length], 4

	push	word [di + MemoryInfo.type+0]
	push	word [di + MemoryInfo.type+2]
	push	word [di + MemoryInfo.length+0]
	push	word [di + MemoryInfo.length+2]
	push	word [di + MemoryInfo.length+4]
	push	word [di + MemoryInfo.length+6]
	push	word [di + MemoryInfo.base+0]
	push	word [di + MemoryInfo.base+2]
	push	word [di + MemoryInfo.base+4]
	push	word [di + MemoryInfo.base+6]
	push	.text
	call	printf
	add	sp, 22

	inc	byte [memoryPoolSize]
	add	di, MemoryInfo_size
	jmp	.loop
.text db 'Base: %x%X%X%X, Length: %x%X%X%X, Type: %x%X',0xA,0
.hello db 'Memory manager initialized!',0xA,0

.ret:
	cmp	byte [memoryPoolSize], 0
	;jz	.no_memory
	jz	Memory_InitOld

	push	.hello
	call	printf
	add	sp, 2

	ret
; .no_memory:
; 	push	.nomem
; 	call	Terminal_Write
; 	add	sp, 2
.fail:
	call	Panic

;;;;;
;
;
Memory_InitOld:
	InstallInterrupt	INT_API_MEMORY

	int	0x12
	jc	.no_memory
	; ax = ram size in kb
	; ax = ax / 1024 * 16 -> RAM segments, -0x50

	mov	bx, 64
	mul	bx

	cmp	ax, (KERNEL_END + 15) / 16
	jbe	.no_memory

	sub	ax, 0x50

	mov	word [memBlock], (KERNEL_END + 15) / 16
	mov	bx, [memBlock]
	mov	es, bx
	mov	word [es:MemBlock.size], ax
	mov	word [es:MemBlock.next], 0
.ret:
	push	.hello
	call	printf
	add	sp, 2

	call	Memory_PrintMap

	ret
.no_memory:
	push	.nomem
	call	Terminal_Write
	add	sp, 2
	call	Panic

.nomem db 'No memory detected!',0xA,0
.memInfoStr db 'First block: %x, size: %x',0xA,0
.hello db 'Memory manager initialized!',0xA,0

;;;;;;;;;;
; (bp+8) - size in bytes
;;;;;;;;;;
Memory_AllocBytes:
	push	bp
	mov	bp, sp

	push	word [bp + 8]
	push	.info
	call	printf
	add	sp, 4

	add	word [bp+8], 15
	shr	word [bp+8], 4
	pop	bp

	jmp	Memory_AllocSegments

	rpush	bp

	mov	ax, [bp+8]
	add	ax, 15
	shr	ax, 4
	push	ax
	call	Memory_AllocSegments
	add	sp, 2

	rpop
	iret
.info db 'Allocating %u bytes -> ',0,0xA,0

;;;;;;;;;;
; (bp+8) - (word) size in segments (bytes / 16)
;;;;;;;;;;
Memory_AllocSegments:
	rpush	bp, bx, cx, es, fs, gs

	mov	cx, [bp+8]
	inc	cx ; cx = size+1, 1 segment more to save size

	; debug
	push	cx
	push	.info
	call	printf
	add	sp, 4

	; es - current segment
	; fs - prev segment
	; gs - next segment
	mov	es, [memBlock]
	mov	bx, 0
	mov	fs, bx
	mov	gs, [es:MemBlock.next]
.loop:
	cmp	[es:MemBlock.size], cx
	jae	.ok

	cmp	word [es:MemBlock.next], 0
	jz	.fail

.next:	; iterate next element
	mov	bx, es
	mov	fs, bx
	mov	bx, gs
	mov	es, bx
	mov	gs, [es:MemBlock.next]

	jmp	.loop

.ok:
	; TODO check if wanted size = current segment size...
	mov	bx, es
	add	bx, cx
	mov	gs, bx

	mov	bx, [es:MemBlock.size]
	sub	bx, cx
	mov	[gs:MemBlock.size], bx
	mov	bx, [es:MemBlock.next]
	mov	[gs:MemBlock.next], bx

	mov	bx, gs
	mov	[fs:MemBlock.next], bx

	mov	ax, es
	cmp	[memBlock], ax
	jne	.not_first

	mov	[memBlock], bx

.not_first:
	mov	[es:MemBlock.size], cx
	inc	ax

.ret:
	push	ax
	push	.mem
	call	printf
	add	sp, 2

	;call	Memory_PrintMap

	pop	ax

	rpop
	;pop	gs
	;pop	fs
	;pop	es
	;pop	cx
	;pop	bx
	;pop	bp
	iret
.fail:
	push	.nomem
	call	printf
	add	sp, 2

	call	Panic

	mov	ax, 0
	iret
.info db 'Allocating %u segments: ',0;0xA,0
.nomem db 'Not enough free memory!',0xA,0
;.mem db 'OK %x',0xA,0
.mem db '%x',0xA,0

; TODO: fs, gs mustn't be used in 16-bit mode, only qemu allows it...
;       oh, they can be... at least PCem allows it, huh. Error was somewhere else :|
; FIXME: is it working correctly!?
;;;;;
; (bp+8) - segment to free
;;;;;;
Memory_Free:
	rpush	bp, bx, si, es, fs, gs

	; debug
	mov	bx, [bp+8]
	dec	bx
	mov	es, bx
	push	word [es:MemBlock.size]
	push	.info
	call	printf
	add	sp, 4

	mov	si, [bp+8]
	dec	si

	; es - current segment
	; fs - prev segment
	; gs - next segment
	mov	es, [memBlock]
	mov	bx, 0
	mov	fs, bx
	mov	gs, [es:MemBlock.next]

	cmp	si, [memBlock]
	jl	.xchg_first

.loop:
	; si > es && si < gs
	; =
	; 

	mov	bx, gs
	cmp	bx, si
	ja	.next
	mov	bx, es
	cmp	bx, si
	jl	.next
	jmp	.xchg_between

.next:	; iterate next element
	cmp	word [es:MemBlock.next], 0
	jz	.xchg_last

	mov	bx, es
	mov	fs, bx
	mov	bx, gs
	mov	es, bx
	mov	gs, [es:MemBlock.next]

	jmp	.loop

.xchg_between:
	;push	.betweenStr
	;call	printf
	;add	sp, 2

	mov	bx, si

	mov	[es:MemBlock.next], si
	mov	es, si
	mov	[es:MemBlock.next], gs

	jmp	.ret

.xchg_first:
	;push	.firstStr
	;call	printf
	;add	sp, 2

	mov	bx, [memBlock]
	mov	es, si
	mov	[es:MemBlock.next], bx
	mov	[memBlock], si

	jmp	.ret

.xchg_last:
	;push	.lastStr
	;call	printf
	;add	sp, 2

	mov	[es:MemBlock.next], si
	mov	gs, si
	mov	word [gs:MemBlock.next], 0

	jmp	.ret

.ret:
	push	word [memBlock]
	push	.curStr
	call	printf
	add	sp, 4

	call	Memory_Merge

	rpop
	iret
.info db 'Freeing %u segments',0xA,0
;.firstStr db 'First',0xA,0
;.betweenStr db 'Between',0xA,0
;.lastStr db 'Last',0xA,0
.curStr db 'Current first block: %x',0xA,0

Memory_Merge:
	rpush	bx, es, fs, gs

	; es - current segment
	; fs - prev segment
	; gs - next segment
	mov	es, [memBlock]
	mov	bx, 0
	mov	fs, bx
	mov	gs, [es:MemBlock.next]

.loop:
	mov	ax, es
	add	ax, [es:MemBlock.size]
	mov	bx, gs
	cmp	ax, bx
	jne	.next

.merge:
	mov	bx, [gs:MemBlock.size]
	add	[es:MemBlock.size], bx
	mov	bx, [gs:MemBlock.next]
	mov	[es:MemBlock.next], bx

	; iterate next element
	mov	gs, bx
	jmp	.next

.next:	; iterate next element
	cmp	word [es:MemBlock.next], 0
	jz	.ret

	mov	bx, es
	mov	fs, bx
	mov	bx, gs
	mov	es, bx
	mov	gs, [es:MemBlock.next]

	jmp	.loop
.ret:
	rpop
	ret

Memory_GetFree:
	rpush	bx, es

	mov	ax, 0
	cmp	word [memBlock], 0
	jz	.ret

	mov	bx, [memBlock]
	mov	es, bx
.loop:
	add	ax, [es:MemBlock.size]
	mov	bx, [es:MemBlock.next]
	cmp	bx, 0
	jz	.ret
	mov	es, bx
	jmp	.loop

.ret:
	rpop
	iret

;;;;;
;
Memory_PrintMap:
	rpush	ax, bx, es

	push	.map
	call	printf
	add	sp, 2

	cmp	word [memBlock], 0
	jz	.ret

	mov	bx, [memBlock]
	mov	es, bx
.loop:
	mov	ax, [es:MemBlock.size]
	shr	ax, 6
	push	ax
	push	es
	push	.info
	call	printf
	add	sp, 6

	mov	bx, [es:MemBlock.next]
	cmp	bx, 0
	jz	.ret
	mov	es, bx
	jmp	.loop

.ret:
	rpop
	ret
.map db 'Memory map:',0xA,0
.info db 0x9,'Block at %x - %ukB',0xA,0