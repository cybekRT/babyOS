[bits 16]
%define OS_NAME 'babyOS v0.1'

%macro rpush 0-*
%push stackframe
	;push	bp
	;mov	bp, sp
	%rep %0
		push	%1
		%ifidni %1, bp
			mov	bp, sp
		%endif
		%rotate 1
	%endrep
	jmp	short %$ok
%$pop:
	%rep %0
		%rotate -1
		pop	%1
	%endrep
	;pop	bp
	jmp	%$ret
%$ok:
%endmacro

%macro rpop 0
	jmp	%$pop
%$ret:
	%pop
%endmacro