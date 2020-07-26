# -*- Mode: makefile -*- 
#*************************************************************#
#
# CONFIG: This set of definitions is included at the beginning
# of the makefiles to define configurable compilation
# parameters.  For Unix.
#
# Author: Mark Hayden, Robbert vanRenesse, 4/96
# Changes: Ohad Rodeh, 8/2001
#
#*************************************************************#
# C Compilation macros.  Used for compiling Socket library
# and the C interface.  Ensemble has been compiled with gcc
# and acc on SunOS4, Solaris, and Aix.  With cl on NT.
# With cc on IRIX 6.5.

# Code Generation Options
# For Ocaml2.01/2.02 on Irix use : -n32 -mips4
CODEGEN = # -n32 -mips4  Default for non-Irix is nothing

# C compiler to use
CC	= gcc

# Note: ENS_CFLAGS is taken from the environment variables.

#*************************************************************#
# The default cryptographic library. We use OpenSSL
# that compiles and runs on many different platforms. 

CRYPTO_LINK = # no crypto by default

# Where to find the OpenSSL cryptographic library. 
#OPENSSL = /cs/phd/orodeh/far/e/openssl/$(PLATFORM)
#OPENSSL = /cs/phd/orodeh/far/e/openssl/i386-linux
#OPENSSL_INC = -I $(OPENSSL)/include
#
#CRYPTOLIB_ML = \
#	$(ENSLIB)/crypto$(CMA)	
#CRYPTOLIB_C = \
#	$(ENSLIB)/libcryptoc$(ARC) \
#	$(OPENSSL)/lib/libcrypto$(ARC)
#
#CRYPTO_LINK = \
#	-cclib $(ENSLIB)/libcryptoc$(ARC) \
#	-cclib $(OPENSSL)/lib/libcrypto$(ARC) \
#	$(CRYPTOLIB_ML) 


#*************************************************************#

# CFLAGS: used for compilation of C files
CFLAGS	= -O2 \
	-Wall \
        $(CODEGEN)                      \
	-I $(OCAML_LIB)			\
	-I $(ENSROOT)/hot/include	\
	$(PURIFY_CFLAGS)		\
	$(ENS_CFLAGS)			\
	$(HOT_CFLAGS)			\
	$(ETH_CFLAGS)			\
	-DOSTYPE=$(ENS_OSTYPE)		\
	-DMACHTYPE=$(ENS_MACHTYPE)	\
	-DHAS_IP_MULTICAST		\
	-DHAS_SENDMSG			\
	$(OPENSSL_INC)


# LIBSYS: used for linking executables
LIBSYS	= # default for Unix is nothing

# SHELL to use for processing these makefiles must be /bin/sh
SHELL = /bin/sh












#*************************************************************#
# Arguments to use for linking with CamlTk.  You may need to
# add "-ccopt -Ldir" arguments).

TKLIBS = \
	-cclib -lcamltk41 \
	-cclib -ltk	\
	-cclib -ltcl	\
	-cclib -ldl	\
	-ccopt -L/usr/X11R6/lib \
	-cclib -lX11

#*************************************************************#
# PLATFORM describes the Unix platform you are using.  This
# is used to differentiate machine dependent files.  On Unix
# platforms (without the Socket library) there are no
# machine-dependent files for the bytecode version of
# Ensemble, so these do not need to be set.  The default is
# to use the GNU "standards" of machine_name-os_name.  If
# you are using the tcsh shell, then the environment
# variables ENS_MACHTYPE and ENS_OSTYPE will be set correctly for
# your platform and you can use the defaults.  On NT,
# PLATFORM should be set to be 'nt'.

# ENS_MACHTYPE = # type of machine: sparc, i386, rs6000, alpha, ...
# ENS_OSTYPE = # os: sunos4, solaris, aix, osf1, linux
# !NOTE! make sure there are no trailing spaces on the next line
PLATFORM	= $(ENS_MACHTYPE)-$(ENS_OSTYPE)

#*************************************************************#
# FOR INITIAL CONFIGURATION, NOTHING BELOW HERE SHOULD NEED TO
# BE EDITED.
#*************************************************************#
#*************************************************************#

