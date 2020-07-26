#*************************************************************#
# MAKEFILE: tools Makefile
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/config.mk
#*************************************************************#

all : \
	$(ENSBIN)/$(EMRG)

$(ENSBIN)/$(EMRG): 
	ocamlc -c emrg.ml 
	ocamlc -o $(ENSBIN)/$(EMRG) emrg.cmo

clean : 
	$(RM) *.cm*

realclean : clean
#*************************************************************#