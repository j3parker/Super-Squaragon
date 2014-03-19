all:
	ca65 ss2048.asm
	ld65 -C ldconfig.txt ss2048.o
	cat ss2048.hdr ss2048.prg ss2048.chr > ss2048.nes