#*************************************************************#
# Decide whether or not to use dynamic linking.  The default
# is 'no'.  If this is set to yes, then you need the asmdynlink
# library from http://pauillac.inria.fr/~lefessan/src/.

# 'yes' or 'no'
# !NOTE! make sure there are no trailing spaces on the next line
USE_DYNLINK = no

DYNLINKSTUFF_no_opt   = $(ENSLIB)/_nulldynlink$(CMO)
DYNLINKSTUFF_yes_opt  = $(LIBDYNLINK)
DYNLINKSTUFF_no_byte  = $(ENSLIB)/_nulldynlink$(CMO)
DYNLINKSTUFF_yes_byte = $(LIBDYNLINK)



DYNLINKSTUFF = $(DYNLINKSTUFF_$(USE_DYNLINK)_$(COMPTYPE))

#*************************************************************#
# There are 3 levels of libraries to use.  The core library
# contains the minimal Ensemble library.  There is not enough
# included to run any protocol stacks, so additional modules
# need to be dynamically linked (so this cannot be used with
# the native code libraries, and USE_DYNLINK must be set!).
# The min library includes a minimal set of layers and other
# stuff that can be used to run the default Ensemble protocol
# stack and a a total ordering layer for using totally ordered
# layers.  The full library contains everything not in the
# previous two libraries.  The macro ENSLIBS_TYPE is used to
# switch betwen these different configurations.  The default
# value is "full", which is the safest (although largest)
# version.

# 'core' or 'min' or 'full'
# !NOTE! make sure there are no trailing spaces on the next line
ENSLIBS_TYPE = full

ENSLIBS_core_byte = $(ENSCORELIB)
ENSLIBS_core_opt  = $(ENSLIBS_min_opt) # override, because native code does not have dynamic linking

ENSLIBS_min_byte  = $(ENSLIBS_core_byte) $(ENSMINLIB)
ENSLIBS_min_opt   = $(ENSLIBS_min_byte)

ENSLIBS_full_byte = $(ENSLIBS_min_byte) $(ENSRESTLIB)
ENSLIBS_full_opt  = $(ENSLIBS_full_byte)

ENSLIBS_DEP	= $(ENSLIBS_$(ENSLIBS_TYPE)_$(COMPTYPE))
ENSLIBS		= $(DYNLINKSTUFF) $(ENSLIBS_DEP)




#*************************************************************#
# There are two different configurations of Ensemble.  For
# Unix, the default is to use the Unix library.  For NT, only
# the socket library is supported.  HSYS_BUILD determines
# which configurations should be built.  ENSCONFDEP is the set
# of Ensemble system modules being used.  ENSCONF also
# includes O'caml modules and specifies whether -custom flag
# should be used.

# 'unix' or 'skt'
# !NOTE! make sure there are no trailing spaces on the next line
HSYS_TYPE = skt

# Socket library
HSYS_BUILD_skt	= socket
ENSCONFDEP_skt	= $(LIBSOCKDEP) $(ENSLIBS_DEP)
ENSCONF_skt	= $(CUSTOM) $(LIBUNIX) $(LIBSOCK) $(LINK_THR) $(ENSLIBS) $(CRYPTO_LINK)

# Unix library
HSYS_BUILD_unix	= $(LIBUSOCK)
ENSCONFDEP_unix	= $(LINKTHR) $(LIBUSOCK) $(ENSLIBS_DEP)
#ENSCONF_unix   = $(CUSTOM) $(LIBUNIX) $(LIBUSOCK) $(LINK_THR) $(ENSLIBS)
#ENSCONF_unix   = $(LIBUNIX) $(LIBUSOCK) $(LINK_THR) $(ENSLIBS)
ENSCONF_unix    = $(CUSTOM) $(LIBUNIX) $(LIBUSOCK) $(LINK_THR) $(ENSLIBS) $(CRYPTO_LINK)

