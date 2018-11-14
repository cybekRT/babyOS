ifeq ($(OS),Windows_NT)
	NASM		= nasm
	DOS_IMG		= D:\Programs\Qemu\dos.img
	QEMU		= D:\Programs\Qemu\qemu-system-i386
	BOCHS		= bochs
	PCEM		=
	CFS		= ../cFS/cFS-cli/Debug/cFS-cli.exe
else
	NASM		= nasm
	DOS_IMG		= ~/dos.img
	QEMU		= qemu-system-i386
	BOCHS		= bochs
	PCEM		= wine ~/Downloads/PCem/PCem.exe
	CFS		= ../cFS/cFS-cli/Debug/cFS-cli
	PHP		= php
endif

SRC_DIR		= src
OUT_DIR		= out
LST_DIR		= lst

NASM_FLAGS	= -I$(SRC_DIR)/ -O0 -Wall
QEMU_FLAGS	= -hda $(DOS_IMG) -cpu 486 -boot ac -m 2
BOCHS_FLAGS	= -f bochs.cfg -q

all: image doc

image: out/floppy.img

# Floppy image
out/floppy.img: src/floppy.json boot kernel
	$(CFS) src/floppy.json > /dev/null

# Bootloader
boot: dirs out/boot.bin
out/boot.bin: src/boot/* out/kernel.bin
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/boot.lst -I$(SRC_DIR)/boot/ $(SRC_DIR)/boot/boot.asm -o $(OUT_DIR)/boot.bin

# Kernel
kernel: dirs out/kernel.bin int
out/kernel.bin: src/kernel/*
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/kernel.lst -I$(SRC_DIR)/kernel/ $(SRC_DIR)/kernel/kernel.asm -o $(OUT_DIR)/kernel.bin

# Interrupts
int: src/kernel/int/*.asm
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/$(shell basename $< .asm).lst -I$(SRC_DIR)/kernel/ $< -o $(OUT_DIR)/$(shell basename $< .asm).int

# Documentation
doc: int_doc

int_doc: int
	$(PHP) src/doc.php > out/babyOS.html

clean:
	rm out/boot.bin out/kernel.bin out/floppy.img out/*.int out/babyOS.html lst/*.lst 2> /dev/null || true
	rmdir out lst 2> /dev/null || true

# Emulators
qemu: image
	$(QEMU) $(QEMU_FLAGS) -fda $(OUT_DIR)/floppy.img -monitor stdio

qemu-debug: image
	$(QEMU) $(QEMU_FLAGS) -fda $(OUT_DIR)/floppy.img -s -S

bochs: image
	$(BOCHS) $(BOCHS_FLAGS)

pcem: image
	$(PCEM) 2>/dev/null

# Directories
dirs:
	mkdir $(OUT_DIR) $(LST_DIR) 2> /dev/null || true

.PHONY: all image boot kernel int clean dirs out lst

# grep -e InstallInterrupt -e InterruptInfo --no-filename `find src/kernel -name *.asm`
# grep -e InterruptInfo --no-filename `find src/kernel -name *.asm` | cut -d' ' -f 3- | sed -En 's/([a-zA-Z])+/\1/'
