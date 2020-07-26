#*************************************************************#
#
#   Ensemble, 1.10
#   Copyright 2001 Cornell University, Hebrew University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# Makefile for test programs

default: tests

ROOT		= ..
ENS		= ../..

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

sparc-solaris_LIB 	= -lsocket -lposix4 -lthread -lpthread \
			-lnsl -ltermcap -lm

# Defaults to rvr_threads
sparc-sunos4_LIB	= $(ENS)/contrib/rvr_threads/SUNOS/libthread.a -lm -ltermcap

i386-linux_LIB		= -lpthread -ltermcap -lm

# uncomment HOTLIB with crypto and CRYPTOLIB to build
# Maestro with the security code included

HOTLIB		= $(ENS)/lib/$(PLATFORM)/libhot.a
#HOTLIB		= $(ENS)/lib/$(PLATFORM)/libhot-crypto.a

CRYPTOLIB	=
#CRYPTOLIB	= $(ENS)/lib/$(PLATFORM)/libcryptoc.a

SYSLIB		= $($(PLATFORM)_LIB)
MAELIB		= $(OBJDIR)/libmae.a
LIB		= $(MAELIB) $(HOTLIB) $(CRYPTOLIB) $(SYSLIB) 


tests: 	group \
	maestro-test \
	maestro-perf \
	test-replicated	\
	test-simple

$(OBJDIR)/%o: %C
	$(CCC) $(CFLAGS) -c -o $@ $<

group: $(OBJDIR)/group.o $(HOTLIB)
	$(CCC) -o $(OBJDIR)/group $(OBJDIR)/group.o $(LIB)

maestro-test: $(OBJDIR)/maestro-test.o $(HOTLIB)
	$(CCC) -o $(OBJDIR)/maestro-test $(OBJDIR)/maestro-test.o $(LIB)

maestro-perf: $(OBJDIR)/maestro-perf.o $(HOTLIB)
	$(CCC) -o $(OBJDIR)/maestro-perf $(OBJDIR)/maestro-perf.o $(LIB)

test-replicated: $(OBJDIR)/test-replicated.o $(HOTLIB)
	$(CCC) -o $(OBJDIR)/test-replicated $(OBJDIR)/test-replicated.o $(LIB)

test-simple: $(OBJDIR)/test-simple.o $(HOTLIB)
	$(CCC) -o $(OBJDIR)/test-simple $(OBJDIR)/test-simple.o $(LIB)

clean:
	$(RM) $(OBJDIR)/maestro-test $(OBJDIR)/maestro-perf $(OBJDIR)/test-replicated $(OBJDIR)/test-simple
