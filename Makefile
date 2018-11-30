output	= NET.rom

AS	= rasm
ASFLAGS	=
OFLAG	= -ob

all: $(output)

.SUFFIXES: .rom .asm

.asm.rom:
	$(AS) $(ASFLAGS) $^ $(OFLAG) $@

.PHONY: all clean

clean:
	$(RM) $(output)
