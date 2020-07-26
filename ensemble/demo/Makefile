#*************************************************************#
#
#   Ensemble, (Version 1.00)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
# DEMO directory default Makefile
#
# This makefile includes ocaml.mk definitions for building bytecode
# executables.  Makefile.opt is the same file, but includes
# ocamlopt.mk.
#
# Author: Mark Hayden, 8/96
#
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/ocaml.mk
include Makefile.base

# Build using the optimizing compiler
opt:
	$(MAKE) -f Makefile.opt
crypto-opt : 
	$(MAKE) -f Makefile.opt crypto
socketopt:
	$(MAKE) -f Makefile.opt socket
just_ensemble:
	$(MAKE) -f Makefile.opt just_ensemble

