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
# Main CE Makefile
#
# Author: Ohad Rodeh 11/2001
# Based on code by Mark Hayden
#
#*************************************************************#
ENSROOT = ../..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/client/c/c_config.mk
#*************************************************************#

.SUFFIXES: .c .o .obj .cmx
.c.o : 
	$(CC) -c $(CFLAGS) -I $(ENSLIB) \
	$< -o $@
.c.obj : 
	$(CC) -c $(CFLAGS) -I $(ENSLIB) $< $(OBJRULE)$@

#*************************************************************#

OBJECTS = \
	ens_utils$(OBJ) \
	ens_hashtbl$(OBJ) \
	ens_connection$(OBJ) \
	ens_comm$(OBJ) \
	ens_threads$(OBJ)

TESTS = \
	$(ENSBIN)/c_rand$(EXE) \
	$(ENSBIN)/c_perf$(EXE)

DEMOS = \
	$(ENSBIN)/c_mtalk$(EXE)

#*************************************************************#
all: \
	$(ENSLIB)/libens$(ARC)  \
	$(ENSLIB)/ens.h \
	$(ENSLIB)/ens_threads.h \
	$(DEMOS)

tests : all $(TESTS)

opt : 
	$(MAKE) OPT=yes all

#*************************************************************#

# static library
#
$(ENSLIB)/libens$(ARC): $(OBJECTS)
	$(MKLIB) $(MKLIBO)$(ENSLIB)/libens$(ARC) $(OBJECTS)
	$(RANLIB) $(ENSLIB)/libens$(ARC)

#*************************************************************#

$(ENSBIN)/c_mtalk$(EXE):  c_mtalk$(OBJ) $(ENSLIB)/libens$(ARC)
	$(CC) $(CFLAGS) -o $(ENSBIN)/c_mtalk$(EXE)\
	  c_mtalk$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ens$(LIB_SUFF) $(LINK_FLAGS) $(THREAD_LIB)

$(ENSBIN)/c_rand$(EXE):  c_rand$(OBJ) md5$(OBJ) $(ENSLIB)/libens$(ARC)
	$(CC) $(CFLAGS) -o $(ENSBIN)/c_rand$(EXE)\
	  c_rand$(OBJ) md5$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ens$(LIB_SUFF) $(LINK_FLAGS) $(THREAD_LIB)

$(ENSBIN)/c_perf$(EXE):  c_perf$(OBJ) md5$(OBJ) $(ENSLIB)/libens$(ARC)
	$(CC) $(CFLAGS) -o $(ENSBIN)/c_perf$(EXE)\
	  c_perf$(OBJ) md5$(OBJ)\
	  $(LIB_PATH)$(ENSLIB) $(LIB_PREF)ens$(LIB_SUFF) $(LINK_FLAGS) $(THREAD_LIB)
#*************************************************************#
$(ENSLIB)/ens.h : ens.h
	$(CP) ens.h $(ENSLIB)

$(ENSLIB)/ens_threads.h : ens_threads.h
	$(CP) ens_threads.h $(ENSLIB)

#*************************************************************#

clean:
	$(CLEANDIR) 

realclean: clean 

force: clean all

depend : 

#*************************************************************#




