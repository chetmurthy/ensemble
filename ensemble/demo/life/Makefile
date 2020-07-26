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
# LIFE: makefile for life demo
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
	ocamlc -c -I +labltk -I $(ENSLIB) $<
.mli.cmi:
	ocamlc -c -I +labltk -I $(ENSLIB) $<
.ml.cmx:
	ocamlopt -c -I +labltk -I $(ENSLIB) $<

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
# The additional -cclib argument was needed so that CAML would
# find the Tk libraries. This is a CAML bug.
#
life: $(OBJS) $(ENSCONFDEP) $(ENSTK)
	ocamlc -custom -o life$(EXE) \
	-cclib -L/home/orodeh/ocaml/3.01/i386-linux/lib/labltk \
	$(ENSCONF) $(LIBTK) $(ENSTK) $(OBJS)

#*************************************************************#

$(ENSTK):
	echo "lib/htk.cma library has not been compiled"

#*************************************************************#

clean :
	$(CLEANDIR)
	$(RM) life

realclean: clean 

depend:
	ocamldep -I $(ENSROOT)/lib *.ml* > $(DEPEND)

include $(DEPEND)

#*************************************************************#

