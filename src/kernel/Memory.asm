; Memory manager
; memBlock - first free block, 0 if no free memory
;	[memBlockPos + 0] -> blockSize
;	[memBlockPos + 2] -> nextBlockPos, 0 if last entry
;

InterruptInfo Memory_Init, Memory_GetFree, Memory_AllocSegments, Memory_AllocBytes, Memory_Free, Memory_PrintMap

struc MemBlock
	.size resw 1
	.next resw 1
endstruc

memBlock dw 0

;memBlock istruc MemBlock
;	at MemBlock.size, dw 0
;	at MemBlock.next, dw 0
;iend

;;;;;;;;;;;;;;;;;;;;
;
; Initialize memory manager
;
;;;;;;;;;;;;;;;;;;;;
Memory_Init:
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

	mov	word [cs:memBlock], (KERNEL_END + 15) / 16
	mov	bx, [cs:memBlock]
	mov	es, bx
	mov	word [es:MemBlock.size], ax
	mov	word [es:MemBlock.next], 0
.ret:
	push	.hello
	;call	printf
	add	sp, 2

	;call	Memory_PrintMap

	ret
.no_memory:
	push	.nomem
	call	Terminal_Write
	add	sp, 2
	call	Panic

.nomem db 'No memory detected!',0xA,0
.memInfoStr db 'First block: %x, size: %x',0xA,0
.hello db 'Memory manager initialized!',0xA,0

;;;;;;;;;;;;;;;;;;;;
;
; Alloc memory
; Input:
;	(bp+8) - size in bytes
;
;;;;;;;;;;;;;;;;;;;;
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

;;;;;;;;;;;;;;;;;;;;
;
; Alloc memory
; Input:
;	(bp+8) - size in segments (bytes / 16)
;
;;;;;;;;;;;;;;;;;;;;
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
	mov	es, [cs:memBlock]
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
	cmp	[cs:memBlock], ax
	;xchg	bx, bx
	jne	.not_first

	mov	[cs:memBlock], bx

.not_first:
	mov	[es:MemBlock.size], cx
	inc	ax

.ret:
	push	ax
	push	.mem
	call	printf
	add	sp, 2

	pop	ax

	rpop
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
;;;;;;;;;;;;;;;;;;;;
;
; Free allocated memory
; Input:
;	(bp+8) - pointer to free
;
;;;;;;;;;;;;;;;;;;;;
Memory_Free:
	rpush	bp, bx, si, es, fs, gs

	; debug
	mov	bx, [bp+8]
	;push	bx
	dec	bx
	mov	es, bx
	push	word [es:MemBlock.size]
	push	word [bp + 8]
	push	.info
	call	printf
	add	sp, 6

	mov	si, [bp+8]
	dec	si

	; es - current segment
	; fs - prev segment
	; gs - next segment
	mov	es, [cs:memBlock]
	mov	bx, 0
	mov	fs, bx
	mov	gs, [es:MemBlock.next]

	cmp	si, [cs:memBlock]
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

	mov	bx, [cs:memBlock]
	mov	es, si
	mov	[es:MemBlock.next], bx
	mov	[cs:memBlock], si

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
	push	word [cs:memBlock]
	push	.curStr
	call	printf
	add	sp, 4

	call	Memory_Merge

	rpop
	iret
.info db 'Freeing %x - %u segments',0xA,0
;.firstStr db 'First',0xA,0
;.betweenStr db 'Between',0xA,0
;.lastStr db 'Last',0xA,0
.curStr db 'Current first block: %x',0xA,0

Memory_Merge:
	rpush	bx, es, fs, gs

	; es - current segment
	; fs - prev segment
	; gs - next segment
	mov	es, [cs:memBlock]
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

;;;;;;;;;;;;;;;;;;;;
;
; Get free memory in segments
; Output:
;	ax - free memory in segments
;
;;;;;;;;;;;;;;;;;;;;
Memory_GetFree:
	rpush	bx, es

	mov	ax, 0
	cmp	word [cs:memBlock], 0
	jz	.ret

	mov	bx, [cs:memBlock]
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

;;;;;;;;;;;;;;;;;;;;
;
; Prints memory map in terminal
;
;;;;;;;;;;;;;;;;;;;;
Memory_PrintMap:
	rpush	ax, bx, ds, es

	push	cs
	pop	ds

	push	.map
	;call	printf
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT
	add	sp, 2

	cmp	word [cs:memBlock], 0
	jz	.ret

	mov	bx, [cs:memBlock]
	mov	es, bx
.loop:
	mov	ax, [es:MemBlock.size]

	cmp	ax, 256 ; <= 4096
	jbe	.loop_b
	jmp	.loop_kb
.loop_b:
	shl	ax, 4
	push	ax
	push	es
	push	.infoB
	jmp	.loop_print
.loop_kb:
	shr	ax, 6
	push	ax
	push	es
	push	.infokB
.loop_print:
	push	2
	ApiCall	INT_API_TERMINAL, TERMINAL_INT_PRINT_ARGS
	add	sp, 8

	mov	bx, [es:MemBlock.next]
	cmp	bx, 0
	jz	.ret
	mov	es, bx
	jmp	.loop

.ret:
	rpop
	iret
.map db 'Memory map:',0xA,0
.infokB db 0x9,'Block at %x - %ukB',0xA,0
.infoB db 0x9,'Block at %x - %uB',0xA,0