HSYS_BUILD	= $(HSYS_BUILD_$(HSYS_TYPE))
ENSCONF		= $(ENSCONF_$(HSYS_TYPE)) 
ENSCONFDEP      = $(ENSCONFDEP_$(HSYS_TYPE))

#*************************************************************#
# OCAML_LIB should point to the library directory.  For
# Unix, OCAML_LIB is only necessary for the socket library
# and the C interface.  By default, it is set to the value
# of the environment variable CAMLLIB, which normally is set
# to the O'Caml library directory.  It is usually preferable
# to set OCAML_LIB indirectly through the CAMLLIB
# environment variable.  Be careful, $(OCAML_LIB)/caml needs
# to identify the correct location of the config.h header
# file.  A copy may also be found in ocaml/byterun, but you
# do not want to use that version, because it may be
# inconsistent with the installation you are using.

OCAML_LIB	= $(CAMLLIB)

#*************************************************************#
# Uncomment this definition if you want to use the raw ethernet
# transport.  This is only supported on Linux platforms which
# are configured with the packet sockets (CONFIG_PACKET).

ETH_CFLAGS	= # -DRAW_ETH

#*************************************************************#
# A bunch of configuration macros to support both NT and Unix

EXE	=
OBJS	= .o
ARCS	= .a
OBJ	= $(OBJS)
ARC	= $(ARCS)
CP	= cp
MV	= mv
LN	= ln
RM	= rm -f
MAKE	= make	
MKLIB   = ar cr 		# comment forces spaces
MKLIBO  =
RANLIB  = ranlib
SUBMAKE = ; $(MAKE)
DEPEND  = .depend
PARTIALLD = ld $(CODEGEN) -r
PARTIALLDO = -o
ECHO	= echo
STRIP   = strip
MKDIR   = mkdir -p
RMDIR   = rm -rf
CHMODR  = chmod +r
#*************************************************************#
NTRULE	= #-unix
UNIXRULE =
#*************************************************************#
# How to link various Ocaml libraries.  Should not require
# modification.
LIBCUNIX	= -lunix
LIBMLUNIX	= unix$(CMAS)
LIBCSOCK	= $(ENSLIB)/libsock$(ARC)
LIBMLSOCK	= $(ENSLIB)/socket$(CMA)
LIBCTHREADS	= -lthreads
LIBMLTHREADS	= threads$(CMAS)
LIBCSTR		= -lstr
LIBMLSTR	= str$(CMAS)
LIBMLSTRBC	= str.cma

LIBTK		= tk41$(CMAS) $(TKLIBS)
#*************************************************************#
# Select whether or not to use Ocaml threads.  Ocaml threads
# only work with bytecode interpreter.  Default is no
# threads.  COMP_THR is the option needed for the
# compilation step.  LINK_THR is the option needed for the
# link step.  To use threads, you need to recompile Ensemble
# from scratch in the def directory (run make clean ; make
# depend ; make).

# No threads
COMP_THR	= # no threads
LINK_THR	= # no threads

# Use threads
#COMP_THR	= -thread
#LINK_THR	= -thread $(LIBTHREADS)

#*************************************************************#
# Root of the Ensemble distribution.  Used to find source files
# when using dynamicly linked ML files.

ENSROOT_ABS	= /usr/u/hayden/ensemble

#*************************************************************#
# Where to find ATM/UNET header files and libraries.  By
# default, these are not compiled with the distribution, so 
# you shouldn't need to adjust them.

# for Cornell CS Dept
LIBUNET		= /usr/u/sww/sun4/lib/libunet-2$(ARCS)
INCUNET		= -I/usr/u/sww/linux/include/unet-2

#*************************************************************#
# MPI header files

INCMPI		= #-I/usr/local/mpi/include

#*************************************************************#
# Configuration infromation for threads and the C interfaces.

# SPARC-SOLARIS
HOT_CFLAGS_sparc-solaris = -DTHREADED_SELECT
HOT_MLLINK_sparc-solaris = # empty
HOT_LINK_sparc-solaris  = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -ldl
#HOT_THREAD_OBJ_sparc-solaris = pthread_intf$(OBJ)
HOT_THREAD_OBJ_sparc-solaris = solaris_thread$(OBJ)


