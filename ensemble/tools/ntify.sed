s:Makefile.top:Makefile.top.nt:g
s:^include *\(.*\).mk:!include \1.nmk:g
s:^include \$(DEPEND):!include $(DEPEND):g
s:^include \$(ENSROOT)/\$(DEPEND):!include $(ENSROOT)\\$(DEPEND):g
s:/:\\:g
s:\$(PARTIALLDO) :\$(PARTIALLDO):g
s:;:\&:g
s:[ 	]*\\$:\\:g
s:\<make\>:nmake -f Makefile.nt:g
s:ifdef:!ifdef:g
s:ifndef:!ifndef:g
s:else:!else:g
s:elif:!elif:g
s:endif:!endif:g
s:ifeq (\(.*\) , \(.*\)):!if \1 == \2:g

