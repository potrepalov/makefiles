# Makefile
#
# main Makefile
#
# GOALS:
# clean	- clean working dirs
# hex	- Intel .hex for flash
# srec	- Motorola .srec for flash
# bin	- .bin for flash
# lst	- listing
# flash	- hex, srec, bin
# all	- clean, lst, flash
# elf   - .elf file
# tag   - tags, cscope.out
#


.DEFAULT_GOAL	 := hex


# MAKE_CRC_OF_FILE := yes
# MAKE_HEAP_START_H := yes


PRG              := prog-name
MCU_TARGET       := STM32F429xx

# for avr define DATA_START
#DATA_START       := 0x800060

INCLUDE_DIRS     += . include

OPTIMIZE         += -O2 -fomit-frame-pointer

LD_MEMORY_SCRIPT := fast-mem.ld
LD_INCLUDE_DIRS  := ldscripts

CFLAGS           += --std=gnu99
CFLAGS           += -g


#CFLAGS += --pedantic 


SRCDIR          := ../FreeRTOS
include makef.mk

SRCDIR          := .
include makef.mk


include rules.mk


#
# End of file  Makefile
