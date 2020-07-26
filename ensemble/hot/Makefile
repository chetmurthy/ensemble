#*************************************************************#
#
# Main HOT Makefile
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

# Configuration infromation for threads and the C interfaces.

FLAG = no

# WIN32
ifeq ("$(PLATFORM)" , "nt")
FLAG = ok
HOT_THREAD_OBJ	= ntthread$(OBJ)
HOT_CFLAGS	= -DTHREADED_SELECT
HOT_MLLINK	= #?
HOT_LINK = $(C_LINK)
endif

# SPARC-SOLARIS
ifeq ("$(PLATFORM)" , "sparc-solaris")
FLAG = ok
HOT_CFLAGS = -DTHREADED_SELECT
HOT_MLLINK = # empty
HOT_LINK  = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -lresolv -ldl
HOT_THREAD_OBJ = solaris_thread$(OBJ)
endif

# I386-SOLARIS: same as for sparc_solaris
ifeq ("$(PLATFORM)" , "i386-solaris")
FLAG = ok
HOT_CFLAGS = -DTHREADED_SELECT
HOT_MLLINK = # empty
HOT_LINK = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -ldl
HOT_THREAD_OBJ = solaris_thread$(OBJ)
endif

# I386-LINUX
# The -D_RENTRANT is needed for the use of threads
ifeq ("$(PLATFORM)" , "i386-linux")
FLAG = ok
HOT_CFLAGS	= -DTHREADED_SELECT -D_REENTRANT -DLINUX_THREADS -Wno-unused
HOT_MLLINK	= # empty
HOT_LINK	= -lpthread -ltermcap -lm -ldl
HOT_THREAD_OBJ = pthread_intf$(OBJ)
endif

# ALPHA-OSF1
ifeq ("$(PLATFORM)" , "alpha-osf1")
FLAG = ok
HOT_CFLAGS	= -DOSF1_THREADS
HOT_MLLINK	=
HOT_LINK	= -lrt -lpthreads -lmach -lexc -lc_r -lm -ltermcap -taso
HOT_THREAD_OBJ  = pthread_intf$(OBJ)
endif

# RS6000-AIX
ifeq ("$(PLATFORM)" , "rs6000-aix")
FLAG = ok
HOT_CFLAGS	= -DOSF1_THREADS
HOT_MLLINK	= # empty
HOT_LINK	= -lpthreads -lm -ltermcap
HOT_THREAD_OBJ = pthread_intf$(OBJ)
endif

# HP9000-HPUX
ifeq ("$(PLATFORM)" , "hp9000-hpux")
FLAG = ok
HOT_CFLAGS	= -DHPUX_THREADS -DINLINE_PRAGMA
HOT_MLLINK	= # empty
HOT_LINK	= -ltermcap -lm -ldce
HOT_THREAD_OBJ = hpux_thread$(OBJ)
endif

# MIPS-IRIX64
ifeq ("$(PLATFORM)" , "mips-irix64")
FLAG = ok
HOT_CFLAGS_mips_irix64 = -DINLINE_PRAGMA -DTHREADED_SELECT
HOT_MLLINK_mips_irix64 = # empty
HOT_LINK_mips_irix64 = -lpthread -ltermcap -lm
HOT_THREAD_OBJ_mips_irix64 = pthread_intf$(OBJ)
endif

# If nothing is applicable
ifeq ("$(FLAG)" , "no")
all : 
	echo "No configuration for this architecture"
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
	$(CC) -c $(CFLAGS) $(HOT_CFLAGS) \
	-I $(ENSROOT)/hot/include -I $(ENSLIB) \
	$< -o $@
.c.obj:
	$(CC) -c $(CFLAGS) $(HOT_CFLAGS) \
	-I $(ENSROOT)/hot/include -I $(ENSLIB) \
	$< -o $@

#*************************************************************#
# HOT files

HOT_SHAREDOBJ = \
	hot_util$(CMO)

HOT_INBOARDOBJ = \
	$(HOT_SHAREDOBJ)	\
	hot_appl$(CMO)		\
	hot_inboard$(CMO)

HOT_OUTBOARDOBJ = \
	$(HOT_SHAREDOBJ)		\
	hot_outboard$(CMO)

HOT_SHAREDCOBJ = \
	hot_mem$(OBJ)	\
	hot_error$(OBJ)	\
	hot_sys$(OBJ)	\
	hot_msg$(OBJ)	\
	$(HOT_THREAD_OBJ) # see config.mk

HOT_INBOARDCOBJ = \
	$(HOT_SHAREDCOBJ)		\
	hot_inboard_c$(OBJ)

HOT_OUTBOARDCOBJ = \
	$(HOT_SHAREDCOBJ)		\
	hot_outboard_c$(OBJ)

#*************************************************************#
# Rules for building HOT tools

# No crypto
#
BASIC_ENSCONF_skt = $(CUSTOM) $(LIBUNIX) $(LIBMLSOCK) $(ENSLIBS) $(LINK_THR) 
CLIBS = 
CRYPTO_CLIBS = 


# To compile with cryptographic support
#
#BASIC_ENSCONF_skt = $(CUSTOM) $(LIBUNIX) $(LIBMLSOCK) $(ENSLIBS) $(LINK_THR) \
#	$(CRYPTOLIB_ML)
#CLIBS = $(CRYPTOLIB_C)
#CRYPTO_CLIBS = $(CRYPTOLIB_JUST_C)
#*************************************************************#

