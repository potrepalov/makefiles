# rules.mk
#
# Правила компиляции, цели
#
# GOALS:
# clean	- clean working dirs
# flash - files for programm flash
# eeprom - files for programm eeprom (if exist)
# lst	- listing
# elf   - .elf file
# tag   - tags, cscope.out
#
# fhex	- Intel .hex for flash
# ehex	- Intel .hex for eeprom
# fsrec	- Motorola .srec for flash
# esrec	- Motorola .srec for eeprom
# fbin	- .bin for flash
# ebin	- .bin for eeprom
#
# hex, bin, srec
#

all: clean flash eeprom lst
flash: fhex fbin fsrec
eeprom: ehex ebin esrec


CFLAGS += -fno-common
CFLAGS += -fshort-enums -Wswitch -funsigned-char
CFLAGS += -funsigned-bitfields
CFLAGS += -finline-functions-called-once
CFLAGS += -foptimize-sibling-calls
CFLAGS += -ffunction-sections 
CFLAGS += -fzero-initialized-in-bss
CFLAGS += -Wdiv-by-zero -Wempty-body -Wfloat-equal
CFLAGS += -Wignored-qualifiers
CFLAGS += -Wimplicit-function-declaration -Wimplicit-int -Wmissing-braces
CFLAGS += -Wmissing-declarations -Wmissing-parameter-type -Wmissing-prototypes
CFLAGS += -Wmultichar -Wnonnull -Wparentheses -Wreturn-type
CFLAGS += -Wsequence-point -Wsign-compare -Wsign-conversion
CFLAGS += -Wstrict-prototypes -Wtype-limits
CFLAGS += -Woverflow -Wuninitialized

LDFLAGS += -Wl,--gc-section,--reduce-memory-overheads,--relax

$(foreach lang,$(LANGS),                        \
	$(foreach id,$($(lang)_INCLUDE_DIRS),   \
		$(eval $(lang)FLAGS += -I $(id))))
$(foreach lang,$(LANGS),                        \
	$(foreach id,$(INCLUDE_DIRS),           \
		$(eval $(lang)FLAGS += -I $(id))))

$(foreach id,$(LD_INCLUDE_DIRS), $(eval LDFLAGS += -Wl,-L$(id)))


.PHONY: all clean flash eeprom lst elf tag
.PHONY: fhex ehex fsrec esrec fbin ebin
.PHONY: hex bin srec flash eeprom


ifndef OBJDIR
OBJDIR := obj/
else
OBJDIR := $(OBJDIR:%/=%)/
endif

PROGDIR := $(OBJDIR)


AVR_MCUs	:=	\
	atmega16	\
	atmega64	\
	atxmega64a1	\
	atxmega64a3	\



ARM_MCUs	:=	\
	STM32F429xx	\



CMP             ?= cmp
CP              ?= cp
MKDIR           ?= mkdir -p
MV              ?= mv
RM              ?= rm
SED             ?= sed
HEAD            ?= head
HOST_CC         ?= gcc
CTAGS           ?= ctags
CSCOPE          ?= cscope
ECHO            ?= echo



# определяем насколько будем подниматься до самого верхнего из обрабатываемых
# каталогов (если такие есть) и на соответствующую глубину опускаем каталог
# с объектными файлами
$(foreach lang,$(LANGS), $(eval ALL_SRCS := $(ALL_SRCS) $($(lang)_SRC)) )

MK_DIRS :=
MAX_DOWNDIRS :=
DOWNDIRS :=

# del_updir  src_file, updirs
define del_updir
$(eval DOWNDIRS := u/$(2))
$(eval $(if $(findstring $(DOWNDIRS),$(MAX_DOWNDIRS)),,     \
	$(eval MAX_DOWNDIRS := $(DOWNDIRS)) ))
$(eval $(call proc_name,$(patsubst ../%,%,$(1)),$(DOWNDIRS)))
endef

# proc_name  src_file, updirs
define proc_name
$(eval $(if $(subst 1,,$(patsubst ../%,1,$(1))),,       \
	$(eval $(call del_updir,$(1),$(2)))             \
))
endef


$(eval $(foreach name, $(ALL_SRCS), $(eval MK_DIRS += $(dir $(name)))))
MK_DIRS := $(sort $(MK_DIRS))
$(foreach name,$(MK_DIRS), $(eval $(call proc_name,$(name),)) )
OBJDIR := $(OBJDIR)$(MAX_DOWNDIRS)
MK_DIRS := $(MK_DIRS:%=$(OBJDIR)%)



