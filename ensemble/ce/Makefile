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
include $(ENSROOT)/ce/ce_config.mk
#*************************************************************#
# Choose whether to use the optimizing compiler or not.
#

ifdef OPT
include $(ENSROOT)/mk/ocamlopt.mk
else
include $(ENSROOT)/mk/ocaml.mk
endif
#*************************************************************#

.SUFFIXES: .ml .cmo .cmx .mli .cmi .c .o .obj .cmx
.mli.cmi:
	ocamlc -c -I $(ENSLIB) $< -o $@
.ml.cmo:
	ocamlc $(MLFLAGS) -c -I $(ENSLIB) $< -o $@
.ml.cmx:
	ocamlopt $(MLFLAGS) -c -I $(ENSLIB) $< -o $@
.c.o : 
	$(CC) -c $(CFLAGS) -I $(ENSLIB) \
	$< -o $@
.c.obj : 
	$(CC) -c $(CFLAGS) -I $(ENSLIB) $< $(OBJRULE)$@

#*************************************************************#
# Single threaded version
#
COMMON = \
	ce_trace$(OBJ)\
	ce_misc$(OBJ) \
	ce_flat$(OBJ) \
	ce_actions$(OBJ)

INBOARD_OBJ_I = \
	$(COMMON) \
	ce_convert$(OBJ)\
	ce_inboard_c$(OBJ) \

OUTBOARD_OBJ_I = \
	$(COMMON) \
	mm_basic$(OBJ) \
	ce_sock_table$(OBJ) \
	ce_context_table$(OBJ) \
	ce_comm$(OBJ) \
	ce_outboard_c$(OBJ)

ST_OBJ = \
	ce_intf$(OBJ)


INBOARD_OBJ = \
	$(INBOARD_OBJ_I) \
	$(ST_OBJ)

OUTBOARD_OBJ = \
	$(OUTBOARD_OBJ_I) \
	$(ST_OBJ)

#*************************************************************#
# Multi-threaded version 
#
MT_OBJ = \
	ce_intf_mt$(OBJ)\
	ce_threads$(OBJ) \
	ce_actions_mt$(OBJ) 

INBOARD_MT_OBJ = \
	$(INBOARD_OBJ_I) \
	$(MT_OBJ) \
	ce_comm$(OBJ) \
	ce_inboard_mt$(OBJ)

OUTBOARD_MT_OBJ =\
	$(OUTBOARD_OBJ_I) \
	$(MT_OBJ) \
	ce_outboard_mt$(OBJ)

MLOBJ =\
	ce_util$(CMO)\
	ce_inboard$(CMO) 

MLIOBJ =\
	ce_util$(CMI)

#*************************************************************#
DEMOS_CLEAN = \
	ce_perf ce_rand ce_fifo ce_mtalk \
	ce_perfo ce_rando ce_fifoo ce_mtalko \
	ce_perf_mt ce_mtalk_mt ce_rand_mt ce_rando_mt \
	*.exe ce_outboard

DEMOS = \
	ce_rand$(EXE) \
	ce_perf$(EXE) \
	ce_fifo$(EXE) \
	ce_mtalk$(EXE) \
	ce_rand_mt$(EXE) \
	ce_perf_mt$(EXE) \
	ce_mtalk_mt$(EXE) 

DEMOSO = \
	ce_mtalko$(EXE) \
	ce_rando$(EXE) \
	ce_perfo$(EXE) \
	ce_fifoo$(EXE) \
	ce_rando_mt$(EXE) 

#*************************************************************#
# For windows, we use only static libraries. This is due to the
# bad behavior of the generated Ensemble DLL on that platform. 
# For unix, we use shared libraries. 
#
all: \
	libce$(CE_LIB) libceo$(CE_LIB) \
	libce_mt$(CE_LIB) libceo_mt$(CE_LIB) \
	ce_outboard$(EXE) $(DEMOSO) $(DEMOS)

opt : 
	$(MAKE) OPT=yes all

#*************************************************************#

# Need to copy the latest version of mm_basic.c
# This contains the basic declarations of iovec utility
# functions.
#
mm_basic.c : $(ENSROOT)/socket/s/mm_basic.c
	$(CP) $(ENSROOT)/socket/s/mm_basic.c .

mm_basic$(OBJ) : mm_basic.c
#*************************************************************#
#
# Create an object file containing Ensemble
#
ce$(OBJ): $(MLIOBJ) $(MLOBJ) $(ENSLIBS) 
	$(MLCOMP) -output-obj $(MLFLAGS) -o ce$(OBJ) $(ENSCONF) $(MLOBJ) 
#*************************************************************#

