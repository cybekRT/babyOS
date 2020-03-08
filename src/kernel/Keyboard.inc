struc KBD_KEYCODE_t
	.keyCode	resb 1
	.scanCode	resb 2
	.asciiLow	resb 1
	.asciiHigh	resb 1
	resb 3
endstruc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Macro to define new keycode
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro KBD_KEYCODE 1-4

%ifndef KBD_COUNT_DEF
	%assign KBD_COUNT 0
	%define KBD_COUNT_DEF
%endif

%xdefine KBD_%1 KBD_COUNT

istruc KBD_KEYCODE_t
	at KBD_KEYCODE_t.keyCode,	db KBD_COUNT
	at KBD_KEYCODE_t.scanCode,	db %4
	at KBD_KEYCODE_t.asciiLow,	db %2
	at KBD_KEYCODE_t.asciiHigh,	db %3
iend

%assign KBD_COUNT KBD_COUNT+1
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Macro to define new scancode
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;scanCodeMap:

;%macro KBD_KEYCODES 1-*
;
;%rep %0
;	KBD_KEYCODE	%1
;	%rotate	1
;%endrep
;
;%endmacro

;KBD_KEYCODES	ESC, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12

;KBD_KEYCODE	ESC
;KBD_KEYCODE	F1
;KBD_KEYCODE	F2
;KBD_KEYCODE	F3
;db 0x00

KBD_KeyCodes:
	KBD_KEYCODE	NONE
	KBD_KEYCODE	A, 'a', 'A', 0x1E
	KBD_KEYCODE	B, 'b', 'B', 0x30
	KBD_KEYCODE	C, 'c', 'C', 0x2E
KBD_KeyCodes_end:
