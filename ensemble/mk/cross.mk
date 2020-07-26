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
# CROSS
#
# Author: Mark Hayden, 6/97
#
#*************************************************************#
# "Cross-compile" for the Nt Unix library.  These rules only run 
# under Unix, and only from the ensemble/def directory.
# This should no longer be needed.

cross: $(OBJD)/nt $(ENSLIB)/libens-nt$(CMA) $(ENSLIB)/socket-nt$(CMA)

$(ENSLIB)/libens-nt$(CMA): $(OBJD)/nt/libens$(CMA) $(ECP)
	$(ECPC) -mlext -nocmo -nocmi $(OBJD)/nt/libens -o $(ENSLIB)/libens-nt

$(ENSLIB)/socket-nt$(CMA): $(OBJD)/nt/socket$(CMA) $(ECP)
	$(ECPC) -mlext -nocmo -nocmi $(OBJD)/nt/socket -o $(ENSLIB)/socket-nt

$(OBJD)/nt:
	mkdir -p $(OBJD)/nt

$(OBJD)/nt/unix.mli: $(LIBNTUNIX)/unix.mli $(ECP)
	$(ECPC) $(LIBNTUNIX)/unix.mli -o $(OBJD)/nt/unix.mli

$(OBJD)/nt/unix$(CMI): $(OBJD)/nt/unix.mli
	cd $(OBJD)/nt ; $(MLCOMP) -c unix.mli

$(OBJD)/nt/socket.cma: $(ECP) \
	  $(OBJD)/nt/unix$(CMI)		\
	  $(ENSROOT)/socket/socksupp.mli \
	  $(ENSROOT)/socket/socksupp.ml	\
	  $(ENSROOT)/socket/socket.mli	\
	  $(ENSROOT)/socket/socket.ml
	$(ECPC) $(ENSROOT)/socket/socksupp.mli -o $(OBJD)/nt/socksupp.mli
	$(ECPC) $(ENSROOT)/socket/socksupp.ml  -o $(OBJD)/nt/socksupp.ml
	$(ECPC) $(ENSROOT)/socket/socket.mli   -o $(OBJD)/nt/socket.mli
	$(ECPC) $(ENSROOT)/socket/socket.ml    -o $(OBJD)/nt/socket.ml
	cd $(OBJD)/nt ; $(MLCOMP) -c socksupp.mli
	cd $(OBJD)/nt ; $(MLCOMP) -c socksupp.ml
	cd $(OBJD)/nt ; $(MLCOMP) -c socket.mli
	cd $(OBJD)/nt ; $(MLCOMP) -c socket.ml
	$(MLLIBR) -o $(OBJD)/nt/socket.cma -linkall $(OBJD)/nt/socksupp.cmo $(OBJD)/nt/socket.cmo

$(OBJD)/nt/hsys.cmo: $(ECP) \
	  $(OBJD)/nt/unix$(CMI) \
	  $(OBJD)/nt/socket$(CMA) \
	  $(ENSROOT)/util/hsys.ml \
	  $(ENSROOT)/util/hsys.ml
	$(ECPC) $(ENSROOT)/util/hsys.mli -o $(OBJD)/nt/hsys.mli
	$(ECPC) $(ENSROOT)/util/hsys.ml -o $(OBJD)/nt/hsys.ml
	cd $(OBJD)/nt ; $(MLCOMP) -c hsys.mli
	cd $(OBJD)/nt ; $(MLCOMP) -c hsys.ml

$(OBJD)/nt/libens$(CMA): $(OBJD)/nt/hsys$(CMO) $(ENSOBJ) $(OBJD)/ensemble$(CMO)
	$(MLLIBR) -o $(OBJD)/nt/libens$(CMA) -linkall $(OBJD)/nt/hsys$(CMO) $(ENSOBJ) $(OBJD)/ensemble$(CMO)

#*************************************************************#
