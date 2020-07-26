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
# PREAMBLE: lists common definitions
#
# Author: Mark Hayden, 3/96
#
#*************************************************************#
OBJD		= obj/$(PLATFORM)
ENSLIB		= $(ENSROOT)/lib/$(PLATFORM)
ENS		= $(ENSLIB)/libens$(CMA)	# main ENS library 
ENSMINLIB	= $(ENSLIB)/libensmin$(CMA)	# core of Ensemble library 
ENSCORELIB	= $(ENSLIB)/libenscore$(CMA)	# core of Ensemble library 
ENSRESTLIB	= $(ENSLIB)/libensrest$(CMA)	# core of Ensemble library 
RPC		= $(ENSLIB)/librpc$(CMA)	# RvR's RPC library
ENSTK		= $(ENSLIB)/libhtk$(CMA)	# ENS TK support
LIBUSOCK	= $(ENSLIB)/usocket$(CMA)	# socket library for Unix
#*************************************************************#
LIBUNIX		= $(LIBMLUNIX) -cclib $(LIBCUNIX)
LIBSOCK		= $(LIBMLSOCK) -cclib $(LIBCSOCK)
LIBSTR		= $(LIBMLSTR) -cclib $(LIBCSTR)
LIBSTRBC	= $(LIBMLSTRBC) -cclib $(LIBCSTR)
LIBSOCKDEP	= $(LIBMLSOCK) $(LIBCSOCK)
LIBTHREADS	= $(LIBMLTHREADS) -cclib $(LIBCTHREADS)
#*************************************************************#
ECAMLC		= $(OBJD)/ecamlc$(EXE)
ECAMLDEP	= $(OBJD)/ecamldep$(EXE)
EMV		= $(OBJD)/emv$(EXE)
ECP		= $(OBJD)/ecp$(EXE)
EMRG		= $(OBJD)/emrg$(EXE)
#ESED		= $(OBJD)/esed-$(PLATFORM)$(EXE)
ESED		= $(OBJD)/esed$(EXE)
ELONG		= $(OBJD)/elong$(EXE)
ETOUCH		= $(OBJD)/etouch$(EXE)
#ECRCS		= $(OBJD)/ecrc$(EXE)
#*************************************************************#
ECAMLCC		= $(ECAMLC)
ECAMLDEPC	= ocamlrun $(ECAMLDEP)
#EMVC		= ocamlrun $(EMV) -plat $(PLATFORM)
#ECPC		= ocamlrun $(ECP) -plat $(PLATFORM)
EMVC		= ocamlrun $(EMV)
ECPC		= ocamlrun $(ECP)
ETOUCHC		= ocamlrun $(ETOUCH)
ESEDC		= $(ESED)
EMRGC		= ocamlrun $(EMRG)
ELONGC		= ocamlrun $(ELONG)
#ECRCSC		= ocamlrun $(OBJD)/ecrc$(EXE)
#*************************************************************#
