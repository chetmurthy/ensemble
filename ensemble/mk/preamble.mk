# -*- Mode: makefile -*- 
#*************************************************************#
#
# PREAMBLE: lists common definitions
#
# Author: Mark Hayden, 3/96
#
#*************************************************************#
VERSION = 2_01
VERSION_DIR = 2.01
#*************************************************************#
ENSLIB		= $(ENSROOT)/lib/$(PLATFORM)
ENS		= $(ENSLIB)/libens$(CMA)	# main ENS library 
ENSMINLIB	= $(ENSLIB)/libensmin$(CMA)	# core of Ensemble library 
ENSCORELIB	= $(ENSLIB)/libenscore$(CMA)	# core of Ensemble library 
ENSRESTLIB	= $(ENSLIB)/libensrest$(CMA)	# core of Ensemble library 
LIBUSOCK	= $(ENSLIB)/usocket$(CMA)	# socket library for Unix
#*************************************************************#
LIBUNIX		= $(LIBMLUNIX) 
LIBSOCKDEP	= $(LIBMLSOCK) $(LIBCSOCK)
#*************************************************************#
EMRG		= emrg$(EXE)
#*************************************************************#

