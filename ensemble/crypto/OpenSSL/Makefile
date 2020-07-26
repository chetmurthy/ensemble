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
