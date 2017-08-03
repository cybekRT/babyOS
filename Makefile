
ifeq ($(OS),Windows_NT)
	NASM		= D:\Programs\Nasm\nasm
	DOS_IMG		= D:\Programs\Qemu\dos.img
	QEMU		= D:\Programs\Qemu\qemu
	FLOPPY		= utils\babyFloppy\babyFloppy.exe
else
	NASM		= nasm
	DOS_IMG		= ~/dos.img
	QEMU		= qemu-system-i386
	BOCHS		= bochs
	FLOPPY		= utils\babyFloppy\babyFloppy
endif

SRC_DIR		= src
OUT_DIR		= out
LST_DIR		= lst

NASM_FLAGS	= -I$(SRC_DIR)/
QEMU_FLAGS	= -hda $(DOS_IMG) -cpu 486 -boot ac -m 32
BOCHS_FLAGS	= -f bochs.cfg -q

all: image

image: out/floppy.img
out/floppy.img: out/boot.bin out/kernel.bin
	cat out/boot.bin out/kernel.bin > out/floppy.img

boot: out/boot.bin
out/boot.bin: src/boot/* out/kernel.bin
	$(NASM) $(NASM_FLAGS) -I$(SRC_DIR)/boot/ -DKERNEL_SIZE=$(shell stat -f"%z" out/kernel.bin) $(SRC_DIR)/boot/boot.asm -o $(OUT_DIR)/boot.bin

kernel: out/kernel.bin
out/kernel.bin: src/kernel/*
	$(NASM) $(NASM_FLAGS) -I$(SRC_DIR)/kernel/ $(SRC_DIR)/kernel/kernel.asm -o $(OUT_DIR)/kernel.bin

clean:
	rm out/boot.bin out/kernel.bin out/floppy.img || true

qemu: image
	$(QEMU) $(QEMU_FLAGS) -fda $(OUT_DIR)/floppy.img -monitor stdio

bochs: image
	$(BOCHS) $(BOCHS_FLAGS)

.PHONY: all image boot kernel clean

#,format=raw

#.PHONY: all clean utils
#all: utils #boot kernel image run

#utils:
#	$(MAKE) -C utils

#boot: out/boot
#kernel: out/kernel.bin

#out/boot: $(SRC_DIR)/*.asm $(SRC_DIR)/*/*.asm
#	$(NASM) $(NASM_FLAGS) $(SRC_DIR)/boot.asm -o $(OUT_DIR)/boot

#out/kernel.bin: $(SRC_DIR)/*.asm $(SRC_DIR)/*/*.asm
#	$(NASM) $(NASM_FLAGS) $(SRC_DIR)/kernel/kernel.asm -o $(OUT_DIR)/kernel.bin

#image: utils boot kernel
#	$(FLOPPY) -b $(OUT_DIR)/boot -a $(OUT_DIR)/kernel.bin -l babyOS -c 1 -o $(OUT_DIR)/floppy.img

#run: image
#	$(QEMU) -fda $(OUT_DIR)/floppy.img $(QEMU_FLAGS)

#clean:
#	$(MAKE) -C utils clean
#	del /Q /S $(OUT_DIR)\*
