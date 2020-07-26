#*************************************************************#
#
#   Ensemble, 1.10
#   Copyright 2001 Cornell University, Hebrew University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#ENSROOT = ../..
#include $(ENSROOT)/mk/sub.mk

OPENSSL = /cs/phd/orodeh/far/e/openssl/$(PLATFORM)
OPENSSL_INC = -I $(OPENSSL)/include
OPENSSL_LIB = $(OPENSSL)/lib/libcrypto$(ARC)

all : bench 

bench.o : bench.c
	gcc -c -w -O2 -I$(OPENSSL)/include bench.c  -o bench.o

bench : bench.o
	gcc -w -O2 -I$(OPENSSL)/include bench.o  \
	-L $(OPENSSL)/lib -lcrypto \
	-o bench 

clean :  
	rm -f *.o idea_c des_c rc4_c *.cm* gct dha rc4 des

