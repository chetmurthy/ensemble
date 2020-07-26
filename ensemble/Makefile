#*************************************************************#
#
#   Ensemble, (Version 1.00)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
#   Ensemble, (Version 0.71F)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
# MAKEFILE: root Ensemble Makefile
#
# Author: Mark Hayden, 2/96
#
#
#*************************************************************#

.PHONY: all def socket opt tar

#*************************************************************#
CD	= cd
CP	= cp
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
	doc/maestro

#	maestro

#*************************************************************#

all:
	$(CD) def ; $(MAKE)

def:
	$(CD) def ; $(MAKE)

opt:
	$(CD) opt ; $(MAKE)

socket:
	$(CD) def ; $(MAKE) socket

wbml:
	$(CD) def ; $(MAKE) wbml

#*************************************************************#

depend:
	$(CD) def	; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) opt	; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) demo	; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) demo/life ; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) demo/dbm  ; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) demo/tk	; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) tools	; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) maestro	; $(TOUCH) .depend ; $(MAKE) depend
	$(CD) tools	; $(TOUCH) .depend ; $(MAKE) depend

clean:
	$(RM) *~ .*~ TAGS
	$(RM) dist/*~
	$(RM) lib/*.cmx* lib/*.o lib/*.a
	@set +e; set -x; for d in $(SUBDIRS) ; do ($(CD) $$d; $(MAKE) -k clean); done
	$(CD) tools ; $(MAKE) -k clean
	$(CD) lib;	$(MAKE) clean
	$(CD) demo;	$(MAKE) clean
	$(CD) maestro;	$(MAKE) clean

# MH: note 'make clean' should *not* clean the def and opt
# directories.  For that, use 'make realclean'
#	$(CD) def ;	$(MAKE) clean
#	$(CD) opt ;	$(MAKE) clean

realclean: clean
	$(CD) def ;	$(MAKE) realclean
	$(CD) opt ;	$(MAKE) realclean
	$(CD) lib;	$(MAKE) realclean
	$(CD) demo;	$(MAKE) realclean
	$(CD) maestro;	$(MAKE) realclean

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

tar:
	$(CD) tar ; $(MAKE) tar

nfs-all:
	cp -ru /usr/u/hayden/ensemble/* /usr/u/hayden/ensemble.nfs

nfs:
	-cp --force /usr/u/hayden/ensemble/lib/* /usr/u/hayden/ensemble.nfs/lib
	-cp --force /usr/u/hayden/ensemble/demo/* /usr/u/hayden/ensemble.nfs/demo

#*************************************************************#
# Create a large enscript file with all the layers

layers.ps:
	$(CD) layers ; ../tools/pagecat */*.ml */*.mli | enscript -2Gr -p ../layers.ps

#*************************************************************#
# Make everything from scratch

everything:
	$(CD) def	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
	$(CD) opt	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k

#	$(CD) demo	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#	$(CD) demo/life ; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#	$(CD) demo/tk	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
#	$(CD) execsvr	; $(MAKE) clean ; $(MAKE) depend ; $(MAKE) -k
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
