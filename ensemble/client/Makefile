#*************************************************************#
#
# Makefile: client Makefiles
#
# Author: Ohad Rodeh  12/2003
#
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/config.mk

clean : 
	cd c; $(MAKE) clean
	cd java; $(MAKE) clean
	cd cs; $(MAKE) clean

all: 
	cd c; $(MAKE) all

#	cd java; $(MAKE) all

tests: 
	cd c; $(MAKE) tests

depend : 
	echo "Currently, 'make depend' is unimplemented"
