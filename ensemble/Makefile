#*************************************************************#
#
# MAKEFILE: root Ensemble Makefile
#
# Author: Ohad Rodeh  12/2001
# Based on code by Mark Hayden
#
#*************************************************************#

.PHONY: socket tar hot ce maestro

include mk/config.mk

ENSROOT = .

SUBDIRS = \
	appl		\
	ce		\
	crypto		\
	demo		\
	demo/tk		\
	demo/life	\
	demo/dbm	\
	doc		\
	ejava		\
	groupd		\
	hot		\
	hot/include	\
	infr		\
	layers		\
	layers/bypass	\
	layers/debug	\
	layers/flow	\
	layers/total	\
	layers/vsync	\
	layers/other	\
	layers/trans	\
	layers/gossip	\
	layers/scale	\
	layers/security	\
	maestro		\
	mk		\
	mm		\
	route		\
	socket		\
	socket/u	\
	socket/s	\
	tar		\
	tools		\
	trans		\
	type		\
	util	



# Make everything from scratch
# 
all: 
	$(MAKE_BASE) -f Makefile.top all; $(MAKE_BASE) -f Makefile.top install
	cd demo ; $(MAKE) ; $(MAKE) install
	cd ce ; $(MAKE)	  ; $(MAKE) install
	cd hot ; $(MAKE)  ; $(MAKE) install

just:
	$(MAKE_BASE) -f Makefile.top all; $(MAKE_BASE) -f Makefile.top install
	cd demo ; $(MAKE) just

# Make the optimized versions
opt: 
	$(MAKE_BASE) -f Makefile.top opt; $(MAKE_BASE) -f Makefile.top install
	cd demo ; 	$(MAKE) opt ;	$(MAKE) install
	cd ce ; $(MAKE) opt ; $(MAKE) install
	cd hot ; $(MAKE) opt ; $(MAKE) install

crypto : 
	cd crypto ; $(MAKE) ; $(MAKE) install 

crypto_opt : 
	cd crypto ; $(MAKE) opt ; $(MAKE) install 

tk :
	$(MAKE_BASE) -f Makefile.top tk

tk_opt :
	$(MAKE_BASE) -f Makefile.top OPT=yes tk


# build a tar file containing the source only.
#
src:
	make realclean
	make depend
	tools/ntify.sh
	cd tar; tarcr $(VERSION)
	cd doc; make build

# build a tar file containing executables and libraries.
#
dist : 
	mkdir -p ../build
	cd bin; \
	for d in *; do ( mkdir -p ../../build/$$d; mkdir -p ../../build/$$d/bin; mkdir -p ../../build/$$d/lib; 	mv $$d/* ../../build/$$d/bin/; mv ../lib/$$d/* ../../build/$$d/lib/); done
	cd ../build; for d in *; do (tar -cf ensemble-$(VERSION)-$$d.tar $$d; gzip ensemble-$(VERSION)-$$d.tar; rm -rf $$d); done

depend: 
	$(MAKE_BASE) -f Makefile.top depend


# This gets around a difference between NMAKE and MAKE. 
#
ifeq ("$(PLATFORM)" , "nt")
CLEANALL = for %%d in ($(SUBDIRS)) do (cd %%d & $(MAKE) clean & cd $(ENS_ABSROOT))
else
CLEANALL = for d in $(SUBDIRS); do (cd $$d; $(MAKE) -k clean); done
endif


# MH: note 'make clean' should clean the def and opt
# directories.  It only leaves libraries, executables, 
# and postscript documents. 
clean: 
	$(CLEANALL)
	$(CLEANDIR)
	$(RM) ensemble.ml ensemble.mli emrg* 
	$(RM) socket/s/socket.mli socket/u/socket.mli
	$(RM) .unknown

# realclean clean
#
realclean: clean 
	$(RMDIR) bin
	$(RMDIR) lib
	cd maestro ;	$(MAKE) realclean
	cd doc ; 	$(MAKE) realclean 


#*************************************************************#
