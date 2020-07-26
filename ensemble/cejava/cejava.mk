# -*- Mode: makefile -*- 
#*************************************************************#
#
# CEJAVA.MK: This set of definitions is included at the
# beginning of the CE makefile, it includes standard definitions
# for Unix systems.
#
# Author: Ohad Rodeh, 7/2002
#
#*************************************************************#

ifeq ("$(PLATFORM)", "i386-linux")
CC = gcc -O2 -DNDEBUG -DINLINE=inline -Wall -Wstrict-prototypes 
LINK = ld -shared 
J2SDK_PLATFORM = linux
CELIB = .so
CEJAVA_LINK_FLAGS = 
endif