HOT_LINK_FULL = $(CRYPTO_CLIBS) $(HOT_LINK)  

all : \
	libhot$(ARC)	\
	libhoto$(ARC)	\
	outboard$(EXE)	\
	hot_testo$(EXE) \
	hot_test$(EXE)

opt : 
	$(MAKE) OPT=yes all

install : 
	$(CP) include/*.h 	$(ENSLIB)
	$(CP) libhot$(ARC)	$(ENSLIB)
	$(CP) libhoto$(ARC)	$(ENSLIB)
	$(CP) outboard$(EXE)	$(ENSBIN)
	$(CP) hot_testo$(EXE)	$(ENSBIN)
	$(CP) hot_test$(EXE)	$(ENSBIN)


# Create an object file containing the ML code
# We have to use ENSCONFDEP_skt because the hot_inboard_c.c
# uses the socket version of the fd representation.
hot$(OBJ): $(HOT_INBOARDOBJ)
	$(RM) hot.c
	$(MLCOMP) -output-obj -o hot$(OBJ) $(BASIC_ENSCONF_skt) $(HOT_INBOARDOBJ) $(HOT_MLLINK)

# Put all the libraries, ML code, and runtime into one library
libhot$(ARC): $(HOT_INBOARDCOBJ) hot$(OBJ) $(ENSLIB)/libsock$(ARC)
	$(PARTIALLD) $(PARTIALLDO) libhot$(OBJ) \
	  hot$(OBJ)	\
	  $(HOT_INBOARDCOBJ)	\
	  $(ENSLIB)/libsock$(ARC)	\
	  $(OCAML_LIB)/libunix$(ARCS) \
	  $(CLIBS) \
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)libhot$(ARC) libhot$(OBJ)
	$(RANLIB) libhot$(ARC)

# Put HOT objects into one library
libhoto$(ARC): $(HOT_OUTBOARDCOBJ)
	$(MKLIB) $(MKLIBO)libhoto$(ARC) $(HOT_OUTBOARDCOBJ) 
	$(RANLIB) libhoto$(ARC)

# Generate the outboard executable
outboard$(EXE): $(ENSCONFDEP) $(HOT_OUTBOARDOBJ)
	$(MLLINK) $(MLLINKFLAGS) -o outboard$(EXE) $(LIBSYS) $(ENSCONF) $(CRYPTO_LINK) $(HOT_OUTBOARDOBJ)


# Generate the hot_test executable
hot_test$(EXE): libhot$(ARC) hot_test$(OBJ)
	$(CC)  -o hot_test$(EXE) \
	  hot_test$(OBJ) \
	  libhot$(ARC) \
	  $(HOT_LINK_FULL)

# Generate the outboard test
hot_testo$(EXE): libhoto$(ARC) hot_test$(OBJ)
	$(CC)  -o hot_testo$(EXE) \
	  hot_test$(OBJ) \
	  libhoto$(ARC) \
	  $(HOT_LINK_FULL)

# Generate the performance test
hot_perf$(EXE): libhoto$(ARC) hot_perf$(OBJ) 
	$(CC)  -o hot_perf$(EXE) \
	  hot_perf$(OBJ) \
	  libhoto$(ARC) \
	  $(HOT_LINK_FULL)

# Purified version of outboard test
p_test$(EXE): libhoto$(ARC) hot_test$(OBJ) 
	$(PURIFY) $(CC)  -o p_test$(EXE) \
	  hot_test$(OBJ) \
	  libhoto$(ARC) \
	  $(HOT_LINK_FULL) $(PURIFY_LIB)

# Generate the hot_test executable
hot_test2$(EXE): libhot$(ARC) hot_test2$(OBJ)
	$(CC)  -o hot_test2$(EXE) \
	  hot_test2$(OBJ) \
	  libhot$(ARC) \
	  $(HOT_LINK_FULL)

hot_test2o$(EXE): libhoto$(ARC) hot_test2$(OBJ)
	$(CC)  -o hot_test2o$(EXE) \
	  hot_test2$(OBJ) \
	  libhoto$(ARC) \
	  $(HOT_LINK_FULL)

hot_test3$(EXE): libhot$(ARC) hot_test3$(OBJ)
	$(CC)  -o hot_test3$(EXE) \
	  hot_test3$(OBJ) \
	  libhot$(ARC) \
	  $(HOT_LINK_FULL)

hot_ping$(EXE): libhot$(ARC) hot_ping$(OBJ)
	$(CC)  -o hot_ping$(EXE) \
	  hot_ping$(OBJ) \
	  libhot$(ARC) \
	  $(HOT_LINK_FULL)

hot_pingo$(EXE): libhoto$(ARC) hot_ping$(OBJ) outboard$(EXE)
	$(CC)  -o hot_pingo$(EXE) \
	  hot_ping$(OBJ) \
	  libhoto$(ARC) \
	  $(HOT_LINK_FULL)

# Purified version of hot_test
phot_test: libhot$(ARC) hot_test$(OBJ)
	purify $(CC)  -o hot_test$(EXE) \
	  hot_test$(OBJ) \
	  libhot$(ARC) \
	  $(HOT_LINK_FULL)


#*************************************************************#
clean:
	$(RM) *.exe outboard hot_test hot_testo
	$(CLEANDIR)

depend:
	ocamldep -I $(ENSROOT)/lib/$(PLATFORM) *.ml *.mli > $(DEPEND)


include $(DEPEND)

#*************************************************************#




