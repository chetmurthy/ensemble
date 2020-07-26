#*************************************************************#
#
# Main HOT Makefile
#
# Author: Ohad Rodeh 11/2001
# Based on code by Mark Hayden
#
#*************************************************************#
ENSROOT = ../..

include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk
#*************************************************************#


HOTOBJ = \
	hot/hot_ce$(OBJ) \
	hot/hot_endpt_tbl$(OBJ) \
	hot/hot_error$(OBJ) \
	hot/hot_mem$(OBJ) \
	hot/hot_msg$(OBJ) \
	hot/hot_sys$(OBJ) \
	hot/$(HOT_THREAD_OBJ)

HOT = 	libhot$(ARC) hot_test$(EXE) 


# NT
ifeq ("$(PLATFORM)" , "nt")
FLAG = ok
#MLFLAGS = #-p
#CFLAGS	= -DINLINE=__inline 
CE_LINK_FLAGS	= $(SOLNKFLAGS)
HOT_THREAD_OBJ	= ntthread$(OBJ)
endif

#i386-linux
ifeq ("$(PLATFORM)" , "i386-linux")
FLAG = ok
MLFLAGS = #-p
#CFLAGS = -DINLINE=inline -O2 -Wall -Wstrict-prototypes #-g -p
CE_LINK_FLAGS = -ltermcap -lm -ldl -lpthread
HOT_THREAD_OBJ = pthread_intf$(OBJ)
endif

# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
FLAG = ok
MLFLAGS = #-p
#CFLAGS =  -DINLINE= -O2 #-g -p
CE_LINK  = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -ldl
HOT_THREAD_OBJ = solaris_thread$(OBJ)
endif

# If nothing is applicable
ifeq ("$(FLAG)" , "no")
all : 
	echo "No configuration for this architecture"
endif

libhot$(ARC) : ce$(OBJ) $(HOTOBJ) $(INBOARD_MT_OBJ) $(COBJ)
	$(PARTIALLD) $(PARTIALLDO) libhot$(OBJ)\
	  $(HOTOBJ) \
	  ce$(OBJ)\
	  $(COBJ)\
	  $(INBOARD_MT_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME) 
	$(MKLIB) $(MKLIBO)libhot$(ARC) libhot$(OBJ)
	$(RANLIB) libhot$(ARC)



# Generate the hot_test executable
hot_test$(EXE): libhot$(ARC) hot/hot_test$(OBJ)
	$(CC) -g -o hot_test$(EXE) \
	  hot/hot_test$(OBJ) \
	  libhot$(ARC) \
	  $(CE_LINK_FLAGS) 
#-lefence

# Generate the outboard test
#hot_testo$(EXE): libhoto$(ARC) hot/hot_test$(OBJ)
#	$(CC)  -o hot_testo$(EXE) \
#	  hot/hot_test$(OBJ) \
#	  libhoto$(ARC) \
#	  $(HOT_LINK_FULL)


#*************************************************************#
all : 
	cd ..; $(MAKE) all

clean:
	$(CLEANDIR)

