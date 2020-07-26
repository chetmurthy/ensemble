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
# DEMO directory base Makefile
#
# Author: Mark Hayden, 8/96
# Massive changes, Ohad Rodeh 12/2001
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk
#*************************************************************#
# Choose whether to use the optimizing compiler or not.
#

ifdef OPT
include $(ENSROOT)/mk/ocamlopt.mk
else
include $(ENSROOT)/mk/ocaml.mk
endif

#*************************************************************#
DEMOS	= \
	$(ENSBIN)/mtalk$(EXE) \
	$(ENSBIN)/groupd$(EXE) \
	$(ENSBIN)/gossip$(EXE) \
	$(ENSBIN)/rand$(EXE) \
	$(ENSBIN)/fifo$(EXE) \
	$(ENSBIN)/perf$(EXE) \
	$(ENSBIN)/armadillo$(EXE) \
	$(ENSBIN)/ensemble$(EXE) \
	$(ENSBIN)/socktest$(EXE)
OBJS	= mtalk$(CMO) groupd$(CMO) gossip$(CMO) rand$(CMO) fifo$(CMO) perf$(CMO)  \
	  lensemble$(CMO) armadillo$(CMO) socktest$(CMO)
EXEC	= _exec-$(PLATFORM)$(EXE)
#*************************************************************#

.SUFFIXES: .ml .cmo .cmx .mli .cmi
.mli.cmi:
	ocamlc  -I $(ENSLIB) -c $<
.ml.cmo:
	ocamlc -I $(ENSLIB) -c $<
.ml.cmx:
	ocamlopt -I $(ENSLIB) -c $<

#*************************************************************#

#gorp:
#	make -C ../test gorp

all: $(EXEC) $(DEMOS)

opt : 
	$(MAKE) OPT=YES all

just : all

# Make stuff in subdirectories too
everything: all
	cd tk ; make
	cd life ; make

$(EXEC): $(OBJS) $(ENSCONFDEP)
	$(MLLINK) $(MLLINKFLAGS) -o $(EXEC) $(LIBSYS) $(ENSCONF) $(CRYPTO_LINK) $(OBJS)

#*************************************************************#
# Standard demos.  We link/copy the _exec program to the names
# of the various demos.  It's all the same executable, which
# does different things depending on its name.  This is a
# hack, but worth the savings in link time.

$(ENSBIN)/gossip$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/gossip$(EXE)

$(ENSBIN)/groupd$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/groupd$(EXE)

$(ENSBIN)/mtalk$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/mtalk$(EXE)

$(ENSBIN)/rand$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/rand$(EXE)

$(ENSBIN)/fifo$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/fifo$(EXE)

$(ENSBIN)/perf$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/perf$(EXE)

$(ENSBIN)/ensemble$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/ensemble$(EXE)

$(ENSBIN)/armadillo$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/armadillo$(EXE)

$(ENSBIN)/socktest$(EXE): $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)/socktest$(EXE)
#*************************************************************#

clean:
	$(CLEANDIR)
	$(RM) _exec* _runt* 

realclean: clean

depend:
	ocamldep -I $(ENSLIB) *.ml *.mli > $(DEPEND)

include $(DEPEND)

#*************************************************************#



