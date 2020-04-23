struc LinkedList
	.next resd 1
	.data resd 1,
endstruc

struc LinkedListHead
	.next resd 1
endstruc

%macro ALLOC_LINKED_LIST 1
	%1 times LinkedListHead_size db 0
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Linked list create
; Arguments:
; 	(ebp + 8)	- data
; Returns:
;	eax	- pointer to linked list
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LinkedList_Create:
	rpush	ebp

	push	LinkedListHead_size
	call	Memory_Alloc
	add	esp, 4

	mov	esi, eax
	mov	eax, [ebp + 8]
	mov	dword [esi + LinkedList.next], 0

	mov	eax, esi
	rpop
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Linked list create
; Arguments:
; 	(ebp + 8)	- data
; Returns:
;	eax	- pointer to linked list
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LinkedList_CreateWithData:
	rpush	ebp

	call	LinkedList_Create
	push	eax
	push	dword [ebp + 8]

	call	LinkedList_Insert
	add	esp, 4
	pop	eax

	rpop
	ret

LinkedList_Free:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Linked list create
; Arguments:
; 	(ebp + 8)	- data
; 	(ebp + 12)	- linked list pointer
; Variables:
;	(ebp - 4)	- new allocated entry
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LinkedList_Insert:
	rpush	ebp, ebx

	mov	esi, [ebp + 12]	; linked list entry
	mov	ebx, [ebp + 8]	; data to insert

	push	LinkedList_size
	call	Memory_Alloc
	add	esp, 4

	mov	dword [eax + LinkedList.next], 0
	mov	dword [eax + LinkedList.data], ebx

.addToList:
	mov	ebx, eax
.searchLastEntry:
	cmp	dword [esi + LinkedList.next], 0
	jz	.insertEntry
	mov	esi, [esi + LinkedList.next]
	jmp	.searchLastEntry

.insertEntry:
	mov	dword [esi + LinkedList.next], ebx

	push	esi
	push	ebx
	push	.msg
	call	Terminal_Print
	add	esp, 12

.exit:
	rpop
	ret
.msg db "Inserted: %p at %p",0xA,0

LinkedList_Remove:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Iterate through linked list
; Arguments:
; 	(ebp + 8)	- pointer to next data
; 	(ebp + 12)	- linked list pointer
; Return:
;	*(ebp + 8)	- next data
;	eax	- 1 if pointer is valid, 0 if end of list
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LinkedList_Iterate:
	rpush	ebp

	mov	eax, [ebp + 12]
	mov	ebx, [ebp + 8]
	cmp	dword [ebx], 0
	jnz	.nextEntry
.firstEntry:
	push	dword [eax]
	pop	dword [ebx]
	add	ebx, LinkedList.data

.nextEntry:
	sub	ebx, LinkedList.data
	add	ebx, LinkedList.next
	cmp	dword [ebx], 0
	jz	.endOfList

	push	dword [ebx]
	pop	ebx
	mov	eax, [ebp + 8]
	mov	[eax], ebx
	mov	eax, 1
	jmp	.exit

.endOfList:
	mov	eax, 0
.exit:
	rpop
	ret
