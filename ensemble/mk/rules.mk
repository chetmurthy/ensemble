# -*- Mode: makefile -*-
#*************************************************************#
#
# FILES: common rules for making the C and ML files
#
# Author: Ohad Rodeh, 10/2002
#
#*************************************************************#

.SUFFIXES: .cmo .cmx .cmi .ml .mli .c .o .obj
.mli.cmi:
	ocamlc $(INCLUDE) -c $<
.ml.cmo:
	ocamlc $(MLFLAGS) $(INCLUDE) -c $<
.ml.cmx: 
	ocamlopt $(MLFLAGS) $(INCLUDE) -c $<
.c.o:
	$(CC) -c $(CFLAGS)  $(C_ADD_FLAGS) $< -o $@
.c.obj:
	$(CC) -c $(CFLAGS)  $(C_ADD_FLAGS) $< $(OBJRULE)$@

#  The new version
#
#
#OBJDIR = $(ENSROOT)\obj
#
#.SUFFIXES: .cmo .cmx .cmi .ml .mli .c .o .obj
#.mli.cmi:
#	ocamlc $(INCLUDE) -c $< -o $(OBJDIR)\$(@F)
#.ml.cmo:
#	ocamlc $(MLFLAGS) $(INCLUDE) -c $< -o $(OBJDIR)\$(@F)
#.ml.cmx: 
#	ocamlopt $(MLFLAGS) $(INCLUDE) -c $< -o $(OBJDIR)\$(@F)
#.c.obj:
#	$(CC) -c $(CFLAGS) $< /Fo$(OBJDIR)\$(@F)