# Put all the libraries, ML code, and runtime into one library
libce$(SO): $(INBOARD_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(MKSHRLIB) $(MKSHRLIBO)libce$(SO) \
	  ce$(OBJ)\
	  $(INBOARD_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)\
	  $(CE_LINK_FLAGS)

# Put C outboard objects into one library
libceo$(SO): $(OUTBOARD_OBJ)
	$(MKSHRLIB) $(MKSHRLIBO)libceo$(SO) \
	  $(OUTBOARD_OBJ)\
	  $(CE_LINK_FLAGS)

##
#  Thread safe version of the above
##

# Put all the libraries, ML code, and runtime into one library
libce_mt$(SO): $(INBOARD_MT_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(MKSHRLIB) $(MKSHRLIBO)libce_mt$(SO) \
	  ce$(OBJ)\
	  $(INBOARD_MT_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)\
	  $(CE_LINK_FLAGS)

# Put C outboard objects into one library
libceo_mt$(SO): $(OUTBOARD_MT_OBJ)
	$(MKSHRLIB) $(MKSHRLIBO)libceo_mt$(SO)\
	  $(OUTBOARD_MT_OBJ)\
	  $(CE_LINK_FLAGS)

#*************************************************************#
# static libraries for the above
#
libce$(ARC): $(INBOARD_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(PARTIALLD) $(PARTIALLDO) libce$(OBJ) \
	  ce$(OBJ)\
	  $(INBOARD_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)libce$(ARC) libce$(OBJ) 
	$(RANLIB) libce$(ARC)

libceo$(ARC): $(OUTBOARD_OBJ)
	$(PARTIALLD) $(PARTIALLDO) libceo$(OBJ) \
	  $(OUTBOARD_OBJ) 
	$(MKLIB) $(MKLIBO)libceo$(ARC) libceo$(OBJ)
	$(RANLIB) libceo$(ARC)

libce_mt$(ARC): $(INBOARD_MT_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(PARTIALLD) $(PARTIALLDO) libce_mt$(OBJ) \
	  ce$(OBJ)\
	  $(INBOARD_MT_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)libce_mt$(ARC) libce_mt$(OBJ)
	$(RANLIB) libce_mt$(ARC)

libceo_mt$(ARC): $(OUTBOARD_MT_OBJ)
	$(PARTIALLD) $(PARTIALLDO) libceo_mt$(OBJ) \
	  $(OUTBOARD_MT_OBJ)
	$(MKLIB) $(MKLIBO)libceo_mt$(ARC) libceo_mt$(OBJ)
	$(RANLIB) libceo_mt$(ARC)

#*************************************************************#

# Generate the outboard executable
ce_outboard$(EXE): $(MLIOBJ) ce_util$(CMO) ce_outboard$(CMO) 
	$(MLLINK) -o ce_outboard$(EXE) \
	$(LIBSYS) $(ENSCONF) ce_util$(CMO) ce_outboard$(CMO) 


ce_rando$(EXE): ce_rand$(OBJ) ce_md5$(OBJ) libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_rando$(EXE)\
	  ce_rand$(OBJ)\
	  ce_md5$(OBJ)\
	  libceo$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_rando_mt$(EXE):  ce_rand_mt$(OBJ) ce_md5$(OBJ) libceo_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_rando_mt$(EXE)\
	  ce_rand_mt$(OBJ)\
	  ce_md5$(OBJ)\
	  libceo_mt$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_mtalko$(EXE):  ce_mtalk$(OBJ) libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_mtalko$(EXE)\
	  ce_mtalk$(OBJ)\
	  libceo$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_fifoo$(EXE):  ce_fifo$(OBJ) libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_fifoo$(EXE)\
	  ce_fifo$(OBJ)\
	  libceo$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_perfo$(EXE):  ce_perf$(OBJ) libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_perfo$(EXE)\
	  ce_perf$(OBJ)\
	  libceo$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_rand$(EXE):  ce_rand$(OBJ) ce_md5$(OBJ) libce$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_rand$(EXE)\
	  ce_rand$(OBJ)\
	  ce_md5$(OBJ)\
	  libce$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_mtalk$(EXE):  ce_mtalk$(OBJ) libce$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_mtalk$(EXE)\
	  ce_mtalk$(OBJ)\
	  libce$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_fifo$(EXE):  ce_fifo$(OBJ) libce$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_fifo$(EXE)\
	  ce_fifo$(OBJ)\
	  libce$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_perf$(EXE):  ce_perf$(OBJ) libce$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_perf$(EXE)\
	  ce_perf$(OBJ)\
	  libce$(CE_LNKLIB) $(CE_LINK_FLAGS)


ce_rand_mt$(EXE):  ce_rand_mt$(OBJ) ce_md5$(OBJ) libce_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_rand_mt$(EXE)\
	  ce_rand_mt$(OBJ)\
	  ce_md5$(OBJ)\
	  libce_mt$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_mtalk_mt$(EXE):  ce_mtalk_mt$(OBJ) libce_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_mtalk_mt$(EXE)\
	  ce_mtalk_mt$(OBJ)\
	  libce_mt$(CE_LNKLIB) $(CE_LINK_FLAGS)

ce_perf_mt$(EXE):  ce_perf$(OBJ) libce_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o ce_perf_mt$(EXE)\
	  ce_perf$(OBJ)\
	  libce_mt$(CE_LNKLIB) $(CE_LINK_FLAGS)


#*************************************************************#
# Get's around a difference between forall syntax between
# WIN32 and Unix.
#
ifeq ("$(PLATFORM)" , "nt")
install : 
	$(CP) libce*.lib $(ENSLIB)
	$(CP) ce.h $(ENSLIB)
	$(CP) ce_threads.h $(ENSLIB)
	$(CP) ce_so.h $(ENSLIB)
	for %%d in ($(DEMOS) $(DEMOSO) ce_outboard$(EXE)) do ( $(CP) %%d $(ENSBIN) )

#	$(CP) libce*.exp $(ENSLIB)
#	$(CP) libce*.dll $(ENSLIB)

else
install : 
	$(CP) libce*.so $(ENSLIB)
	$(CP) ce.h $(ENSLIB)
	$(CP) ce_threads.h $(ENSLIB)
	$(CP) ce_so.h $(ENSLIB)
	$(CP) $(DEMOS) $(DEMOSO) ce_outboard$(EXE) $(ENSBIN)
endif

#*************************************************************#

clean:
	$(CLEANDIR)
	$(RM) ce.c mm_basic.c *.lib *.dll *.ilk *.pdb *.exp *.so *.a $(DEMOS_CLEAN) 

realclean: clean 


force: clean all

depend : 
	ocamldep -I $(ENSROOT)/lib/$(PLATFORM) *.ml *.mli > $(DEPEND)

#*************************************************************#




