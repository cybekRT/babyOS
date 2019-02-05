NASM		= nasm
BOCHS		= bochs
#PHP		= php
CFS		= ../cFS/cFS-cli/Debug/cFS-cli

ifeq ($(OS),Windows_NT)
	QEMU		= D:\Programs\Qemu\qemu-system-i386
	DOS_IMG		= D:\Programs\Qemu\dos.img
	PCEM		= D:\Programs\PCem\PCem.exe
	BOCHS		= D:\Programs\Bochs\bochsdbg-p4-smp.exe
	PHP		= D:/Workspace/babyOS/php.exe
else
	DOS_IMG		= ~/dos.img
	QEMU		= qemu-system-i386
	PCEM		= wine ~/Downloads/PCem/PCem.exe
	PHP		= php
endif

SRC_DIR		= src
OUT_DIR		= out
LST_DIR		= lst

NASM_FLAGS	= -I$(SRC_DIR)/ -O0 -Wall -D__BASE_FILENAME__="\"$(shell basename $< .asm)\""
QEMU_FLAGS	= -hda $(DOS_IMG) -cpu 486 -boot ac -m 2
BOCHS_FLAGS	= -f bochs.cfg -q

all: image 
#doc

image: out/floppy.img

# Floppy image
out/floppy.img: src/floppy.json boot kernel
	$(CFS) src/floppy.json > /dev/null

# Bootloader
boot: dirs out/boot.bin
out/boot.bin: src/boot/* out/kernel.bin
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/boot.lst -I$(SRC_DIR)/boot/ $(SRC_DIR)/boot/boot.asm -o $(OUT_DIR)/boot.bin

# Kernel
kernel: dirs int int_inc out/kernel.bin
out/kernel.bin: src/kernel/*
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/kernel.lst -I$(SRC_DIR)/kernel/ $(SRC_DIR)/kernel/kernel.asm -o $(OUT_DIR)/kernel.bin

# Interrupts
INT_FILES = ${wildcard ${SRC_DIR}/kernel/int/*.asm}

int: dirs int_inc ${addprefix out/, ${addsuffix .int, ${notdir ${basename ${INT_FILES}}}}}

int_inc: src/kernel/interrupt_codes.inc
src/kernel/interrupt_codes.inc: src/kernel/int/*.asm src/kernel/Memory.asm src/kernel/Terminal.asm
	php src/int.php > $@

out/%.int: src/kernel/int/%.asm src/kernel/*.inc
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/$(shell basename $< .asm).lst -I$(SRC_DIR)/kernel/ $< -o $(OUT_DIR)/$(shell basename $< .asm).int

# Documentation
doc: dirs int_doc

int_doc: int
	$(PHP) src/doc.php > out/babyOS.html

clean:
	rm out/boot.bin out/kernel.bin out/floppy.img out/*.int out/babyOS.html lst/*.lst 2> /dev/null || true
	rm src/kernel/interrupt_codes.inc 2> /dev/null || true
	rmdir out lst 2> /dev/null || true

# Emulators
qemu: image
	$(QEMU) $(QEMU_FLAGS) -fda $(OUT_DIR)/floppy.img -monitor stdio

qemu-debug: image
	$(QEMU) $(QEMU_FLAGS) -fda $(OUT_DIR)/floppy.img -s -S -monitor stdio

dos: image
	$(QEMU) $(QEMU_FLAGS) -fda $(OUT_DIR)/floppy.img -boot c

bochs: image
	$(BOCHS) $(BOCHS_FLAGS)

pcem: image
	$(PCEM)

# Directories
dirs: out lst
out:
	mkdir $(OUT_DIR) 2> /dev/null || true
lst:
	mkdir $(LST_DIR) 2> /dev/null || true

.PHONY: all image boot kernel int clean dirs

# grep -e InstallInterrupt -e InterruptInfo --no-filename `find src/kernel -name *.asm`
# grep -e InterruptInfo --no-filename `find src/kernel -name *.asm` | cut -d' ' -f 3- | sed -En 's/([a-zA-Z])+/\1/'
