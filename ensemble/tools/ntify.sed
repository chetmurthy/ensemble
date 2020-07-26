s:^include Makefile.base:!include Makefile.base.nt:g
s:Makefile.opt:Makefile.opt.nt:g
s:^include *\(.*\).mk:!include \1.nmk:g
s:^include \$(DEPEND):!include $(DEPEND):g
s:/:\\:g
s:-o \(\$(OBJD).*\$(OBJ)\):/Fo\1 :g
s:\$(PARTIALLDO) :\$(PARTIALLDO):g
s:;:\&:g
s:[ 	]*\\$:\\:g
s:ecamlc :ecamlc.exe :g
s:\<make\>:nmake -f Makefile.nt:g