LD_FLAGS        := $(LDFLAGS) -Wl,-Map,$(PROGDIR)$(PRG).map

C_FLAGS         := $(CFLAGS) $(OPTIMIZE) $(REGS)
C_OBJS          := $(C_SRC:%.c=$(OBJDIR)%.o)
C_DEPS          := $(C_OBJS:%=%.d)

CPP_FLAGS       := $(CPPFLAGS) $(OPTIMIZE) $(REGS)
CPP_OBJS        := $(CPP_SRC:%.cpp=$(OBJDIR)%.o)
CPP_DEPS        := $(CPP_OBJS:%=%.d)

AS_FLAGS        := $(ASFLAGS) $(OPTIMIZE) $(REGS)
AS_OBJS         := $(AS_SRC:%.S=$(OBJDIR)%.o)
AS_DEPS         := $(AS_OBJS:%=%.d)

OBJS            := $(C_OBJS) $(CPP_OBJS) $(AS_OBJS)
DEPS            := $(C_DEPS) $(CPP_DEPS) $(AS_DEPS)

.SECONDARY : $(OBJS) $(DEPS)



lst:  $(PRG).lst
elf:  $(PROGDIR)$(PRG).elf

.SECONDARY : $(PROGDIR)$(PRG).elf




#####################################
# Test for ARM architecture
ifneq (,$(findstring $(MCU_TARGET),$(ARM_MCUs)))


hex:  $(PRG).hex
bin:  $(PRG).bin
srec: $(PRG).srec
fhex: hex
fbin: bin
fsrec: srec
ehex:
ebin:
esrec:



LD_FLAGS        += -T $(LD_MEMORY_SCRIPT)
LD_FLAGS        += -T sections.ld

CC_FLAGS        := -D$(MCU_TARGET)
CC_FLAGS        += -nostartfiles -mthumb -march=armv7e-m
CC_FLAGS        += -mfloat-abi=hard -mfpu=fpv4-sp-d16 -specs=nosys.specs

CC              := arm-gcc $(CC_FLAGS)
OBJCOPY         := arm-objcopy
OBJDUMP         := arm-objdump


# for ARM those vars are empty
rm-eeprom-files =
make-heap-start-h =
rm-heap-start-h =
make-crc-of-hex =
getcrc_hex =
make-crc-of-bin =
getcrc_bin =


#####################################
# Test for AVR architecture
else ifneq (,$(findstring $(MCU_TARGET),$(AVR_MCUs)))


ifneq (,$(strip $(DATA_START)))
# память, распределяемая вручную, располагается по младшим адресам
LD_FLAGS += -Wl,--section-start,.data=$(DATA_START)
endif

# байт EEPROM с адресом 0 не используем
LD_FLAGS += -Wl,--section-start,.eeprom=0x810001


hex: fhex ehex
bin: fbin ebin
srec: fsrec esrec
fhex:  $(PRG).hex
fbin:  $(PRG).bin
fsrec: $(PRG).srec
ehex:  $(PRG)_eeprom.hex
ebin:  $(PRG)_eeprom.bin
esrec: $(PRG)_eeprom.srec


C_FLAGS         += -mstrict-X
CPP_FLAGS       += -mstrict-X

CC_FLAGS        := -mmcu=$(MCU_TARGET)

ifneq (,$(strip $(FIXED_REGS)))
$(foreach reg,$(FIXED_REGS),$(eval CC_FLAGS += -ffixed-$(reg)))
endif


CC              := avr-gcc $(CC_FLAGS)
OBJCOPY         := avr-objcopy -j .text -j .data 
EEPROMCOPY      := avr-objcopy -j .eeprom --change-section-lma .eeprom=1 
OBJDUMP         := avr-objdump


define rm-eeprom-files
 -@$(RM) -rf $(PRG)_eeprom.hex $(PRG)_eeprom.bin $(PRG)_eeprom.srec
endef

#####################################
# helper for make 'heap-start.h' file
#
ifdef MAKE_HEAP_START_H

