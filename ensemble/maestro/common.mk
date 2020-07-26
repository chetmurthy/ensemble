# Makefile for Maestro

MAKE            = make
ROOT		= ../..
ENS		= ../../..

CC		= gcc
CCC		= g++

SYSNAME_linux	= LINUX
SYSNAME_solaris	= SOLARIS
SYSNAME_sunos4	= SUN4
SYSNAME		= $(SYSNAME_$(ENS_OSTYPE))

#**********************************************************

# Change this between -g and -O to compile for debugging/performance
OPT_OPS		= -O

CFLAGS		= 	\
			-I $(ENS)/hot/include	\
			-I $(ROOT)/src/type	\
			-I $(ROOT)/src/corba	\
			-I $(ROOT)/src/group 	\
			$(OPT_OPS)		\
			-D$(SYSNAME)

RM		= /bin/rm -f
AR		= ar r

.SUFFIXES: .C.o .c.o 

PLATFORM	= $(ENS_MACHTYPE)-$(ENS_OSTYPE)
OBJDIR		= $(ROOT)/conf/$(PLATFORM)

HOTLIB		= $(ENS)/lib/$(PLATFORM)/libhot.a

CRYPTOLIB	=
#CRYPTOLIB	= $(ENS)/lib/$(PLATFORM)/libcryptoc.a

sparc-solaris_LIB 	= -lsocket -lposix4 -lthread -lpthread \
			-lnsl -ltermcap -lm

# SUNOS defaults to rvr_threads
sparc-sunos4_LIB	= $(ENS)/contrib/rvr_threads/SUNOS/libthread.a -lm -ltermcap

i386-linux_LIB		= -lpthread -ltermcap -lm -ldl

SYSLIB		= $($(PLATFORM)_LIB)

MAE_TYPE_OBJ =	Maestro_Types.o	\
		Maestro_Perf.o

MAE_GROUP_OBJ =	\
		Maestro_GroupMember.o		\
		Maestro_ClSv.o		\
		Maestro_CSX.o			\
		Maestro_Prim.o		\
		Maestro_ES_ReplicatedUpdates.o \
		Maestro_ES_Simple.o	\
		Maestro_Group.o
 
MAE_CORBA_OBJ =	\
		Maestro_CORBA.o	\
		Maestro_GIOP.o	\
		Maestro_ETC.o		\
		Maestro_IIOPBridge.o	\
		Maestro_ORB.o

MAE_OBJ	      =	\
		$(MAE_TYPE_OBJ)		\
		$(MAE_GROUP_OBJ)	\
		$(MAE_CORBA_OBJ)

MAELIB		= libmae.a
LIB		= $(MAELIB) $(HOTLIB) $(CRYPTOLIB) $(SYSLIB) 


%o: ../../src/corba/%C
	$(CCC) $(CFLAGS) -c -o $@ $<

%o: ../../src/group/%C
	$(CCC) $(CFLAGS) -c -o $@ $<

%o: ../../src/type/%C
	$(CCC) $(CFLAGS) -c -o $@ $<

%o: ../../src/util/%C
	$(CCC) $(CFLAGS) -c -o $@ $<

all: 	libmae.a	\
	newkey	\
	read_ior


############################################################################

# Set this to your purify location
PURIFY_HOME_sparc-solaris = /opts/pure/purify-4.0.1-solaris2

PURIFY_HOME 		= $(PURIFY_HOME_$(PLATFORM))
PURIFY_INC 		= $(PURIFY_INC_$(PLATFORM))
PURIFY_OPS		= -cache-dir=/usr/u/alexey/tmp 		\
			-threads=yes -windows=yes -g++=yes	\
			-chain-length=15
PURIFY_LIB 		= $(PURIFY_HOME)/purify_stubs.a
PURIFY 			= $(PURIFY_HOME)/purify $(PURIFY_OPS)

############################################################################

libmae.a: $(MAE_OBJ)
	$(AR) libmae.a $(MAE_OBJ)
	ranlib libmae.a

newkey: newkey.o
	$(CCC) -o newkey newkey.o $(LIB)

read_ior: read_ior.o
	$(CCC) -o read_ior read_ior.o $(LIB)

clean:
	$(RM) *.o libmae.a newkey read_ior
	cd ../../test; $(MAKE) clean

realclean : clean

depend:
	$(CCC) $(CFLAGS) -MM 	\
	$(ROOT)/src/type/*.C 	\
	$(ROOT)/src/corba/*.C 	\
	$(ROOT)/src/util/*.C 	\
	$(ROOT)/src/group/*.C 	> .err
	mv .err .depend
	cp .depend ../../test/.depend

include .depend
