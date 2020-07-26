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

MAKE_DEF = cd $(ENSROOT)/def; $(MAKE) 
MAKE_OPT = cd $(ENSROOT)/opt; $(MAKE) 

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

libhot-crypto:
	$(MAKE_DEF) libhot-crypto

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
	cd ../test; $(MAKE) 

socket:
	$(MAKE_DEF) socket

cross:
	$(MAKE_DEF) cross

rpc:
	$(MAKE_DEF) rpc

tar:
	cd $(ENSROOT)/tar ; $(MAKE) tar

clean:
	$(RM) *.cm* *.ppo *.aux .err a.out *.o *.a *.lib *.asm *.obj *~ .*~ .#?*

#*************************************************************#