define make-heap-start-h
 @$(ECHO) "/* DO NOT EDIT THIS FILE! */" > new-heap-start.h
 @$(ECHO) "/* This file is auto generated */" >> new-heap-start.h
 @$(SED) -e "/_Heap_Begin/!d"   \
    -r -e "s/([[:space:]]*0x)([^[:space:]]+).*/#define HEAP_START 0x\2/" \
    $(PROGDIR)$(PRG).map >> new-heap-start.h
 @$(SED) -e "/_Heap_Limit/!d"   \
    -r -e "s/([[:space:]]*0x)([^[:space:]]+).*/#define HEAP_END 0x\2/" \
    $(PROGDIR)$(PRG).map >> new-heap-start.h
 @if $(CMP) -s new-heap-start.h heap-start.h ;      \
    then $(RM) new-heap-start.h ;    \
    else $(MV) -f new-heap-start.h heap-start.h ;   \
    $(MAKE) $(PROGDIR)$(PRG).elf ;   \
 fi
endef

define rm-heap-start-h
 -@$(RM) heap-start.h
endef

else

make-heap-start-h =
rm-heap-start-h =

endif
#
# helper for make 'heap-start.h' file
#####################################


#####################################
# helper for make crc of programm file
#
ifdef MAKE_CRC_OF_FILE

define GETCRC_SOURCE_HEX
/* getcrc-hex.c */

#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

unsigned short int CRC = 0;
unsigned long int FINISH = 0;

unsigned short int ByteCRC( unsigned short int CRC, unsigned char c )
{
	int i;
	CRC ^= c;
	for ( i = 0; i < 8; ++i ) if ( CRC & 1 ) { CRC >>= 1; CRC ^= 0xA001; }
		else CRC >>= 1;
	return CRC;
} // ByteCRC

unsigned char ReadNibble( void )
{
	int ch = getchar();
	if ( EOF == ch ) return 0;
	ch = toupper( ch );
	if ( ch >= 'A' ) ch = 10 + ch - 'A';
	else ch = ch - '0';
	return ch;
} // ReadNibble

#define ReadByte() ((ReadNibble() << 4) + ReadNibble())

int ReadLine( void )
{
	int bytes;
	int addr;
	int ch = getchar();
	if ( EOF == ch ) return 0;
	if ( ':' != ch ) exit(1);

	bytes = ReadByte();
	addr = ReadByte() * 256u + ReadByte();

	if ( !ReadByte() )
	{
		if ( !FINISH ) FINISH = addr;
		else if ( FINISH != addr ) exit(1);

		for ( ; bytes; -- bytes )
		{
			CRC = ByteCRC( CRC, ReadByte() );
			++FINISH;
		}
	}
	while ( (EOF != ch) && ('\n' != ch) ) ch = getchar();
	return 1;
} // ReadLine

int main( void )
{
	while ( ReadLine() ) (void)0;
	int sum = (0-(2 + (FINISH >> 8) + FINISH + CRC + (CRC >> 8))) & 0xff;
	printf( ":02%04X00%02X%02X%02X\n", (int)FINISH, (int)(CRC & 0xFF),
			(int)((CRC >> 8) & 0xFF), (int)(sum) );
	return 0;
} // main

/* End of file  getcrc-hex.c */
endef

getcrc_hex := getcrc-hex.exe

.INTERMEDIATE : $(getcrc_hex) getcrc-hex.c

$(getcrc_hex) : getcrc-hex.c
	$(HOST_CC) getcrc-hex.c -o $@

export GETCRC_SOURCE_HEX
getcrc-hex.c :
	$(ECHO) "$${GETCRC_SOURCE_HEX}" > getcrc-hex.c


define make-crc-of-hex
 $(HEAD) --lines=-1 $@ > n-$@
 ./$(getcrc_hex) < $@ >> n-$@
 $(ECHO) :00000001FF >> n-$@
 $(MV) n-$@ $@
endef


define GETCRC_SOURCE_BIN
/* getcrc-bin.c */

#include <stdio.h>

unsigned short int CRC = 0;

unsigned short int ByteCRC( unsigned short int CRC, unsigned char c )
{
	int i;
	CRC ^= c;
	for ( i = 0; i < 8; ++i ) if ( CRC & 1 ) { CRC >>= 1; CRC ^= 0xA001; }
		else CRC >>= 1;
	return CRC;
} // ByteCRC

int main( void )
{
	int ch;
	while ( (ch = getchar()) != EOF ) CRC = ByteCRC( CRC, ch );
	printf( "%c%c", (char)(CRC & 0xFF), (char)((CRC >> 8) & 0xFF) );
	return 0;
} // main

