;terminalX dw 0
;terminalY dw 0 
terminalPos dw 0

%define TAB_WIDTH 8

Terminal_Init:
	; mode 2
	mov	ah, 0
	mov	al, 0x2
	int	0x10

	cmp	al, 0x30
	jne	Panic

	; disable blinking
	mov	ah, 1
	mov	cl, 0
	mov	ch, 0b0010000
	int	0x10

	; clear screen
	mov	cx, 80*25

	mov	bx, 0xb800
	mov	es, bx
	mov	bx, 0
.clear_loop:
	mov	byte [es:bx], 0
	mov	byte [es:bx+1], 0x0F

	add	bx, 2
	loop	.clear_loop
	
	ret

; Text: [ds:bp+4]
; NULL-terminated
Terminal_Write:
	push	bp
	mov	bp, sp

	push	ax
	push	si

	mov	si, [bp+4]
.write_loop:
	cmp	byte [ds:si], 0
	je	.ret

	mov	al, [ds:si]
	call	Terminal_Put

	inc	si
	jmp	.write_loop

.ret:
	pop	si
	pop	ax
	pop	bp
	ret

; al - character
Terminal_Put:
	push	ax
	push	bx
	push	es

	; Line feed
	cmp	al, 0xA
	je	.lf
	; Carriage return
	cmp	al, 0xD
	je	.cr
	; Tab
	cmp	al, '	'
	je	.tab

	mov	bx, 0xb800
	mov	es, bx
	mov	bx, [cs:terminalPos]

	mov	byte [es:bx], al
	add	word [cs:terminalPos], 2

	cmp	word [cs:terminalPos], 80*25*2
	jb	.ret
	call	Terminal_Scroll

.ret:
	pop	es
	pop	bx
	pop	ax
	ret
.lf:
	call	Terminal_LineFeed
	jmp	.ret
.cr:
	call	Terminal_CarriageReturn
	jmp	.ret
.tab:
	call	Terminal_Tab
	jmp	.ret

Terminal_LineFeed:
	push	ax
	push	bx
	push	dx

	mov	bx, 80*2
	mov	dx, 0
	mov	ax, [cs:terminalPos]
	div	bx

	sub	word [cs:terminalPos], dx
	add	word [cs:terminalPos], 80*2

	cmp	word [cs:terminalPos], 80*25*2
	jb	.ret
	call	Terminal_Scroll

.ret:
	pop	dx
	pop	bx
	pop	ax
	ret

Terminal_CarriageReturn:
	push	ax
	push	bx
	push	dx

	mov	bx, 80*2
	mov	dx, 0
	mov	ax, [cs:terminalPos]
	div	bx

	sub	word [cs:terminalPos], dx

	pop	dx
	pop	bx
	pop	ax
	ret

Terminal_Tab:
	push	ax
	push	bx
	push	dx

	mov	bx, TAB_WIDTH*2
	mov	dx, 0
	mov	ax, [cs:terminalPos]
	div	bx

	sub	word [cs:terminalPos], dx
	add	word [cs:terminalPos], TAB_WIDTH*2

	cmp	word [cs:terminalPos], 80*25*2
	jb	.ret
	call	Terminal_Scroll

.ret:
	pop	dx
	pop	bx
	pop	ax
	ret

	ret

Terminal_Scroll:
	mov	word [cs:terminalPos], 80*24*2

	push	ax
	push	cx
	push	si
	push	di
	push	ds
	push	es

	; ds:si -> es:di
	mov	si, 0xb800
	mov	ds, si
	mov	es, si
	mov	si, 80*1*2
	mov	di, 0
	mov	cx, 80*24*2
	rep	movsb

	mov	di, 80*24*2
	mov	cx, 80*1
	mov	al, 0
	mov	ah, 0x0F
	rep	stosw

	mov	word [cs:terminalPos], 80*24*2

	pop	es
	pop	ds
	pop	di
	pop	si
	pop	cx
	pop	ax

	ret

;
; (ds:bp+4)	- string location
;
; ax		- used for special characters
; bx		- buffer offset
; cx		- counter
; dx
; si		- current string character
; di		- offset to pointers to variables
;
%define printf Terminal_Print
Terminal_Print:
	push	bp
	mov	bp, sp
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di

	mov	si, [ds:bp+4]
	mov	di, bp
	add	di, 6

.loop:
	mov	al, [si] ; al - character
	inc	si
	cmp	al, 0
	je	.ret

	cmp	al, '%'
	je	.spec_cmp

	call	Terminal_Put
	jmp	.loop

.spec_cmp:
	mov	al, [si]
	; %d
	cmp	al, 'd'
	je	.spec_d
	; %u
	cmp	al, 'u'
	je	.spec_u
	; %s
	cmp	al, 's'
	je	.spec_s
	; %p
	cmp	al, 'p'
	je	.spec_p
	; %x
	cmp	al, 'x'
	je	.spec_x
	; %X
	cmp	al, 'X'
	je	.spec_xx
	; %%
	cmp	al, '%'
	je	.spec_proc

	jmp	.spec_invalid

.spec_d:
	mov	ax, [di]
	add	di, 2

	cmp	ax, 0
	jnz	.spec_d_not_zero
	mov	al, '0'
	call	Terminal_Put
	jmp	.loop
.spec_d_not_zero:
	mov	bx, .bufferEnd
	mov	cx, 10

	test	ax, 0x8000
	jz	.spec_d_loop

	push	ax
	mov	al, '-'
	call	Terminal_Put
	pop	ax
	not	ax
	inc	ax

.spec_d_loop:
	mov	dx, 0
	div	cx
	xchg	dx, ax
	add	al, '0'
	dec	bx
	mov	[bx], al
	mov	ax, dx

	cmp	ax, 0
	jnz	.spec_d_loop

	push	bx
	call	Terminal_Write
	add	sp, 2

	inc	si
	jmp	.loop

.spec_u:
	mov	ax, [di]
	add	di, 2

	cmp	ax, 0
	jnz	.spec_u_not_zero
	mov	al, '0'
	call	Terminal_Put
	jmp	.loop
.spec_u_not_zero:
	mov	bx, .bufferEnd
	mov	cx, 10
	jmp	.spec_d_loop

.spec_s:
	mov	ax, [di]
	add	di, 2

	push	ax
	call	Terminal_Write
	add	sp, 2

	inc	si
	jmp	.loop

;;;;; %p %x ;;;;;
.spec_xx:
	jmp	.spec_x_after_0x
.spec_p:
.spec_x:
	mov	al, '0'
	call	Terminal_Put
	mov	al, 'x'
	call	Terminal_Put
.spec_x_after_0x:
	mov	ax, [di]
	add	di, 2
	mov	cx, 4
.spec_x_loop:
	rol	ax, 4

	push	ax
	and	ax, 0x000f
	cmp	ax, 10
	jb	.spec_x_num
	jmp	.spec_x_alp
	
.spec_x_num:
	add	al, '0'
	call	Terminal_Put
	jmp	.spec_x_loop_end

.spec_x_alp:
	add	al, 'A'-10
	call	Terminal_Put
	jmp	.spec_x_loop_end

.spec_x_loop_end:
	pop	ax
	loop	.spec_x_loop

	inc	si
	jmp	.loop
;;;;; %p %x ;;;;;

.spec_proc:
	call	Terminal_Put
	inc	si
	jmp	.loop

.spec_invalid:
	mov	al, '%'
	call	Terminal_Put
	jmp	.loop

.ret:
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	bp
	ret

.buffer times 7 db 0
.bufferEnd db 0