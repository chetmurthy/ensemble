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
