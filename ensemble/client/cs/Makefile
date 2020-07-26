#*************************************************************#
#
#   Ensemble, 2_00
#   Copyright 2004 Cornell University, Hebrew University
#           IBM Israel Science and Technology
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
# Main CS Makefile
#
# Author: Ohad Rodeh 8/2003
# Based on code by Mark Hayden
#
#*************************************************************#
ENSROOT = ../..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
#*************************************************************#

ifeq ("$(PLATFORM)" , "nt")
clean : 
	$(RM_REC) *.dll
	$(RM_REC) *.pdb
	$(RM_REC) *.exe
else
clean : 
	$(RM) ENS/*/*/*/*.dll
	$(RM) ENS/*/*/*/*.pdb
	$(RM) ENS/*/*/*/*.exe
endif

#*************************************************************#
