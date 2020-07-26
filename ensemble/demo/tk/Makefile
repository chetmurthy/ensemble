#*************************************************************#
#
#   Ensemble, 1.10
#   Copyright 2001 Cornell University, Hebrew University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
# TK: makefile for Tk demos
#
# Author: Mark Hayden, 8/96
#
#*************************************************************#
ENSROOT = ../..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/ocaml.mk
#*************************************************************#
OBJS = wb$(CMO) wbexec$(CMO)
#*************************************************************#

.SUFFIXES: .ml .cmo .mli .cmi
.ml.cmo:
	ocamlc -c -I $(ENSLIB) $<
.mli.cmi:
	ocamlc -c -I $(ENSLIB) $<

#*************************************************************#

wbml: $(OBJS) $(ENSCONFDEP) $(ENSTK)
	$(RM) wbml$(EXE)
	ocamlc -custom -o wbml$(EXE) $(LIBTK) $(ENSCONF) $(ENSTK) $(OBJS)
#	ocamlc -custom -o wbml$(EXE) $(LIBTK) $(ENSCONF) $(ENSTK) $(CRYPTO_LINK) $(OBJS)

#*************************************************************#

$(ENSTK):
	echo "lib/htk.cma library has not been compiled"

#*************************************************************#

clean:
	$(RM) *~ .*~ *.cm* .err TAGS core
	$(RM) wbml

depend:
	ocamldep -I $(ENSLIB) *.ml* > .depend

include .depend

#*************************************************************#
