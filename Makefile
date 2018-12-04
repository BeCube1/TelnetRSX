output	= NET.rom

AS	= pasmo
ASFLAGS	=
OFLAG	=

all: $(output)

.SUFFIXES: .rom .asm

.asm.rom:
	$(AS) $(ASFLAGS) $^ $(OFLAG) $@

.PHONY: all clean

clean:
	$(RM) $(output)
