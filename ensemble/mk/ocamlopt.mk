# -*- Mode: makefile -*- 
#*************************************************************#
#
# OCAMLOPT: definitions for the native code compiler
#
# Author: Mark Hayden, 2/96
#
#*************************************************************#
MLCOMP		= ocamlopt
MLLINK		= $(MLCOMP)
MLLIBR		= $(MLCOMP) -a
CMI		= .cmi
CMOS		= .cmx
CMAS		= .cmxa
CMO		= $(CMOS)
CMA		= $(CMAS)
#*************************************************************#
COMPTYPE	= opt
MLWARN		=
#MLFAST		= -unsafe -noassert -inline 5
MLFAST		= -unsafe -noassert -compact
PROFILE		= #-p
DEBUGGER	=
MLFLAGS		= $(DEBUGGER) $(MLFAST) $(PROFILE)
MLLINKFLAGS	= $(MLFAST) $(PROFILE)
DEPFLAGS	= -opt
ENSCOMPFLAGS	= -opt $(MLFLAGS)
ENSCOMP		= $(MLCOMP) $(MLFLAGS)
#*************************************************************#
CUSTOM		=# no -custom option for ocamlopt
#*************************************************************#
