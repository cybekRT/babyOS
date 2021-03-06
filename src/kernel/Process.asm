struc Process_t
	.pid resd 0

	.eflags resd 1
	.eax resd 1
	.ebx resd 1
	.ecx resd 1
	.edx resd 1
	.esi resd 1
	.edi resd 1

	.eip resd 1
	.cs resd 1

	.ebp resd 1
	.esp resd 1
	.stack resd 1
endstruc

struc ProcessEntry_t
	.union resb Process_t_size
	.next resd 1
endstruc

processes_size dd 0
processes_list dd 0
current_process dd 0
process_last_pid dd 0

STACK_SIZE equ 8192

Process_Init:
	mov	ebp, esp

	push	dword ProcessEntry_t_size
	call	Memory_Alloc
	add	esp, 4

	mov	ebx, eax
	mov	[processes_list], ebx
	inc	dword [processes_size]

	; memset zero
	mov	al, 0
	mov	edi, ebx
	mov	ecx, ProcessEntry_t_size
	rep	stosb

	mov	[ebx + Process_t.pid], dword 0

	push	dword STACK_SIZE
	call	Memory_Alloc
	add	esp, 4

	mov	[ebx + Process_t.stack], eax
	add	eax, STACK_SIZE
	mov	esp, eax
	push	dword [ebp]

	mov	[current_process], ebx

	ret

Process_SchedulerFromIRQ:
	add	esp, 4
Process_Scheduler:
	cli

	; Save context
	push	eax
	mov	eax, [current_process]
	
	pop	dword [eax + Process_t.eax]
	mov	[eax + Process_t.ebx], ebx
	mov	[eax + Process_t.ecx], ecx
	mov	[eax + Process_t.edx], edx
	mov	[eax + Process_t.esi], esi
	mov	[eax + Process_t.edi], edi
	mov	[eax + Process_t.ebp], ebp

	pop	dword [eax + Process_t.eip]
	pop	dword [eax + Process_t.cs]
	pop	dword [eax + Process_t.eflags]

	mov	[eax + Process_t.esp], esp

	mov	eax, [eax + ProcessEntry_t.next]
	test	eax, eax
	jnz	.not_zero
	mov	eax, [processes_list]
.not_zero:
	mov	[current_process], eax

	mov	ebx, [eax + Process_t.ebx]
	mov	ecx, [eax + Process_t.ecx]
	mov	edx, [eax + Process_t.edx]
	mov	esi, [eax + Process_t.esi]
	mov	edi, [eax + Process_t.edi]
	mov	ebp, [eax + Process_t.ebp]
	mov	esp, [eax + Process_t.esp]

	push	dword [eax + Process_t.cs]
	push	dword [eax + Process_t.eip]
	push	dword [eax + Process_t.eflags]

	mov	eax, [eax + Process_t.eax]

	popf
	sti
	retf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Process spawn
; Arguments:
; 	(ebp + 8) - entry point
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Process_Spawn:
	cli
	rpush	ebp, eax, edi
	pushf

	;push	.preMsg
	;call	Terminal_Print
	;add	esp, 4

	mov	edi, [processes_list]
.find_last_entry:
	cmp	[edi + ProcessEntry_t.next], dword 0
	jz	.found_last_entry
	mov	edi, [edi + ProcessEntry_t.next]
	jmp	.find_last_entry

.found_last_entry:
	push	dword ProcessEntry_t_size
	call	Memory_Alloc
	add	esp, 4

	inc	dword [processes_size]
	mov	[edi + ProcessEntry_t.next], eax

	mov	edi, eax
	mov	al, 0
	mov	ecx, ProcessEntry_t_size
	push	edi
	rep	stosb
	pop	edi

	;pushf
	;pop	dword [edi + Process_t.eflags]
	;mov	dword [edi + Process_t.eflags], 0

	push	dword STACK_SIZE
	call	Memory_Alloc
	add	esp, 4

	mov	[edi + Process_t.stack], eax
	add	eax, STACK_SIZE
	mov	[edi + Process_t.esp], eax
	
	mov	[edi + Process_t.cs], dword 0x8
	mov	eax, [ebp + 8]
	mov	[edi + Process_t.eip], eax
	mov	[edi + Process_t.eax], eax

	mov	eax, Timer_Delay
	mov	[edi + Process_t.ebx], eax

	inc	dword [process_last_pid]
	mov	eax, [process_last_pid]
	mov	[edi + Process_t.pid], eax

	push	dword [edi + Process_t.eip]
	push	dword [edi + Process_t.pid]
	push	.msg
	call	Terminal_Print
	add	esp, 12

.exit:
	popf
	rpop
	sti
	ret
.preMsg db "Spawning process...",0xA,0
.msg db "Spawned process (%u) -> %p",0xA,0