/* End of file  getcrc-bin.c */
endef

getcrc_bin := getcrc-bin.exe

.INTERMEDIATE : $(getcrc_bin) getcrc-bin.c

$(getcrc_bin) : getcrc-bin.c
	$(HOST_CC) getcrc-bin.c -o $@

export GETCRC_SOURCE_BIN
getcrc-bin.c :
	$(ECHO) "$${GETCRC_SOURCE_BIN}" > getcrc-bin.c


define make-crc-of-bin
 $(CP) $@ n-$@
 ./$(getcrc_bin) < $@ >> n-$@
 $(MV) n-$@ $@
endef


else
make-crc-of-hex =
getcrc_hex =
make-crc-of-bin =
getcrc_bin =
endif
#
# helper for make crc of programm file
#####################################



%_eeprom.hex: $(PROGDIR)%.elf
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
ifeq ($(MAKECMDGOALS),eeprom)
	@$(EEPROMCOPY) -O ihex $< $@
else ifeq ($(MAKECMDGOALS),ehex)
	@$(EEPROMCOPY) -O ihex $< $@
else
	-@$(EEPROMCOPY) -O ihex $< $@
endif

%_eeprom.srec: $(PROGDIR)%.elf
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
ifeq ($(MAKECMDGOALS),eeprom)
	@$(EEPROMCOPY) -O srec $< $@
else ifeq ($(MAKECMDGOALS),esrec)
	@$(EEPROMCOPY) -O srec $< $@
else
	-@$(EEPROMCOPY) -O srec $< $@
endif

%_eeprom.bin: $(PROGDIR)%.elf
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
ifeq ($(MAKECMDGOALS),eeprom)
	@$(EEPROMCOPY) -O binary $< $@
else ifeq ($(MAKECMDGOALS),ebin)
	@$(EEPROMCOPY) -O binary $< $@
else
	-@$(EEPROMCOPY) -O binary $< $@
endif



else


$(error Unknown MCU target: '$(MCU_TARGET)' (see rulers.mk))


endif
# finish architectur specific part
#####################################



#####################################
# Invariant part
#

skip-line = $(if $(findstring j,$(MAKEFLAGS)),,$(info ))

ifeq ($(MAKE_VERSION),4.1)
slash:=\\\\
define make-objs-list
	$(file > $(PROGDIR)$(PRG)-objs-list)
	$(foreach name,$(OBJS),$(file >> $(PROGDIR)$(PRG)-objs-list,$(name)))
endef
else ifeq ($(MAKE_VERSION),4.0)
$(error Unchecked version of 'make')
else
slash:=\\\\\\\\
$(shell $(ECHO)> $(PROGDIR)$(PRG)-objs-list)
$(foreach name,$(OBJS),$(shell $(ECHO) $(name)>>$(PROGDIR)$(PRG)-objs-list))
make-objs-list=
endif # MAKE_VERSION


$(PROGDIR)$(PRG).elf : $(OBJS)
	$(call make-objs-list)
	$(CC) $(C_FLAGS) $(LD_FLAGS) -Wl,@$(PROGDIR)$(PRG)-objs-list -o $@
	$(call make-heap-start-h)
	$(call skip-line)

%.lst: $(PROGDIR)%.elf
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
	$(OBJDUMP) -h -s -S $< > $@

%.hex: $(PROGDIR)%.elf $(getcrc_hex)
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
	$(OBJCOPY) -O ihex $< $@
	$(call make-crc-of-hex)

%.srec: $(PROGDIR)%.elf
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
	$(OBJCOPY) -O srec $< $@

%.bin: $(PROGDIR)%.elf $(getcrc_bin)
	@if [ -e $@ ] ; then $(RM) $@ 2> /dev/nul ; fi
	$(OBJCOPY) -O binary $< $@
	$(call make-crc-of-bin)


