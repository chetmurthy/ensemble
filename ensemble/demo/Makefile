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
DEMOS_CLEAN = \
	mtalk groupd gossip rand fifo perf ensemble armadillo socktest *.exe
DEMOS	= mtalk$(EXE) groupd$(EXE) gossip$(EXE) rand$(EXE) fifo$(EXE) \
          perf$(EXE) armadillo$(EXE) ensemble$(EXE) socktest$(EXE)
#DEMOS	= socktest$(EXE)
OBJS	= mtalk$(CMO) groupd$(CMO) gossip$(CMO) rand$(CMO) fifo$(CMO) perf$(CMO)  \
	  lensemble$(CMO) armadillo$(CMO) socktest$(CMO)
#OBJS	= armadillo$(CMO)
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

all: basic $(DEMOS)

opt : 
	$(MAKE) OPT=YES all

just : basic rand$(EXE)

# Make stuff in subdirectories too
everything: all
	cd tk ; make
	cd life ; make

basic: $(OBJS) $(ENSCONFDEP)
	$(RM) $(EXEC)
	$(MLLINK) $(MLLINKFLAGS) -o $(EXEC) $(LIBSYS) $(ENSCONF) $(CRYPTO_LINK) $(OBJS)

#*************************************************************#
# Standard demos.  We link/copy the _exec program to the names
# of the various demos.  It's all the same executable, which
# does different things depending on its name.  This is a
# hack, but worth the savings in link time.

gossip$(EXE): $(EXEC)
	$(RM) gossip$(EXE)
	$(LN) $(EXEC) gossip$(EXE)

groupd$(EXE): $(EXEC)
	$(RM) groupd$(EXE)
	$(LN) $(EXEC) groupd$(EXE)

mtalk$(EXE): $(EXEC)
	$(RM) mtalk$(EXE)
	$(LN) $(EXEC) mtalk$(EXE)

rand$(EXE): $(EXEC)
	$(RM) rand$(EXE)
	$(LN) $(EXEC) rand$(EXE)

fifo$(EXE): $(EXEC)
	$(RM) fifo$(EXE)
	$(LN) $(EXEC) fifo$(EXE)

perf$(EXE): $(EXEC)
	$(RM) perf$(EXE)
	$(LN) $(EXEC) perf$(EXE)

ensemble$(EXE): $(EXEC)
	$(RM) ensemble$(EXE)
	$(LN) $(EXEC) ensemble$(EXE)

armadillo$(EXE): $(EXEC)
	$(RM) armadillo$(EXE)
	$(LN) $(EXEC) armadillo$(EXE)

socktest$(EXE): $(EXEC)
	$(RM) socktest$(EXE)
	$(LN) $(EXEC) socktest$(EXE)
#*************************************************************#

clean:
	$(CLEANDIR)
	$(RM) $(DEMOS_CLEAN) _exec* _runt* 
	$(RM) hot_*$(EXE) outboard$(EXE)

realclean: clean

depend:
	ocamldep -I $(ENSLIB) *.ml *.mli > $(DEPEND)

include $(DEPEND)

#*************************************************************#
# Make different versions of the demos

socket: socketexec $(DEMOS)

socketexec: $(OBJS) $(ENSCONFDEP_skt)
	$(RM) $(EXEC)
	$(MLLINK) $(MLLINKFLAGS) -o $(EXEC) $(LIBSYS) $(ENSCONF_skt) $(OBJS)

#*************************************************************#
# Install everything in the BIN directory
#

$(ENSBIN)/$(EXEC) : $(EXEC)
	$(CP) $(EXEC) $(ENSBIN)

$(ENSBIN)/gossip$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/gossip$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/gossip$(EXE)

$(ENSBIN)/groupd$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/groupd$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/groupd$(EXE)

$(ENSBIN)/mtalk$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/mtalk$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/mtalk$(EXE)

$(ENSBIN)/rand$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/rand$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/rand$(EXE)

$(ENSBIN)/fifo$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/fifo$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/fifo$(EXE)

$(ENSBIN)/perf$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/perf$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/perf$(EXE)

$(ENSBIN)/ensemble$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/ensemble$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/ensemble$(EXE)

$(ENSBIN)/armadillo$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/armadillo$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/armadillo$(EXE)

$(ENSBIN)/socktest$(EXE): $(ENSBIN)/$(EXEC)
	$(RM) $(ENSBIN)/socktest$(EXE)
	$(LN) $(ENSBIN)/$(EXEC) $(ENSBIN)/socktest$(EXE)

install : $(ENSBIN)/$(EXEC) $(ENSBIN)/gossip$(EXE) $(ENSBIN)/groupd$(EXE) $(ENSBIN)/mtalk$(EXE) $(ENSBIN)/rand$(EXE) $(ENSBIN)/fifo$(EXE) $(ENSBIN)/perf$(EXE) $(ENSBIN)/ensemble$(EXE) $(ENSBIN)/armadillo$(EXE) $(ENSBIN)/socktest$(EXE)

#*************************************************************#


