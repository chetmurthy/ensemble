#*************************************************************#
#
#   Ensemble, (Version 1.00)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
ENSROOT = ../../../ensemble
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/ocaml.mk
#*************************************************************#
OBJS = db$(CMO) 
#*************************************************************#

.SUFFIXES: .ml .cmo .mli .cmi
.ml.cmo:
	ocamlc -c -I $(ENSROOT)/lib $<
.mli.cmi:
	ocamlc -c -I $(ENSROOT)/lib $<

#*************************************************************#

db: $(OBJS) $(ENSCONFDEP) $(ENSTK)
	$(RM) db$(EXE)
	ocamlc -custom -o db$(EXE) $(LIBTK) $(ENSCONF) $(ENSTK) str.cma dbm.cma $(OBJS) -cclib -lstr -cclib -lmldbm -cclib -lndbm

#*************************************************************#

clean:
	$(RM) *~ .*~ *.cm* .err TAGS core
	$(RM) db

depend:
	ocamldep -I $(ENSROOT)/lib *.ml* > .depend

include .depend

#*************************************************************#
