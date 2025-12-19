ASM = nasm
BOOT_BIN = boot.bin
GAME_BIN = game.bin
IMG = pong.img
ISO = pong_os.iso
ISO_DIR = iso_root

all: $(IMG) $(ISO)

$(IMG): boot.asm game.asm
	$(ASM) -f bin boot.asm -o $(BOOT_BIN)
	$(ASM) -f bin game.asm -o $(GAME_BIN)
	@truncate -s %512 $(GAME_BIN)
	cat $(BOOT_BIN) $(GAME_BIN) > $(IMG)
	@truncate -s 1474560 $(IMG)
	@echo "[+] Success build $(IMG)"

$(ISO): $(IMG) isolinux.cfg
	@mkdir -p $(ISO_DIR)
	@cp $(IMG) $(ISO_DIR)/
	@cp isolinux.cfg $(ISO_DIR)/
	@cp /usr/lib/ISOLINUX/isolinux.bin $(ISO_DIR)/ 2>/dev/null || true
	@cp /usr/lib/syslinux/modules/bios/*.c32 $(ISO_DIR)/ 2>/dev/null || true
	@cp /usr/lib/syslinux/memdisk $(ISO_DIR)/ 2>/dev/null || true
	# Memastikan poweroff.c32 tersalin dari berbagai kemungkinan path sistem
	@cp /usr/lib/syslinux/modules/bios/poweroff.c32 $(ISO_DIR)/ 2>/dev/null || true
	genisoimage -o $(ISO) -b isolinux.bin -c boot.cat -no-emul-boot \
		-boot-load-size 4 -boot-info-table $(ISO_DIR)
	@echo "[+] Success build $(ISO)"

run-iso: $(ISO)
	qemu-system-i386 -cdrom $(ISO)

run-img: $(IMG)
	qemu-system-i386 -drive format=raw,file=$(IMG),if=floppy

clean:
	rm -rf $(BOOT_BIN) $(GAME_BIN) $(IMG) $(ISO) $(ISO_DIR)

.PHONY: all clean run-iso run-img
