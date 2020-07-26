#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# -*- Mode: makefile -*- 
#*************************************************************#
#
# MAKEFILE.SUB: this makefile is included in source code
# subdirectories.  It allows compilations to be run from those
# directories.
#
# Author: Mark Hayden, 2/96
#
#*************************************************************#
#MAKE = make #by default, this is already set

# These are set up to be run with gnumake
MAKE_DEF = $(MAKE) -C $(ENSROOT)/def -k $(ENS_MAKEOPTS)
MAKE_OPT = $(MAKE) -C $(ENSROOT)/opt #-k $(ENS_MAKEOPTS)

.PHONY: clean def mmm life

def:
	$(MAKE_DEF)

opt:
	$(MAKE_OPT)

tk:
	$(MAKE_DEF) tk

atm:
	$(MAKE_DEF) atm

mpi:
	$(MAKE_DEF) mpi

crypto:
	$(MAKE_DEF) crypto

installtk:
	$(MAKE_DEF) installtk

life:
	$(MAKE_DEF) life

wbml:
	$(MAKE_DEF) wbml

hot:
	$(MAKE_DEF) hot

hoto:
	$(MAKE_DEF) hoto

hoti:
	$(MAKE_DEF) hoti

hot_ping:
	$(MAKE_DEF) hot_ping

hot_test2:
	$(MAKE_DEF) hot_test2

outb_test:
	$(MAKE_DEF) outb_test

test:
	$(MAKE_DEF) install
	$(MAKE) -C ../test

socket:
	$(MAKE_DEF) socket

cross:
	$(MAKE_DEF) cross

rpc:
	$(MAKE_DEF) rpc

tar:
	$(MAKE) -C $(ENSROOT)/tar tar

all:	

clean::
	$(RM) *~ .*~ *.cm* *.ppo *.aux .err a.out *.o *.a *.lib *.asm *.obj

#*************************************************************#
