# Makefile contributed by jtsiomb

src = bootlogo.asm

.PHONY: all
all: bootlogo.img bootlogo.com

bootlogo.img: $(src)
	nasm -f bin -o $@ $(src)

bootlogo.com: $(src)
	nasm -f bin -o $@ -Dcom_file=1 $(src)

.PHONY: clean
clean:
	$(RM) bootlogo.img bootlogo.com

.PHONY: rundosbox
rundosbox: bootlogo.com
	dosbox $<

.PHONY: runqemu
runqemu: bootlogo.img
	qemu-system-i386 -fda bootlogo.img