# I386-SOLARIS: same as for sparc-solaris
HOT_CFLAGS_i386-solaris = $(HOT_CFLAGS_sparc-solaris)
HOT_MLLINK_i386-solaris = # empty
HOT_LINK_i386-solaris = -lthread -lposix4 -ltermcap -lsocket -lnsl -lm -ldl
HOT_THREAD_OBJ_i386-solaris = $(HOT_THREAD_OBJ_sparc-solaris)

# I386-LINUX
# The -D_RENTRANT is needed for the use of threads
HOT_CFLAGS_i386-linux	= -DTHREADED_SELECT -DUSE_PTHREAD_SEMAPHORE -DUSE_PTHREAD_LOCK -D_REENTRANT -DLINUX_THREADS
HOT_MLLINK_i386-linux	= # empty
HOT_LINK_i386-linux	= -lpthread -ltermcap -lm
HOT_THREAD_OBJ_i386-linux = pthread_intf$(OBJ)

# I486-LINUX same as for i386
HOT_CFLAGS_i486-linux	= $(HOT_CFLAGS_i386-linux)
HOT_MLLINK_i486-linux	= $(HOT_MLLINK_i386-linux)
HOT_LINK_i486-linux	= $(HOT_LINK_i386-linux)
HOT_THREAD_OBJ_i486-linux = $(HOT_THREAD_OBJ_i386-linux)

# ALPHA-OSF1
HOT_CFLAGS_alpha-osf1	= -DOSF1_THREADS
HOT_MLLINK_alpha-osf1	=
HOT_LINK_alpha-osf1	= -lrt -lpthreads -lmach -lexc -lc_r -lm -ltermcap -taso
HOT_THREAD_OBJ_alpha-osf1 = pthread_intf$(OBJ)

# RS6000-AIX
HOT_CFLAGS_rs6000-aix	= -DOSF1_THREADS
HOT_MLLINK_rs6000-aix	= # empty
HOT_LINK_rs6000-aix	= -lpthreads -lm -ltermcap
HOT_THREAD_OBJ_rs6000-aix = pthread_intf$(OBJ)

# HP9000-HPUX
HOT_CFLAGS_hp9000-hpux	= -DINLINE_PRAGMA
HOT_MLLINK_hp9000-hpux	= # empty
HOT_LINK_hp9000-hpux	=
HOT_THREAD_OBJ_hp9000-hpux = pthread_intf$(OBJ)

# MIPS-IRIX64
HOT_CFLAGS_mips-irix64 = -DINLINE_PRAGMA -DTHREADED_SELECT
HOT_MLLINK_mips-irix64 = # empty
HOT_LINK_mips-irix64 = -lpthread -ltermcap -lm
HOT_THREAD_OBJ_mips-irix64 = pthread_intf$(OBJ)

GTHREADS	= $(GTHREADS_$(PLATFORM))
HOT_CFLAGS	= $(HOT_CFLAGS_$(PLATFORM))
HOT_MLLINK	= $(HOT_MLLINK_$(PLATFORM))
HOT_LINK	= $(HOT_LINK_$(PLATFORM))
HOT_THREAD_OBJ	= $(HOT_THREAD_OBJ_$(PLATFORM))

#*************************************************************#
# Purify options

PURIFY_HOME_sparc-solaris = /opts/pure/purify-4.0.1-solaris2
PURIFY_HOME = $(PURIFY_HOME_$(PLATFORM))
PURIFY_CFLAGS = $(PURIFY_CFLAGS_$(PLATFORM))

PURIFY_sparc-solaris = 	$(PURIFY_HOME)/purify 			\
			-cache-dir=/usr/u/alexey/tmp 		\
			-threads=yes 				\
			-chain-length=15			\
			-windows=yes
PURIFY_CFLAGS_sparc-solaris = -I $(PURIFY_HOME)

PURIFY_LIB 	= $(PURIFY_HOME)/purify_stubs.a
PURIFY 		= $(PURIFY_$(PLATFORM))

#*************************************************************#
