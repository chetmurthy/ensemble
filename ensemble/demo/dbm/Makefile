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
ENSROOT = ../..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/ocaml.mk
include $(ENSROOT)/mk/sub.mk
#*************************************************************#
OBJS = db$(CMO) 
#*************************************************************#

.SUFFIXES: .ml .cmo .mli .cmi
.ml.cmo:
	ocamlc -c -I $(ENSROOT)/lib/$(PLATFORM) $<
.mli.cmi:
	ocamlc -c -I $(ENSROOT)/lib/$(PLATFORM) $<

#*************************************************************#

db: $(OBJS) $(ENSCONFDEP)
	$(RM) db$(EXE)
	ocamlc -custom -o db$(EXE) $(ENSCONF) str.cma dbm.cma $(OBJS) -cclib -lstr -cclib -lmldbm -cclib -lndbm

#*************************************************************#

clean : 
	$(CLEANDIR)
	$(RM) db

realclean: clean

depend:
	ocamldep -I $(ENSROOT)/lib *.ml* > $(DEPEND)

include $(DEPEND)

#*************************************************************#
