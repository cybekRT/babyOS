;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Global Descriptor Table
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GDT_data:
dq 0
istruc GDT
	at GDT.limit_0_15, dw 0xffff
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_CODE_READ | GDT_FLAG_SEG_CODE | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend

istruc GDT
	at GDT.limit_0_15, dw 0xffff
	at GDT.base_0_15, dw 0
	at GDT.base_16_23, db 0
	at GDT.flags, db (GDT_FLAG_DATA_WRITE | GDT_FLAG_SEG_DATA | GDT_FLAG_SEG_CODE_OR_DATA | GDT_FLAG_RING_0 | GDT_FLAG_ENTRY_PRESENT)
	at GDT.limit_16_19_attributes, db 0xF | (GDT_ATTRIBUTE_32BIT_SIZE | GDT_ATTRIBUTE_GRANULARITY)
	at GDT.base_24_31, db 0
iend
GDT_data_end:

GDT_Handle:
	dw (GDT_data_end - GDT_data)
	dd GDT_data

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GDT pre-init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[bits 16]
GDT_PreInit:
	lgdt	[GDT_Handle]

	ret
[bits 32]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GDT init
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GDT_Init:
	ret
