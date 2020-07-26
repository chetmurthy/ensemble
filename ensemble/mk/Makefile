#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/sub.mk

MKFILES = mmm dynlink main preamble ocaml ocamlopt install files tools cross
MKDIRS = ../demo ../demo/tk ../demo/life ../def ../opt

nmk:
	@set +e; set -x; for f in $(MKFILES) ; do \
	  sed -f ../tools/ntify.sed <../mk/$$f.mk >../mk/$$f.nmk ;	\
	 done
	@set +e; set -x; for d in $(MKDIRS) ; do \
	  sed -f ../tools/ntify.sed <$${d}/Makefile >$${d}/Makefile.nt ; \
	  sed -f ../tools/ntify.sed <$${d}/.depend  >$${d}/depend.nt ;	\
	 done

	sed -f ../tools/ntify.sed <../demo/Makefile.base >../demo/Makefile.base.nt
	sed -f ../tools/ntify.sed <../demo/Makefile.opt >../demo/Makefile.opt.nt
	sed -f ../tools/ntify.sed <../lib/Makefile >../lib/Makefile.nt

nmk-clean:
	$(RM) $(MKFILES:%=../mk/%.nmk) $(MKDIRS:%=%/Makefile.nt) $(MKDIRS:%=%/depend.nt)
