#*************************************************************#
#
# Main CRYPTO Makefile
#
# Author: Ohad Rodeh 11/2001
# Based on code by Mark Hayden
#
#*************************************************************#
ENSROOT = ../../..

include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk

ifdef OPT
include $(ENSROOT)/mk/ocamlopt.mk
else
include $(ENSROOT)/mk/ocaml.mk
endif
#*************************************************************#

.SUFFIXES: .cmo .cmx .cmi .ml .mli
.mli.cmi:
	ocamlc -I $(ENSLIB) -c $<
.ml.cmo:
	ocamlc $(MLFLAGS) -I $(ENSLIB) -c $<
.ml.cmx: 
	ocamlopt $(MLFLAGS) -I $(ENSLIB) -c $<


#*************************************************************#
all : $(ENSLIB)/crypto_fake$(CMA) $(ENSLIB)/cryptokit_int$(CMI)

$(ENSLIB)/crypto_fake$(CMA): cryptokit_int$(CMI) cryptokit_int$(CMO)
	$(MLLIBR) -o $(ENSLIB)/crypto_fake$(CMA) cryptokit_int$(CMO)

$(ENSLIB)/cryptokit_int$(CMI) : cryptokit_int$(CMI)
	$(CP) cryptokit_int$(CMI) $(ENSLIB)/cryptokit_int$(CMI)

clean : 
	$(CLEANDIR)

#*************************************************************#


