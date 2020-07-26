# -*- Mode: makefile -*- 
#*************************************************************#
#
# PREAMBLE: lists common definitions
#
# Author: Mark Hayden, 3/96
#
#*************************************************************#
VERSION = 1_42
#*************************************************************#
ENSLIB		= $(ENSROOT)/lib/$(PLATFORM)
ENS		= $(ENSLIB)/libens$(CMA)	# main ENS library 
ENSMINLIB	= $(ENSLIB)/libensmin$(CMA)	# core of Ensemble library 
ENSCORELIB	= $(ENSLIB)/libenscore$(CMA)	# core of Ensemble library 
ENSRESTLIB	= $(ENSLIB)/libensrest$(CMA)	# core of Ensemble library 
ENSTK		= $(ENSLIB)/libhtk$(CMA) 	# ENS TK support
LIBUSOCK	= $(ENSLIB)/usocket$(CMA)	# socket library for Unix
#*************************************************************#
LIBUNIX		= $(LIBMLUNIX) 
LIBSOCKDEP	= $(LIBMLSOCK) $(LIBCSOCK)
LIBTHREADS	= $(LIBMLTHREADS) -cclib $(LIBCTHREADS)
#*************************************************************#
EMRG		= emrg$(EXE)
#*************************************************************#
