SHELL		= bash
NASM		= nasm
BOCHS		= bochs
PHP		= php
CFS		= ../cFS/cFS-cli/cFS-cli

ifeq ($(OS),Windows_NT)
	QEMU		= D:\Programs\Qemu\qemu-system-i386
	DOS_IMG		= D:\Programs\Qemu\dos.img
	PCEM		= D:\Programs\PCem\PCem.exe
	BOCHS		= D:\Programs\Bochs\bochsdbg-p4-smp.exe -f bochs-win.bxrc
	PHP		= D:/Workspace/babyOS/php.exe
	WATCOM		= D:/Programs/Watcom
else
	DOS_IMG		= ~/dos.img
	QEMU		= qemu-system-i386
#	PCEM		= wine ~/Downloads/PCem/PCem.exe
	PCEM		= wine64 ~/Seafile/Programs/PCem/PCem.exe
	PHP		= php
	WATCOM		= D:/Programs/Watcom
	BOCHS		= bochs -f bochs.cfg
endif

SRC_DIR		= src
OUT_DIR		= out
LST_DIR		= lst

NASM_FLAGS	= -I$(SRC_DIR)/ -O0 -Wall -Werror -D__BASE_FILENAME__="\"$(shell basename $< .asm)\""
QEMU_FLAGS	= -hda $(DOS_IMG) -cpu 486 -boot ac -m 32 -soundhw pcspk
BOCHS_FLAGS	= -q

# Suppress warnings 'character constant too long' :/
ifeq ($(shell echo -e "2.13\n"`nasm -v | cut -f3 -d" "` | sort -V | head -n 1),2.13)
NASM_FLAGS += -w-other
endif

all: image 
#doc

image: out/floppy.img

# Floppy image
out/floppy.img: src/floppy.json boot kernel
	$(CFS) src/floppy.json > /dev/null

# Bootloader
boot: dirs out/boot.bin
out/boot.bin: $(SRC_DIR)/boot/boot.asm $(SRC_DIR)/*.inc
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/${addsuffix .lst, ${basename ${notdir $@} .bin}} $< -o $@
# -I$(SRC_DIR)/boot/

# Kernel
kernel: dirs int out/kernel.bin
out/kernel.bin: $(SRC_DIR)/*.inc $(SRC_DIR)/kernel/*.asm $(SRC_DIR)/kernel/*.inc
	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/${addsuffix .lst, ${basename ${notdir $@} .bin}} -I$(SRC_DIR)/kernel/ $(SRC_DIR)/kernel/kernel.asm -o $@

# Interrupts
INT_FILES = ${wildcard ${SRC_DIR}/kernel/int/*.asm} ${wildcard ${SRC_DIR}/kernel/int/*.c}

COM_FILES = ${wildcard ${SRC_DIR}/kernel/com/*.asm}
COM_FILES_OUT = ${addsuffix .com,${addprefix out/,${basename ${notdir $(COM_FILES)}}}}

SRC_EXT = $(INT_FILES) $(COM_FILES_OUT)

int: $(SRC_EXT)
#dirs src/kernel/interrupt_codes.inc ${addprefix out/, ${addsuffix .int, ${notdir ${basename ${INT_FILES}}}}}

src/kernel/interrupt_codes.inc: 
#src/kernel/int/*.asm src/kernel/Memory.asm src/kernel/Terminal.asm
#	$(PHP) src/int.php > $@

out/%.int: 
#src/kernel/int/%.asm src/kernel/*.inc
#	$(NASM) $(NASM_FLAGS) -l$(LST_DIR)/$(shell basename $< .asm).lst -I$(SRC_DIR)/kernel/ $< -o $@

out/%.com: src/kernel/com/%.asm
	nasm $< -o $@ -l$(LST_DIR)/${addsuffix .lst, ${basename ${notdir $@} .bin}}

out/%.int: 
#src/kernel/int/%.c src/kernel/*.inc Makefile
#	rm $(basename $<).obj 2>/dev/null || true
#	./watcom.cmd $< $(basename $<).obj $@ $(WATCOM) 2>/dev/null
#wine cmd /c watcom.cmd $< $(basename $<).obj $@ $(WATCOM) 2>/dev/null || true

# Documentation
doc: dirs int_doc

int_doc: 
#int
#	$(PHP) src/doc.php > out/babyOS.html

clean:
	rm out/boot.bin out/kernel.bin out/floppy.img out/*.int out/babyOS.html lst/*.lst 2> /dev/null || true
	rm src/kernel/interrupt_codes.inc 2> /dev/null || true
	rm $(COM_FILES_OUT) 2> /dev/null || true
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
