struc KBD_KEYCODE_t
	.keyCode	resb 1
	.scanCode	resw 1
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

%xdefine KBD_%2 KBD_COUNT

istruc KBD_KEYCODE_t
	at KBD_KEYCODE_t.keyCode,	db KBD_COUNT
%if %0 >= 2
	at KBD_KEYCODE_t.scanCode,	dw %1
  %if %0 >= 3
	at KBD_KEYCODE_t.asciiLow,	db %3
    %if %0 >= 4
	at KBD_KEYCODE_t.asciiHigh,	db %4
    %else
      %if %3 >= 'a' && %3 <= 'z'
	at KBD_KEYCODE_t.asciiHigh,	db ((%3) + ('A' - 'a'))
      %else
      	at KBD_KEYCODE_t.asciiHigh,	db (%3)
      %endif
    %endif
  %endif
%endif

iend

%assign KBD_COUNT KBD_COUNT+1
%endmacro

KBD_KeyCodes:
	KBD_KEYCODE	0x0000, NONE

	KBD_KEYCODE	0x0002, 1, '1', '!'
	KBD_KEYCODE	0x0003, 2, '2', '@'
	KBD_KEYCODE	0x0004, 3, '3', '#'
	KBD_KEYCODE	0x0005, 4, '4', '$'
	KBD_KEYCODE	0x0006, 5, '5', '%'
	KBD_KEYCODE	0x0007, 6, '6', '^'
	KBD_KEYCODE	0x0008, 7, '7', '&'
	KBD_KEYCODE	0x0009, 8, '8', '*'
	KBD_KEYCODE	0x000A, 9, '9', '('
	KBD_KEYCODE	0x000B, 0, '0', ')'

	KBD_KEYCODE	0x000E, BACKSPACE, 0x08

	KBD_KEYCODE	0x0010, Q, 'q'
	KBD_KEYCODE	0x0011, W, 'w'
	KBD_KEYCODE	0x0012, E, 'e'
	KBD_KEYCODE	0x0013, R, 'r'
	KBD_KEYCODE	0x0014, T, 't'
	KBD_KEYCODE	0x0015, Y, 'y'
	KBD_KEYCODE	0x0016, U, 'u'
	KBD_KEYCODE	0x0017, I, 'i'
	KBD_KEYCODE	0x0018, O, 'o'
	KBD_KEYCODE	0x0019, P, 'p'
	KBD_KEYCODE	0x001A, BRACKET_LEFT, '[', '{'
	KBD_KEYCODE	0x001B, BRACKET_RIGHT, ']', '}'
	KBD_KEYCODE	0x001C, ENTER, 0x0A
	; 0x1D ?
	KBD_KEYCODE	0x001E, A, 'a'
	KBD_KEYCODE	0x001F, S, 's'
	KBD_KEYCODE	0x0020, D, 'd'
	KBD_KEYCODE	0x0021, F, 'f'
	KBD_KEYCODE	0x0022, G, 'g'
	KBD_KEYCODE	0x0023, H, 'h'
	KBD_KEYCODE	0x0024, J, 'j'
	KBD_KEYCODE	0x0025, K, 'k'
	KBD_KEYCODE	0x0026, L, 'l'
	KBD_KEYCODE	0x0027, SEMICOLON, ';', ':'
	KBD_KEYCODE	0x0028, QUOTATION_MARK, "'", '"'
	KBD_KEYCODE	0x0029, APOSTROPHE, "`", '~'
	KBD_KEYCODE	0x002A, LSHIFT
	KBD_KEYCODE	0x002B, BACKSLASH, '\', '|'

	KBD_KEYCODE	0x002C, Z, 'z'
	KBD_KEYCODE	0x002D, X, 'x'
	KBD_KEYCODE	0x002E, C, 'c'
	KBD_KEYCODE	0x002F, V, 'v'
	KBD_KEYCODE	0x0030, B, 'b'
	KBD_KEYCODE	0x0031, N, 'n'
	KBD_KEYCODE	0x0032, M, 'm'
	KBD_KEYCODE	0x0033, COMMA, ',', '<'
	KBD_KEYCODE	0x0034, PERIOD, '.', '>'
	KBD_KEYCODE	0x0035, SLASH, '/', '?'
	KBD_KEYCODE	0x0036, RSHIFT

	KBD_KEYCODE	0x0039, SPACE, ' '

	KBD_KEYCODE	0x6047, HOME, '<'
	KBD_KEYCODE	0x604F, END, '>'
	KBD_KEYCODE	0x6049, PAGE_UP, '^'
	KBD_KEYCODE	0x6051, PAGE_DOWN, 'v'

	KBD_KEYCODE	0x604B, LEFT, '<'
	KBD_KEYCODE	0x6048, UP, '^'
	KBD_KEYCODE	0x604D, RIGHT, '>'
	KBD_KEYCODE	0x6050, DOWN, 'v'

KBD_KeyCodes_end:
