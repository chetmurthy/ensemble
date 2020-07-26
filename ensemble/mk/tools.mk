#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# -*- Mode: makefile -*-
#*************************************************************#
#
# TOOLS: rules for building Ensemble compilation tools
#
# Author: Mark Hayden, 6/97
#
#*************************************************************#
# Special compiler, dependency generators, and other tools
# These rules all use basic system utilities like cp/copy.

# This gets made first for mkutil below
$(ETOUCH): ../tools/etouch.ml
	ocamlc -o $(ETOUCH) ../tools/etouch.ml
	$(RM) ../tools/etouch.cmi
	$(RM) ../tools/etouch.cmo

# We also need to "touch" the mkutil.ml because
# NT copy command leaves the copied file with the
# same time as the original.
$(OBJD)/mkutil.cmo: ../tools/mkutil.ml $(ETOUCH)
	$(RM) $(OBJD)/mkutil.ml
	$(CP) ../tools/mkutil.ml $(OBJD)/mkutil.ml
	$(ETOUCHC) $(OBJD)/mkutil.ml
	ocamlc -I $(OBJD) -c $(OBJD)/mkutil.ml

# We can now build the ecp command which is used
# in the tools below.
$(ECP): ../tools/ecp.ml $(OBJD)/mkutil.cmo
	$(RM) $(OBJD)/ecp.ml
	$(CP) ../tools/ecp.ml $(OBJD)/ecp.ml
	ocamlc -I $(OBJD) -o $(ECP) $(OBJD)/mkutil.cmo $(OBJD)/ecp.ml

$(ECAMLDEP): ../tools/ecamldep.mll ../tools/misc.ml $(ECP)
	$(ECPC) ../tools/ecamldep.mll -o $(OBJD)/ecamldep.mll
	$(ECPC) ../tools/misc.ml -o $(OBJD)/misc.ml
	ocamllex $(OBJD)/ecamldep.mll
	ocamlc -I $(OBJD) -o $(ECAMLDEP) $(OBJD)/misc.ml $(OBJD)/ecamldep.ml

$(OBJD)/echeck.ml: ../tools/echeck.ml $(ECP)
	$(ECPC) ../tools/echeck.ml -o $(OBJD)/echeck.ml

$(ECAMLC): ../tools/ecamlc.ml $(OBJD)/mkutil.cmo $(OBJD)/echeck.ml $(ECP)
	$(ECPC) ../tools/ecamlc.ml -o $(OBJD)/ecamlc.ml
	ocamlc -custom -I $(OBJD) -o $(ECAMLC) \
	  $(OBJD)/mkutil.cmo \
	  $(OBJD)/echeck.ml \
	  -cclib $(LIBCUNIX) unix.cma \
	  $(OBJD)/ecamlc.ml $(LIBSYS)

$(EMV): ../tools/emv.ml $(OBJD)/mkutil.cmo $(ECP)
	$(ECPC) ../tools/emv.ml -o $(OBJD)/emv.ml
	ocamlc -I $(OBJD) -o $(EMV) $(OBJD)/mkutil.cmo $(OBJD)/emv.ml

$(EMRG): ../tools/emrg.ml $(OBJD)/mkutil.cmo $(ECP)
	$(ECPC) ../tools/emrg.ml -o $(OBJD)/emrg.ml
	ocamlc -I $(OBJD) -o $(EMRG) $(OBJD)/mkutil.cmo $(OBJD)/emrg.ml

$(ELONG): ../tools/elong.ml $(OBJD)/mkutil.cmo $(ECP)
	$(ECPC) ../tools/elong.ml -o $(OBJD)/elong.ml
	ocamlc -I $(OBJD) -o $(ELONG) $(OBJD)/mkutil.cmo $(OBJD)/elong.ml

#$(ECRCS): ../tools/ecrcs.ml $(OBJD)/mkutil.cmo $(ECP)
#	$(ECPC) ../tools/ecrcs.ml -o $(OBJD)/ecrcs.ml
#	ocamlc -I $(OBJD) -o $(ECRCS) $(OBJD)/mkutil.cmo $(OBJD)/ecrcs.ml

#*************************************************************#
