#*************************************************************#
#
#   Ensemble, 1_42
#   Copyright 2003 Cornell University, Hebrew University
#           IBM Israel Science and Technology
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
# Changes: Ohad Rodeh 11/2001
#
#*************************************************************#
ENSROOT = ../..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/ocaml.mk
#*************************************************************#

.SUFFIXES: .ml .cmo .mli .cmi .cmx
.ml.cmo:
	ocamlc -c -g -I +labltk -I $(ENSLIB) $<
.mli.cmi:
	ocamlc -c -g -I +labltk -I $(ENSLIB) $<
.ml.cmx:
	ocamlopt -c -I +labltk -I $(ENSLIB) $<

#*************************************************************#
# The additional -cclib argument was needed so that CAML would
# find the Tk libraries. This is a CAML bug.
#
wbml: wb$(CMO) $(ENSTK)
	$(RM) wbml$(EXE)
	ocamlc -custom -o wbml$(EXE) \
	$(ENSCONF) $(LIBTK) $(ENSTK) wb$(CMO)

#	-cclib -L/home/orodeh/ocaml/3.01/i386-linux/lib/labltk \
#	ocamlc -custom -o wbml$(EXE) $(LIBTK) $(ENSCONF) $(ENSTK) $(CRYPTO_LINK) $(OBJS)

#*************************************************************#

$(ENSTK):
	echo "lib/htk.cma library has not been compiled"

#*************************************************************#


clean :
	$(CLEANDIR)
	$(RM) wbml

realclean: clean 

depend:
	ocamldep -I $(ENSLIB) *.ml* > $(DEPEND)

include $(DEPEND)

#*************************************************************#