# make_obj  lang
define make_obj
 $(CC) -MMD -MF $@.p.d -c $($(strip $(1))_FLAGS)   \
       $($(strip $(1))_FLAGS_$<) $< -o $@
 @$(SED) -e "s/.*:/$(subst /,\/,$@): $(slash)\n/" < $@.p.d > $@.d
 @$(SED) -e '/^ \\$$/d' < $@.d > $@.p.d
 @$(SED) -e 's/.*:/SRC_FILES +=/g' < $@.p.d > $@.d
 @$(SED) -e "1s/^.*:/\n$(subst /,\/,$@) $(subst /,\/,$@).d : /"              \
         -e "\$$s/$$/ $(slash)\n $(subst /,\/,$($(strip $(1))_MK_FILES_$<))\n/"  \
         < $@.p.d >> $@.d
 @$(SED) -e '/^[^:]*: */d' -e 's/^[ \t]*//'   \
         -e 's/ \\$$//' -e 's/$$/ :/'         \
         -e "\$$s/$$/\n$(subst /,\/,$($(strip $(1))_MK_FILES_$<)) :/"  \
         < $@.p.d >> $@.d
 -@$(RM) -f $@.p.d
 $(call skip-line)
endef


$(C_OBJS) : $(OBJDIR)%.o : %.c
	$(call make_obj,C)

$(CPP_OBJS) : $(OBJDIR)%.o : %.cpp
	$(call make_obj,CPP)

$(AS_OBJS) : $(OBJDIR)%.o : %.S
	$(call make_obj,AS)



clean:
	-@$(RM) -rf $(PROGDIR)$(PRG).elf
	-@$(RM) -f $(PROGDIR)$(PRG)-objs-list
	-@$(RM) -rf $(PRG).lst $(PROGDIR)$(PRG).map
	-@$(RM) -rf $(PRG).hex $(PRG).bin $(PRG).srec
	-@$(RM) -rf $(MK_DIRS:%=%/*.o) $(MK_DIRS:%=%/*.o.d)
	-@$(RM) -f tags cscope.out
	$(call rm-heap-start-h)
	$(call rm-eeprom-files)


# include dep. files
ifneq "$(MAKECMDGOALS)" "clean"
-include $(DEPS)
endif



ifeq "tag" "$(findstring tag,$(subst tags,tag,$(MAKECMDGOALS)))"


# make_dep  lang
define make_dep
 $(CC) -MM $($(strip $(1))_FLAGS) $($(strip $(1))_FLAGS_$<) $< -o $@.p.d 
 @$(SED) -e 's/.*:/SRC_FILES +=/g' < $@.p.d > $@
 @$(SED) -e "1s/^.*:/\n$(subst /,\/,$(@:%.d=%)) $(subst /,\/,$@) : $(slash)\n/"  \
         -e "\$$s/$$/ $(slash)\n $(subst /,\/,$($(strip $(1))_MK_FILES_$<))\n/"  \
         < $@.p.d >> $@
 @$(SED) -e 's/^[^:]*: *//' -e 's/^[ \t]*//'   \
         -e 's/ \\$$//' -e 's/$$/ :/'          \
         -e "\$$s/$$/\n$(subst /,\/,$($(strip $(1))_MK_FILES_$<)) :/"  \
         < $@.p.d >> $@.d
 -@$(RM) -f $@.p.d
 $(call skip-line)
endef


$(C_DEPS) : $(OBJDIR)%.o.d : %.c
	$(call make_dep,C)

$(CPP_DEPS) : $(OBJDIR)%.o.d : %.cpp
	$(call make_dep,CPP)

$(AS_DEPS) : $(OBJDIR)%.o.d : %.S
	$(call make_dep,AS)


ifeq ($(MAKE_VERSION),4.1)
define make-srcs-list
	$(file > $(PROGDIR)$(PRG)-srcs-list)
	$(foreach name,$(sort $(SRC_FILES)),$(file >> $(PROGDIR)$(PRG)-srcs-list,$(name)))
endef
else ifeq ($(MAKE_VERSION),4.0)
$(error Unchecked version of 'make')
else
$(shell $(ECHO)> $(PROGDIR)$(PRG)-srcs-list)
$(foreach name,$(sort $(SRC_FILES)),$(shell $(ECHO) $(name)>>$(PROGDIR)$(PRG)-srcs-list))
make-srcs-list=
endif # MAKE_VERSION

tag: tags
tags: $(SRC_FILES)
	$(call make-srcs-list)
	if [ -e tags ] ; then $(CTAGS) -u -L $(PROGDIR)$(PRG)-srcs-list ; \
		else $(CTAGS) -L $(PROGDIR)$(PRG)-srcs-list ; fi
	$(CSCOPE) -U -b -i$(PROGDIR)$(PRG)-srcs-list


endif



# Create directories
$(shell $(MKDIR) $(MK_DIRS) 2>/dev/null)


#
# End of file  rules.mk
