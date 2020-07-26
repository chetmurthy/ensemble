#*************************************************************#
#
# MAKEFILE: root Ensemble Makefile
#
# Author: Mark Hayden, 2/96
#
#
#*************************************************************#

.PHONY: all def socket opt tar

include mk/config.mk
#*************************************************************#
TOUCH	= touch

SRCS	= \
	  util/*.ml util/*.mli		\
	  buffer/*.ml buffer/*.mli	\
	  type/*.ml type/*.mli		\
	  layers/*/*.ml			\
	  trans/*.ml trans/*.mli	\
	  trans/atm/*.ml trans/atm/*.mli \
	  trans/mpi/*.ml		\
	  groupd/*.ml groupd/*.mli	\
	  buffer/*.ml buffer/*.mli	\
	  appl/*.ml appl/*.mli		\
	  route/*.ml route/*.mli	\
	  infr/*.ml infr/*.mli		\
	  demo/*.ml			\
	  demo/life/*.ml demo/life/*.mli \
	  demo/tk/*.ml			\
	  hot/*.ml hot/*.mli

SUBDIRS = \
	mk		\
	socket		\
	util		\
	buffer		\
	type		\
	infr		\
	route		\
	appl		\
	trans		\
	trans/atm	\
	trans/mpi	\
	groupd		\
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
	demo		\
	demo/tk		\
	demo/life	\
	demo/dbm	\
	crypto		\
	rpc		\
	hot		\
	hot/include	\
	doc/maestro	\
	doc

#	maestro

#*************************************************************#

all:
	cd def ; $(MAKE)

def:
	cd def ; $(MAKE)

opt:
	cd opt ; $(MAKE)

socket:
	cd def ; $(MAKE) socket

wbml:
	cd def ; $(MAKE) wbml

#*************************************************************#

depend:
	cd def	; $(TOUCH) $(DEPEND) ; $(MAKE) depend
	cd opt	; $(TOUCH) $(DEPEND) ; $(MAKE) depend
	cd demo	; $(TOUCH) $(DEPEND) ; $(MAKE) depend
	cd demo/life ; $(TOUCH) $(DEPEND) ; $(MAKE) depend
	cd demo/dbm  ; $(TOUCH) $(DEPEND) ; $(MAKE) depend
	cd demo/tk	; $(TOUCH) $(DEPEND) ; $(MAKE) depend
	cd maestro	; $(TOUCH) $(DEPEND) ; $(MAKE) depend


# HACK. This gets around a difference between NMAKE and MAKE. 
# Get the clean_all rule.
#
include mk/clean_all.mk

# MH: note 'make clean' should clean the def and opt
# directories.  It only leaves libraries, executables, 
# and postscript documents. 
clean: 
	$(CLEANALL)
	$(RM) *.cm* *.ppo *.aux .err a.out *.o *.a *.lib *.asm *.obj *~ .*~ .#?*
	cd def ;	$(MAKE) clean
	cd opt ;	$(MAKE) clean
	cd ce;		$(MAKE) clean
	cd ejava;	$(MAKE) clean
	cd maestro;	$(MAKE) clean
	cd doc; 	$(MAKE) clean 

# realclean clean
#
realclean: clean 
	cd def ;	$(MAKE) realclean
	cd opt ;	$(MAKE) realclean
	cd lib;		$(MAKE) realclean
	cd demo;	$(MAKE) realclean
	cd ce;		$(MAKE) realclean
	cd maestro;	$(MAKE) realclean
	cd doc; 	$(MAKE) realclean 

tags:
	ls $(SRCS)
	etags $(SRCS)

ltags:
	etags layers/*/*.ml

tagall:
	etags $(SRCS) README mk/* Makefile */Makefile */*/Makefile */README */*/README

#*************************************************************#
# Some filters of various aspects of the sources

bugs:
	grep BUG $(SRCS)

heads:
	head -6 $(SRCS)

opens:
	grep "^open" $(SRCS)

opensu:
	grep -h "^open" $(SRCS) | sort -u

author:
	attrib hayden $(SRCS)

rvr:
	attrib renesse $(SRCS)

srcs:
	echo $(SRCS) >.srcs


#*************************************************************#
# Create a large enscript file with all the layers

layers.ps:
	cd layers ; ../tools/pagecat */*.ml */*.mli | enscript -2Gr -p ../layers.ps

#*************************************************************#
# Make everything from scratch

build:
	cd def	; $(MAKE) depend ; $(MAKE) ; $(MAKE) hot 
	cd opt	; $(MAKE) depend ; $(MAKE) ; $(MAKE) hot
	cd ce   ; $(MAKE)
	$(CHMODR) lib/$(PLATFORM)/*.mli
	make clean 
	cd ..; tar -cf ensemble-$(PLATFORM).tar ensemble; gzip ensemble-$(PLATFORM).tar

#	cd demo	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#	cd demo/life ; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#	cd demo/tk	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#	cd execsvr	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#*************************************************************#
# Get a breakdown of size of the ML/C/Latex sources

wc:
	@ echo "Core code:"
	  cat util/*.ml | wc -
	  cat buffer/*.ml | wc -
	  cat type/*.ml | wc -
	  cat route/*.ml | wc -
	  cat appl/*.ml | wc -
	  cat infr/*.ml | wc -
	  cat trans/*.ml | wc -
	  cat layers/*/*.ml | wc -

old_wc:
	@ wc \
	  util/*.ml	\
	  buffer/*.ml	\
	  type/*.ml	\
	  appl/*.ml	\
	  infr/*.ml	\
	  route/*.ml	\
	  trans/*.ml	\
	  layers/vsync/*.ml		\
	  layers/trans/*.ml		\
	  layers/other/*.ml
	@ echo "ML code:"
	@ wc \
	  util/*.ml	util/*.mli	\
	  buffer/*.ml	buffer/*.mli	\
	  buffer/*.ml	buffer/*.mli	\
	  type/*.ml	type/*.mli	\
	  appl/*.ml	appl/*.mli	\
	  groupd/*.ml   groupd/*.mli \
	  layers/*/*.ml	layers/*/*.mli	\
	  socket/*.ml	socket/*.mli	\
	  trans/*.ml	trans/*.mli	\
	  rpc/*.ml	rpc/*.mli	\
	  hsys/*.ml	hsys/*.mli	\
	  demo/*.ml			\
	  demo/tk/*.ml			\
	  execsvr/*.ml			\
	  demo/life/*.ml demo/life/*.mli \
	  atm/*.ml
	@ echo
	@ echo "C code:"
	@ wc \
	  atm/*.[ch] \
	  socket/*.[ch]
	@ echo
	@ echo "Latex Documentation"
	@ wc doc/*.tex layers/*/*.tex


nfiles:
	@ ls $(SRCS) mk/* | wc

#*************************************************************#
