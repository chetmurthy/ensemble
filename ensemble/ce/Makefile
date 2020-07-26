#*************************************************************#
#
# Main CE Makefile
#
# Author: Ohad Rodeh 11/2001
# Based on code by Mark Hayden
#
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
#*************************************************************#
# Choose whether to use the optimizing compiler or not.
#

ifdef OPT
include $(ENSROOT)/mk/ocamlopt.mk
else
include $(ENSROOT)/mk/ocaml.mk
endif
#*************************************************************#

# NT
ifeq ("$(PLATFORM)" , "nt")
MLFLAGS = #-p
CFLAGS	= #
CE_LINK_FLAGS	= $(LIBSYSCL)
else

#i386-linux
ifeq ("$(PLATFORM)" , "i386-linux")
MLFLAGS = #-p
CFLAGS =  -O2 #-g -p
CE_LINK_FLAGS = -ltermcap -lm #-lefence
else

# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
MLFLAGS = #-p
CFLAGS =  -O2 #-g -p
CE_LINK_FLAGS = -lposix4 -ltermcap -lsocket -lnsl -lm -ldl
else

ERROR = yes
endif
endif
endif

#*************************************************************#
.SUFFIXES: .ml .cmo .cmx .mli .cmi .c .o .obj .obj .cmx
.mli.cmi:
	ocamlc -c -I $(ENSLIB) $< -o $@
.ml.cmo:
	ocamlc -c $(MLFLAGS) -I $(ENSLIB) $< -o $@
.ml.cmx:
	ocamlopt -c $(MLFLAGS) -I $(ENSLIB) $< -o $@
.c.o : 
	$(CC) -c -I$(CAMLLIB) -I $(ENSLIB) $(CFLAGS) $< -o $@
.c.obj : 
	$(CC) -c -I$(CAMLLIB) -I $(ENSLIB) $(CFLAGS) $< $(OBJRULE)$@

#*************************************************************#

COBJ =\
	ce_trace$(OBJ)\
	ce_convert$(OBJ)\
	ce_misc$(OBJ)\
	ce_actions$(OBJ)\
	ce_inboard_c$(OBJ) \
	ce_flat$(OBJ) 

MLOBJ =\
	ce_util$(CMO)\
	ce_inboard$(CMO) 

MLIOBJ =\
	ce_util.cmi

DEMOS_CLEAN = ce_perf ce_rand ce_fifo ce_mtalk *.exe
DEMOS = ce_perf$(EXE) ce_rand$(EXE) ce_fifo$(EXE) ce_mtalk$(EXE) 

all: $(DEMOS) 

opt : 
	$(MAKE) OPT=yes all

#BASIC_ENSCONF_skt = $(CUSTOM) $(LIBUNIX) $(LIBSOCK) $(LINK_THR) $(ENSLIBS) 
BASIC_ENSCONF_skt = $(LIBUNIX) $(LIBSOCK) $(LINK_THR) $(ENSLIBS) 



ce$(OBJ): $(MLIOBJ) $(MLOBJ) $(ENSLIBS) 
	$(MLCOMP) -output-obj $(MLFLAGS) -o ce$(OBJ) $(BASIC_ENSCONF_skt) $(MLOBJ) $(HOT_MLLINK)

# Put all the libraries, ML code, and runtime into one library
libce$(ARC): $(COBJ) ce$(OBJ)
	$(RM) ce.c
	$(PARTIALLD) $(PARTIALLDO)libce$(OBJ)\
	  ce$(OBJ)\
	  $(COBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)libce$(ARC) libce$(OBJ)
	$(RANLIB) libce$(ARC)

ce_mtalk$(EXE): $(COBJ) ce_mtalk$(OBJ) libce$(ARC)
	$(CC) $(CFLAGS) -o ce_mtalk$(EXE)\
	  ce_mtalk$(OBJ)\
	  libce$(ARC) \
	$(CE_LINK_FLAGS)

ce_fifo$(EXE): $(COBJ) ce_fifo$(OBJ) libce$(ARC)
	$(CC) $(CFLAGS) -o ce_fifo$(EXE)\
	  ce_fifo$(OBJ)\
	  libce$(ARC) \
	$(CE_LINK_FLAGS)

ce_rand$(EXE): $(COBJ) ce_rand$(OBJ) libce$(ARC)
	$(CC) $(CFLAGS) -o ce_rand$(EXE)\
	  ce_rand$(OBJ)\
	  libce$(ARC)\
	$(CE_LINK_FLAGS)

ce_perf$(EXE): $(COBJ) ce_perf$(OBJ) libce$(ARC)
	$(CC) $(CFLAGS) -o ce_perf$(EXE)\
	  ce_perf$(OBJ)\
	  libce$(ARC)\
	$(CE_LINK_FLAGS)

#*************************************************************#
# Get's around a difference between forall syntax between
# WIN32 and Unix.
#
ifeq ("$(PLATFORM)" , "nt")
INSTALL = for %%d in ($(DEMOS)) do ( $(CP) %%d $(ENSBIN) )
else
INSTALL = $(CP) $(DEMOS) $(ENSBIN)
endif

install : 
	$(CP) libce$(ARC) $(ENSLIB)
	$(INSTALL)

#*************************************************************#

clean:
	$(CLEANDIR)
	$(RM) *.a *.lib *.dll $(DEMOS_CLEAN) 

realclean: clean 


force: clean all

#*************************************************************#




