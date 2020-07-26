# -*- Mode: makefile -*- 
#*************************************************************#
#
# MA_CONFIG.MK: This set of definitions is included at the
# beginning of the Maestro makefile, it includes standard definitions
# for Unix systems.
#
# Author: Ohad Rodeh, 4/2003
#
#*************************************************************#

CCC		= g++

CFLAGS= -DMAESTRO_INLINE=inline -O2 -DNDEBUG 
#-p/-pg  -g -Wall

#i386-linux
ifeq ("$(PLATFORM)" , "i386-linux")
MA_LINK_FLAGS = -ltermcap -lm -lpthread -ldl

endif


# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
MA_LINK_FLAGS  = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -lresolv -ldl
endif


#hp9000-hpux
ifeq ("$(PLATFORM)" , "hp9000-hpux")
# .so Libs erzeugen aus ocamlc Object Files klappt nicht beu HP-UX

MA_LINK_FLAGS = -ltermcap -lm -ldce
endif


#alpha-osf1
ifeq ("$(PLATFORM)" , "alpha-osf1")
MA_LINK_FLAGS = -ltermcap -lm -ldl -lpthread
endif




