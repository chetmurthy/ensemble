#*************************************************************#
#
# Main CRYPTO Makefile
#
# Author: Ohad Rodeh 11/2001
# Based on code by Mark Hayden
#
#*************************************************************#
ENSROOT = ..

include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk
#*************************************************************#
# Choose whether to use the optimizing compiler or not.
#

ifdef OPT
include $(ENSROOT)/mk/ocamlopt.mk
else
include $(ENSROOT)/mk/ocaml.mk
endif

#*************************************************************#


.SUFFIXES: .cmo .cmx .cmi .ml .mli .c .o .obj
.mli.cmi:
	ocamlc -I $(ENSLIB) -c $<
.ml.cmo:
	ocamlc $(MLFLAGS) -I $(ENSLIB) -c $<
.ml.cmx: 
	ocamlopt $(MLFLAGS) -I $(ENSLIB) -c $<
.c.o:
	$(CC) -c $(CFLAGS) -I $(ENSLIB) $< -o $@
.c.obj:
	$(CC) -c $(CFLAGS) -I $(ENSLIB) $< $(OBJRULE)$@

#*************************************************************#
# Crypto Stuff

CRYPTOOBJ = \
	isaac/isaac$(CMO)	\
	OpenSSL/rc4$(CMO)	\
	OpenSSL/dha$(CMO)

CRYPTOCOBJ = \
	isaac/isaac_c$(OBJ)	\
	isaac/randport$(OBJ)	\
	OpenSSL/rc4_c$(OBJ)	\
	OpenSSL/dha_c$(OBJ)

#*************************************************************#
all : crypto$(CMA) libcryptoc$(ARC)

opt : 
	$(MAKE) OPT=yes all

crypto$(CMA): $(CRYPTOOBJ)
	$(MLLIBR) -o crypto$(CMA) -linkall $(CRYPTOOBJ)

libcryptoc$(ARC): $(CRYPTOCOBJ)
	$(MKLIB) $(MKLIBO)libcryptoc$(ARC) $(CRYPTOCOBJ)
	$(RANLIB) libcryptoc$(ARC)

install : 
	$(CP) crypto.* libcryptoc.* $(ENSLIB)/

clean : 
	$(CLEANDIR)
	cd isaac; $(MAKE) clean
	cd OpenSSL; $(MAKE) clean


include $(ENSROOT)/$(DEPEND)
#*************************************************************#


