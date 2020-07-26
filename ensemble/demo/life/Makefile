#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
# LIFE: makefile for life demo
#
# Author: Mark Hayden, 8/96
#
#*************************************************************#
ENSROOT = ../..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/ocaml.mk
#*************************************************************#

.SUFFIXES: .ml .cmo .mli .cmi
.ml.cmo:
	ocamlc -c -I $(ENSLIB) $<
.mli.cmi:
	ocamlc -c -I $(ENSLIB) $<

#*************************************************************#

OBJS = \
        collector$(CMO)	\
        lifetk$(CMO)	\
	debug$(CMO)	\
	rules$(CMO)	\
	slave$(CMO)	\
	master$(CMO)	\
	life$(CMO)

#*************************************************************#

life: $(OBJS) $(ENSCONFDEP) $(ENSTK)
	ocamlc -custom -o life$(EXE) $(LIBTK) $(ENSCONF) $(ENSTK) $(OBJS)

#*************************************************************#

$(ENSTK):
	echo "lib/htk.cma library has not been compiled"

#*************************************************************#

clean:
	$(RM) *~ .*~ *.cm* .err TAGS core
	$(RM) life

depend:
	ocamldep -I $(ENSROOT)/lib *.ml* > .depend

include .depend

#*************************************************************#
