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

# The type of system we are running on

# The type of system we are running on
#
KIND = unix

# C compiler to use
CC	= gcc

#*************************************************************#

# CFLAGS: used for compilation of C files
CFLAGS	=-DINLINE=inline \
	-O2 -Wall -Wno-unused -Wstrict-prototypes -DNDEBUG \
        $(CODEGEN)                      \
	-I $(OCAML_LIB)			\
	$(OPENSSL_INC) 

# -DNDEBUG -O2
#
#-g -p/-pg 
#	-DOSTYPE=$(ENS_OSTYPE)		
#	-DMACHTYPE=$(ENS_MACHTYPE)	


# LIBSYS: used for linking executables
LIBSYS	= # default for Unix is nothing

# SHELL to use for processing these makefiles must be /bin/sh
SHELL = /bin/sh





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

# The binary and library directories
#
ENSLIB = $(ENSROOT)/lib/$(PLATFORM)
ENSBIN = $(ENSROOT)/bin/$(PLATFORM)

#*************************************************************#
# The default cryptographic library. We use OpenSSL
# that compiles and runs on many different platforms. 

CRYPTO_LINK = # no crypto by default

# Where to find the OpenSSL cryptographic library. 
#OPENSSL_LIB = /usr/lib/libssl.so.0.9.6
#OPENSSL_INC = -I /usr/include/openssl
#
#
#CRYPTOLIB_ML = \
#	$(ENSLIB)/crypto$(CMA)	
#CRYPTOLIB_C = \
#	$(ENSLIB)/libcryptoc$(ARC) \
#	$(OPENSSL_LIB)
#CRYPTOLIB_JUST_C = \
#	$(OPENSSL_LIB)
#
#CRYPTO_LINK = \
#	-cclib $(ENSLIB)/libcryptoc$(ARC) \
#	-cclib $(OPENSSL_LIB) \
#	$(CRYPTOLIB_ML) 


#*************************************************************#
# FOR INITIAL CONFIGURATION, NOTHING BELOW HERE SHOULD NEED TO
# BE EDITED.
#*************************************************************#

#*************************************************************#
# There are 3 levels of libraries to use.  The core library
# contains the minimal Ensemble library.  There is not enough
# included to run any protocol stacks, so additional modules
# need to be linked.
#
# The min library includes a minimal set of layers and other
# stuff that can be used to run the default Ensemble protocol
# stack and a a total ordering layer for using totally ordered
# layers.  The full library contains everything not in the
# previous two libraries.  The macro ENSLIBS_TYPE is used to
# switch betwen these different configurations.  The default
# value is "full", which is the safest (although largest)
# version.

# 'min' or 'full'
# !NOTE! make sure there are no trailing spaces on the next line
ENSLIBS_TYPE = full

ENSLIBS_min  = $(ENSCORELIB) $(ENSMINLIB)
ENSLIBS_full = $(ENSLIBS_min) $(ENSRESTLIB)

ENSLIBS_DEP	= $(ENSLIBS_$(ENSLIBS_TYPE))
ENSLIBS		= $(ENSLIBS_DEP)



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
ENSCONFDEP_skt	= $(LIBSOCKDEP) $(ENSLIBS_DEP)
ENSCONF_skt	= $(CUSTOM) $(LIBUNIX) $(LIBSOCK) $(LINK_THR) $(ENSLIBS) $(CRYPTO_LINK)

# Unix library
ENSCONFDEP_unix	= $(LINKTHR) $(LIBUSOCK) $(ENSLIBS_DEP)
ENSCONF_unix    = $(CUSTOM) $(LIBUNIX) $(LIBUSOCK) $(LINK_THR) $(ENSLIBS) $(CRYPTO_LINK)

ENSCONFDEP      = $(ENSCONFDEP_$(HSYS_TYPE))
ENSCONF		= $(ENSCONF_$(HSYS_TYPE)) 

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
C_LINK = 
#*************************************************************#
# A bunch of configuration macros to support both NT and Unix

EXE	=
OBJS	= .o
ARCS	= .a
OBJ	= $(OBJS)
ARC	= $(ARCS)
CP	= cp -f
MV	= mv
LN	= ln
RM	= rm -f
MAKE	= gmake	
MAKE_BASE = gmake	
MKLIB   = ar cr 		# comment forces spaces
RANLIB  = ranlib
MKLIBO  =
#*************************************************************#
## Shared libraryies

MKSHRLIB   = ld -shared
MKSHRLIBO   = -o #comment forces a space
SO = .so
#*************************************************************#
SUBMAKE = ; $(MAKE)
DEPEND  = .depend
PARTIALLD = ld $(CODEGEN) -r
PARTIALLDO = -o
OBJRULE = -o
ECHO	= echo
STRIP   = strip
MKDIR   = mkdir -p
RMDIR   = rm -rf
CHMODR  = chmod +r
#*************************************************************#
# How to link various Ocaml libraries.  Should not require
# modification.
LIBCUNIX	= -lunix
LIBMLUNIX	= unix$(CMAS)
LIBCSOCK	= $(ENSLIB)/libsock$(ARC)
LIBMLSOCK	= $(ENSLIB)/ssocket$(CMA)
LIBSOCK		= $(LIBMLSOCK) -cclib $(LIBCSOCK) 
LIBCTHREADS	= -lthreads
LIBMLTHREADS	= threads$(CMAS)

LIBTK		= $(OCAML_LIB)/labltk/labltk$(CMAS) 
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
# Clean this directory
#
CLEANDIR = \
    $(RM) .nfs* *.cm* .err a.out *.o* *.a *.lib *.asm *~ .*~ .\#*  core *.pdb core gmon.out camlprim*

#*************************************************************#
