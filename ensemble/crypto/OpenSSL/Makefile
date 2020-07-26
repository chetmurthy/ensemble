#*************************************************************#
#
#   Ensemble, 1_42
#   Copyright 2003 Cornell University, Hebrew University
#           IBM Israel Science and Technology
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
ENSROOT = ../..
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/sub.mk
#*************************************************************#
# Local sanity tests for internal development. 
#

all : bench 

bench.o : bench.c
	gcc -c -w -O2 -I$(OPENSSL)/include bench.c  -o bench.o

bench : bench.o
	gcc -w -O2 -I$(OPENSSL)/include bench.o  \
	-L $(OPENSSL)/lib -lcrypto \
	-o bench 

#*************************************************************#
