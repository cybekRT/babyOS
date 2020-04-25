PAGE_DIRECTORY_FLAG_PRESENT		equ (1 << 0)
PAGE_DIRECTORY_FLAG_READONLY		equ (0 << 1)
PAGE_DIRECTORY_FLAG_READ_WRITE		equ (1 << 1)
PAGE_DIRECTORY_FLAG_USER		equ (0 << 2)
PAGE_DIRECTORY_FLAG_SUPERVISOR		equ (1 << 2)
PAGE_DIRECTORY_FLAG_WRITE_THROUGH	equ (1 << 3)
PAGE_DIRECTORY_FLAG_CACHE_ENABLED	equ (0 << 4)
PAGE_DIRECTORY_FLAG_CACHE_DISABLED	equ (1 << 4)
PAGE_DIRECTORY_FLAG_ACCESSED		equ (1 << 5)
PAGE_DIRECTORY_FLAG_PAGE_4K		equ (0 << 7)
PAGE_DIRECTORY_FLAG_PAGE_4M		equ (1 << 7)

PAGE_TABLE_FLAG_PRESENT		equ (1 << 0)
PAGE_TABLE_FLAG_READONLY		equ (0 << 1)
PAGE_TABLE_FLAG_READ_WRITE		equ (1 << 1)
PAGE_TABLE_FLAG_USER		equ (0 << 2)
PAGE_TABLE_FLAG_SUPERVISOR		equ (1 << 2)
PAGE_TABLE_FLAG_WRITE_THROUGH	equ (1 << 3)
PAGE_TABLE_FLAG_CACHE_ENABLED	equ (0 << 4)
PAGE_TABLE_FLAG_CACHE_DISABLED	equ (1 << 4)
PAGE_TABLE_FLAG_ACCESSES		equ (1 << 5)
PAGE_TABLE_FLAG_DIRTY		equ (1 << 6)
PAGE_TABLE_FLAG_GLOBAL		equ (1 << 7)

%define PAGE_TABLE_ADDRESS(addr) (addr & 0xFFFFF000)
%define PAGE_TABLE_ENTRY(addr, flags) (PAGE_TABLE_ADDRESS(addr) | flags)

struc PageDirectoryEntry
	.data resd 1
endstruc

struc PageTableEntry
	.data resd 1
endstruc

pagingDirectory dd 0
Paging_Init:
	mov	ecx, 1024 * PageDirectoryEntry_size * 2
	;push	1024 * PageDirectoryEntry_size
	push	ecx
	call	Memory_Alloc
	add	esp, 4

	add	eax, 0xFFF
	and	eax, 0xFFFFF000
	mov	[pagingDirectory], eax

	mov	edi, eax
	mov	ecx, 4096
	mov	al, 0x00
	rep stosb

	; Alloc first page
	mov	ebx, [pagingDirectory]
	push	1024 * PageTableEntry_size * 2
	push	Memory_Alloc
	add	esp, 4

	push	eax

	; Fill
	mov	ecx, 1024
.fillEntries:


	loop	.fillEntries

	; Write first directory entry

	; Write to register
	mov	eax, [pagingDirectory]
	mov	cr3, eax

	mov	eax, cr0
	or	eax, 0x80000001
	mov	cr0, eax

	ret