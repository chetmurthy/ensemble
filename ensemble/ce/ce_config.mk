# -*- Mode: makefile -*- 
#*************************************************************#
#
# CE_CONFIG.MK: This set of definitions is included at the
# beginning of the CE makefile, it includes standard definitions
# for Unix systems.
#
# Author: Ohad Rodeh, 5/2002
#
#*************************************************************#

SO = .so

# static or dynamic linking?
#
CE_LIB = .so     #.a
CE_LNKLIB = .so  #.a

#i386-linux
ifeq ("$(PLATFORM)" , "i386-linux")
CE_LINK_FLAGS = -ltermcap -lm -ldl -lpthread
CFLAGS = -DINLINE=inline \
	-O2 -Wall -Wstrict-prototypes -DNDEBUG \
	-I $(OCAML_LIB)			
#-g -p/-pg 
endif

# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
CE_LINK_FLAGS  = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -ldl
endif



