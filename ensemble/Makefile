#*************************************************************#
#
#   Ensemble, 1_42
#   Copyright 2003 Cornell University, Hebrew University
#           IBM Israel Science and Technology
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
#
# Makefile: root Ensemble Makefile
#
# Author: Ohad Rodeh  12/2001
# Based on code by Mark Hayden
#
#*************************************************************#

.PHONY: socket tar hot ce maestro tools doc

include mk/config.mk
include mk/preamble.mk

SUBDIRS = \
	appl		\
	ce		\
	cs		\
	cejava		\
	crypto		\
	demo		\
	demo/tk		\
	demo/life	\
	demo/dbm	\
	doc		\
	ejava		\
	groupd		\
	hot		\
	hot/include	\
	infr		\
	layers		\
	layers/bypass	\
	layers/debug	\
	layers/flow	\
	layers/total	\
	layers/vsync	\
	layers/other	\
	layers/trans	\
	layers/gossip	\
	layers/scale	\
	layers/security	\
	maestro		\
	mk		\
	mm		\
	route		\
	socket		\
	socket/u	\
	socket/s	\
	socket/s/unix	\
	socket/s/nt	\
	tar		\
	tools		\
	trans		\
	type		\
	util	

# Make everything from scratch
# 
all : dirs
	cd socket ; $(MAKE) all 
	$(MAKE_BASE) -f Makefile.top all
	cd demo ; $(MAKE) 
	cd ce ; $(MAKE)	
	cd hot ; $(MAKE) 
	cd maestro ; $(MAKE) 

# Make sure the target directories are in place
#
dirs : 
	$(MKDIR) bin
	$(MKDIR) lib
	$(MKDIR) bin/$(PLATFORM)
	$(MKDIR) lib/$(PLATFORM)

maestro : 
	cd maestro ; $(MAKE) all

sock : dirs
	cd socket; $(MAKE) all

just: dirs
	cd socket ; $(MAKE) all 
	$(MAKE_BASE) -f Makefile.top all
	cd demo ; $(MAKE) 

# Make the optimized versions
opt: dirs
	cd socket ; $(MAKE) opt 
	$(MAKE_BASE) -f Makefile.top opt
	cd demo ; 	$(MAKE) opt 
	cd ce ; $(MAKE) opt 
	cd hot ; $(MAKE) opt 
	cd maestro ; $(MAKE) 

# Make the java JNI API. This has been separated out from the main 'make' because
# not all OSes have Java.
#
cejava : 
	cd cejava ; $(MAKE) ; $(MAKE) install

crypto : 
	cd crypto ; $(MAKE) ; $(MAKE) install 

crypto_opt : 
	cd crypto ; $(MAKE) opt ; $(MAKE) install 

tk :
	$(MAKE_BASE) -f Makefile.top tk

tk_opt :
	$(MAKE_BASE) -f Makefile.top OPT=yes tk


everything : all cejava

touch_depend : 
	touch .depend .depend.nt
	touch socket/.depend socket/.depend.nt
	touch ce/.depend ce/.depend.nt
	touch cejava/.depend ce/.depend.nt
	touch hot/.depend hot/.depend.nt
	touch demo/.depend demo/.depend.nt
	touch demo/dbm/.depend demo/dbm/.depend.nt
	touch demo/life/.depend demo/life/.depend.nt
	touch demo/tk/.depend demo/tk/.depend.nt


dos2unix : 
	make touch_depend
	dos2unix tar/{copyright*,tarcr,tarcheck}
	dos2unix Makefile* */Makefile* */*/Makefile*
	dos2unix .cvsignore */.cvsignore */*/.cvsignore */*/*/.cvsignore
	dos2unix */*.[chC] */*/*.[chC] */*/*/*.[chC]
	dos2unix */*.tex */*/*.tex
	dos2unix */*.java
	dos2unix */*.ml* */*/*.ml* */*/*/*.ml* 
	dos2unix */*.mk 
	tools/ntify.sh

# build a tar file containing the source only.
#
src: dos2unix
	make realclean
	make depend
	cd tar; tcsh tarcr $(VERSION) /home/orodeh/e/1.42/ensemble 

doc : 
	cd doc; $(MAKE) all; $(MAKE) build

# build a tar file containing executables and libraries.
#
dist : 
	cd ../build; for d in *; do (tar -cf ensemble-$VERSION-$$d.tar $$d; gzip ensemble-1_42-$$d.tar; rm -rf $$d); done


depend:
	cd socket; $(MAKE) depend
	cd socket; $(MAKE) depend
	cd ce; $(MAKE) depend
	cd cejava; $(MAKE) depend
	cd hot; $(MAKE) depend
	cd demo; $(MAKE) depend
	cd maestro; $(MAKE) depend
	$(MAKE_BASE) -f Makefile.top depend

# This gets around a difference between NMAKE and MAKE. 
#
ifeq ("$(PLATFORM)" , "nt")
ENS_ABSROOT = $(MAKEDIR)
CLEANALL = for %%d in ($(SUBDIRS)) do (cd %%d & $(MAKE) clean & cd $(ENS_ABSROOT))
else
CLEANALL = for d in $(SUBDIRS); do (cd $$d; $(MAKE) -k clean); done
endif

# MH: note 'make clean' should clean the def and opt
# directories.  It only leaves libraries, executables, 
# and postscript documents. 
clean: 
	$(CLEANALL)
	$(CLEANDIR)
	$(RM) ensemble.ml ensemble.mli emrg* 
	$(RM) .unknown


# realclean clean
#
realclean: clean 
	$(RMDIR) bin
	$(RMDIR) lib
	cd maestro ; 	$(MAKE) realclean 
	cd doc ; 	$(MAKE) realclean 


#*************************************************************#
# Get a breakdown of size of the ML/C/Latex sources

wc:
	@ echo "Core code:"
	  cat util/*.{ml,mli} | wc -l -
	  cat mm/*.{ml,mli} | wc -l -
	  cat type/*.{ml,mli} | wc -l -
	  cat route/*.{ml,mli} | wc -l -
	  cat appl/*.{ml,mli} | wc -l -
	  cat infr/*.{ml,mli} | wc -l -
	  cat trans/*.{ml,mli} | wc -l -
	  cat layers/*/*.ml | wc -l -

old_wc:
	@ wc -l \
	  util/*.ml	\
	  mm/*.ml	\
	  type/*.ml	\
	  appl/*.ml	\
	  infr/*.ml	\
	  route/*.ml	\
	  trans/*.ml	\
	  layers/*/*.ml		\
	@ echo "ML code:"
	@ wc -l \
	  util/*.ml	util/*.mli	\
	  mm/*.ml	mm/*.mli	\
	  mm/*.ml	mm/*.mli	\
	  type/*.ml	type/*.mli	\
	  appl/*.ml	appl/*.mli	\
	  groupd/*.ml   groupd/*.mli \
	  layers/*/*.ml		\
	  socket/*.ml	socket/*.mli	\
	  trans/*.ml	trans/*.mli	\
	  demo/*.ml			\
	  demo/tk/*.ml			\
	  demo/life/*.ml demo/life/*.mli 
	@ echo
	@ echo "C code:"
	@ wc \
	  socket/*/*.[ch] socket/*/*/*.[ch]
	@ echo
	@ echo "Latex Documentation"
	@ wc doc/*.tex doc/layers/*.tex


nfiles:
	@ ls $(SRCS) mk/* | wc

#*************************************************************#


