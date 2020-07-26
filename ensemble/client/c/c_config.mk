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

#i386-linux
ifeq ("$(PLATFORM)" , "i386-linux")
LINK_FLAGS = -lm 
THREAD_LIB = -lpthread 
CFLAGS = -DINLINE=inline -O2 -DNDEBUG -Wall -Wno-unused -Wstrict-prototypes -DENS_TRACE

#-p/-pg  -g  -DCE_TRACE
endif

#i386-redhat
ifeq ("$(PLATFORM)" , "i386-redhat")
LINK_FLAGS = -lm 
THREAD_LIB = -lpthread 
CFLAGS = -DINLINE=inline -O2 -DNDEBUG -Wall -Wno-unused -Wstrict-prototypes 
#-p/-pg  -g  -DCE_TRACE
endif


# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
LINK_FLAGS = -lposix4 -lsocket -lnsl -lm -lresolv
THREAD_LIB = -lthread 
CFLAGS = -DINLINE=inline \
	-O2 -Wall -Wno-unused -Wstrict-prototypes \
	-DNDEBUG  -DSolaris
endif


#hp9000-hpux
ifeq ("$(PLATFORM)" , "hp9000-hpux")
CE_LINK_FLAGS = -lm -ldce
CE_THREAD_LIB = 
CFLAGS = -DINLINE=inline -O2 -Wall -Wstrict-prototypes -I /opt/dce/include/ 	
#-g -p/-pg 
#-DNDEBUG 
endif


#alpha-osf1
ifeq ("$(PLATFORM)" , "alpha-osf1")
CE_LINK_FLAGS = -lm
CE_THREAD_LIB = -lpthread 
CFLAGS = -DINLINE=inline -O2 -Wall -Wstrict-prototypes 
#-g -p/-pg 
#-DNDEBUG 
endif



