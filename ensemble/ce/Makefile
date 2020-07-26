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
	ce_appl_env_list$(OBJ) \
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

DEMOS = \
	$(ENSBIN)/ce_rand$(EXE) \
	$(ENSBIN)/ce_perf$(EXE) \
	$(ENSBIN)/ce_fifo$(EXE) \
	$(ENSBIN)/ce_mtalk$(EXE) \
	$(ENSBIN)/ce_rand_mt$(EXE) \
	$(ENSBIN)/ce_perf_mt$(EXE) \
	$(ENSBIN)/ce_mtalk_mt$(EXE)

DEMOSO = \
	$(ENSBIN)/ce_mtalko$(EXE) \
	$(ENSBIN)/ce_rando$(EXE) \
	$(ENSBIN)/ce_perfo$(EXE) \
	$(ENSBIN)/ce_fifoo$(EXE) \
	$(ENSBIN)/ce_rando_mt$(EXE) 

#*************************************************************#
# For windows, we use only static libraries. This is due to the
# bad behavior of the generated Ensemble DLL on that platform. 
# For unix, we use shared libraries. 
#
#tst : tst.c
#	gcc -o tst tst.c -lpthread

all: \
	$(ENSLIB)/libce$(CE_LIB) $(ENSLIB)/libceo$(CE_LIB) \
	$(ENSLIB)/libce_mt$(CE_LIB) $(ENSLIB)/libceo_mt$(CE_LIB) \
	$(ENSBIN)/ce_outboard$(EXE) \
	$(ENSLIB)/ce.h $(ENSLIB)/ce_threads.h \
	$(DEMOSO) \
	$(DEMOS)

opt : 
	$(MAKE) OPT=yes all

debug : 
	$(MAKE) OPT=yes CE_DEBUG=yes all
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
$(ENSLIB)/libce$(SO): $(INBOARD_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(MKSHRLIB) $(MKSHRLIBO)$(ENSLIB)/libce$(SO) \
	  ce$(OBJ)\
	  $(INBOARD_OBJ)\
	  $(ENSROOT)/lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME) \
	$(CE_LINK_FLAGS)

# Put C outboard objects into one library
$(ENSLIB)/libceo$(SO): $(OUTBOARD_OBJ)
	$(MKSHRLIB) $(MKSHRLIBO)$(ENSLIB)/libceo$(SO) \
	  $(OUTBOARD_OBJ)\
	$(CE_LINK_FLAGS)

##
#  Thread safe version of the above
##

# Put all the libraries, ML code, and runtime into one library
$(ENSLIB)/libce_mt$(SO): $(INBOARD_MT_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(MKSHRLIB) $(MKSHRLIBO)$(ENSLIB)/libce_mt$(SO) \
	  ce$(OBJ)\
	  $(INBOARD_MT_OBJ)\
	  $(ENSROOT)/lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)\
	$(CE_LINK_FLAGS) $(CE_THREAD_LIB)

# Put C outboard objects into one library
$(ENSLIB)/libceo_mt$(SO): $(OUTBOARD_MT_OBJ)
	$(MKSHRLIB) $(MKSHRLIBO)$(ENSLIB)/libceo_mt$(SO)\
	  $(OUTBOARD_MT_OBJ) \
	$(CE_LINK_FLAGS) $(CE_THREAD_LIB)

#*************************************************************#
# static libraries for the above
#
$(ENSLIB)/libce$(ARC): $(INBOARD_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(PARTIALLD) $(PARTIALLDO) $(ENSLIB)/libce$(OBJ) \
	  ce$(OBJ)\
	  $(INBOARD_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)$(ENSLIB)/libce$(ARC) libce$(OBJ) 
	$(RANLIB) libce$(ARC)

$(ENSLIB)/libceo$(ARC): $(OUTBOARD_OBJ)
	$(PARTIALLD) $(PARTIALLDO) $(ENSLIB)/libceo$(OBJ) \
	  $(OUTBOARD_OBJ) 
	$(MKLIB) $(MKLIBO)$(ENSLIB)/libceo$(ARC) libceo$(OBJ)
	$(RANLIB) $(ENSLIB)/libceo$(ARC)

$(ENSLIB)/libce_mt$(ARC): $(INBOARD_MT_OBJ) ce$(OBJ)
	$(RM) ce.c
	$(PARTIALLD) $(PARTIALLDO) $(ENSLIB)/libce_mt$(OBJ) \
	  ce$(OBJ)\
	  $(INBOARD_MT_OBJ)\
	  ../lib/$(PLATFORM)/libsock$(ARC)\
	  $(OCAML_LIB)/libunix$(ARCS)\
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)$(ENSLIB)/libce_mt$(ARC) libce_mt$(OBJ)
	$(RANLIB) $(ENSLIB)/libce_mt$(ARC)

