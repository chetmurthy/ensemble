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

# static or dynamic linking?
#
# CE_LIB = .so     # .a
# CE_LNKLIB = .so  # .a

#i386-linux
ifeq ("$(PLATFORM)" , "i386-linux")
CE_LIB = .so
CE_LNKLIB = .so

CE_LINK_FLAGS = -ltermcap -lm -ldl -lpthread 
CFLAGS = -DINLINE=inline \
	 -O2 -DNDEBUG -Wall -Wno-unused -Wstrict-prototypes \
	 -I $(OCAML_LIB)		
#-p/-pg  -g  -DCE_TRACE
endif


# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
CE_LIB = .a
CE_LNKLIB = .a

MKSHRLIB   = ld 

CE_LINK_FLAGS  = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -lresolv -ldl
CFLAGS = -DINLINE=inline \
	-O2 -Wall -Wno-unused -Wstrict-prototypes \
	-DNDEBUG  -DSolaris \
	-I $(OCAML_LIB)	
endif


#hp9000-hpux
ifeq ("$(PLATFORM)" , "hp9000-hpux")
# .so Libs erzeugen aus ocamlc Object Files klappt nicht beu HP-UX

CE_LIB = .a
CE_LNKLIB = .a

# geht aber sowieso nicht bei HP und ocaml
MKSHRLIB   = ld -b

CE_LINK_FLAGS = -ltermcap -lm -ldce
CFLAGS = -DINLINE=inline \
	-O2 -Wall -Wstrict-prototypes \
	-I $(OCAML_LIB)	 -I /opt/dce/include/ 	
#-g -p/-pg 
#-DNDEBUG 
endif


#alpha-osf1
ifeq ("$(PLATFORM)" , "alpha-osf1")
CE_LINK_FLAGS = -ltermcap -lm -ldl -lpthread
CFLAGS = -DINLINE=inline \
	-O2 -Wall -Wstrict-prototypes \
	-I $(OCAML_LIB)		
#-g -p/-pg 
#-DNDEBUG 
endif