$(ENSLIB)/libceo_mt$(ARC): $(OUTBOARD_MT_OBJ)
	$(PARTIALLD) $(PARTIALLDO) $(ENSLIB)/libceo_mt$(OBJ) \
	  $(OUTBOARD_MT_OBJ)
	$(MKLIB) $(MKLIBO)l$(ENSLIB)/ibceo_mt$(ARC) libceo_mt$(OBJ)
	$(RANLIB) $(ENSLIB)/libceo_mt$(ARC)

#*************************************************************#

# Generate the outboard executable
$(ENSBIN)/ce_outboard$(EXE): $(MLIOBJ) ce_util$(CMO) ce_outboard$(CMO) 
	$(MLLINK) -o $(ENSBIN)/ce_outboard$(EXE) \
	$(LIBSYS) $(ENSCONF) ce_util$(CMO) ce_outboard$(CMO) 


$(ENSBIN)/ce_rando$(EXE): ce_rand$(OBJ) ce_md5$(OBJ) $(ENSLIB)/libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_rando$(EXE)\
	  ce_rand$(OBJ)\
	  ce_md5$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ceo$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_rando_mt$(EXE):  ce_rand_mt$(OBJ) ce_md5$(OBJ) $(ENSLIB)/libceo_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_rando_mt$(EXE)\
	  ce_rand_mt$(OBJ)\
	  ce_md5$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ceo_mt$(LIB_SUFF) $(CE_LINK_FLAGS) $(CE_THREAD_LIB)

$(ENSBIN)/ce_mtalko$(EXE):  ce_mtalk$(OBJ) $(ENSLIB)/libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_mtalko$(EXE)\
	  ce_mtalk$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ceo$(LIB_SUFF) $(CE_LINK_FLAGS) 

$(ENSBIN)/ce_fifoo$(EXE):  ce_fifo$(OBJ) $(ENSLIB)/libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_fifoo$(EXE)\
	  ce_fifo$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ceo$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_perfo$(EXE):  ce_perf$(OBJ) $(ENSLIB)/libceo$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_perfo$(EXE)\
	  ce_perf$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ceo$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_rand$(EXE):  ce_rand$(OBJ) ce_md5$(OBJ) $(ENSLIB)/libce$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_rand$(EXE)\
	  ce_rand$(OBJ)\
	  ce_md5$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_mtalk$(EXE):  ce_mtalk$(OBJ) $(ENSLIB)/libce$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_mtalk$(EXE)\
	  ce_mtalk$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_fifo$(EXE):  ce_fifo$(OBJ) $(ENSLIB)/libce$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_fifo$(EXE)\
	  ce_fifo$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_perf$(EXE):  ce_perf$(OBJ) $(ENSLIB)/libce$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_perf$(EXE)\
	  ce_perf$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce$(LIB_SUFF) $(CE_LINK_FLAGS)

$(ENSBIN)/ce_rand_mt$(EXE):  ce_rand_mt$(OBJ) ce_md5$(OBJ) $(ENSLIB)/libce_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_rand_mt$(EXE)\
	  ce_rand_mt$(OBJ)\
	  ce_md5$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce_mt$(LIB_SUFF) $(CE_LINK_FLAGS) $(CE_THREAD_LIB)

$(ENSBIN)/ce_mtalk_mt$(EXE):  ce_mtalk_mt$(OBJ) $(ENSLIB)/libce_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_mtalk_mt$(EXE)\
	  ce_mtalk_mt$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce_mt$(LIB_SUFF) $(CE_LINK_FLAGS) $(CE_THREAD_LIB)

$(ENSBIN)/ce_perf_mt$(EXE):  ce_perf$(OBJ) $(ENSLIB)/libce_mt$(CE_LIB)
	$(CC) $(CFLAGS) -o $(ENSBIN)/ce_perf_mt$(EXE)\
	  ce_perf$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ce_mt$(LIB_SUFF) $(CE_LINK_FLAGS) $(CE_THREAD_LIB)

#*************************************************************#
$(ENSLIB)/ce.h : ce.h
	$(CP) ce.h $(ENSLIB)

$(ENSLIB)/ce_threads.h : ce_threads.h
	$(CP) ce_threads.h $(ENSLIB)

#*************************************************************#

clean:
	$(CLEANDIR)
	$(RM) ce.c mm_basic.c *.lib *.dll *.ilk *.pdb *.exp *.so *.a $(DEMOS_CLEAN) 

realclean: clean 


force: clean all

depend : 
	ocamldep -I $(ENSROOT)/lib/$(PLATFORM) *.ml *.mli > $(DEPEND)

#*************************************************************#




