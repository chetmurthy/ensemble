#*************************************************************#
#
# Makefile: root Ensemble Makefile
#
# Author: Ohad Rodeh  12/2001
# Based on code by Mark Hayden
#
#*************************************************************#

.PHONY: socket tar tools doc

#*************************************************************#
ENSROOT=.
include mk/config.mk
include mk/preamble.mk
#*************************************************************#

# Make everything from scratch
# 
all : dirs
	cd tools; $(MAKE) all
	cd server; $(MAKE) all
	cd client; $(MAKE) all

tests : all
	cd server; $(MAKE) tests
	cd client; $(MAKE) tests

# Make sure the target directories are in place
#
dirs : 
	$(MKDIR) bin
	$(MKDIR) lib
	$(MKDIR) bin/$(PLATFORM)
	$(MKDIR) lib/$(PLATFORM)

# Make the optimized versions
opt: dirs
	$(MAKE) OPT=1 all

dos2unix : 
	make touch_depend
	dos2unix tar/{copyright*,tarcr,tarcheck}
	dos2unix Makefile* */Makefile* */*/Makefile* */*/*/Makefile*
	dos2unix .cvsignore */.cvsignore */*/.cvsignore */*/*/.cvsignore
	dos2unix */*.[chC] */*/*.[chC] */*/*/*.[chC] */*/*/*/*.[chC]
	dos2unix */*.tex */*/*.tex
	dos2unix client/java/*.java client/java/*/*.java
	dos2unix */*.ml* */*/*.ml* */*/*/*.ml* */*/*/*/*.ml* 
	dos2unix mk/*.mk client/*/*.mk 
	tools/ntify.sh

# build a tar file containing the source only.
#
src: dos2unix
	make touch_depend
	make depend
	make realclean
	cd tar; tcsh tarcr $(VERSION) /home/orodeh/e/$(VERSION_DIR)/ensemble 

doc : 
	cd doc; $(MAKE) all; $(MAKE) build

# build a tar file containing executables and libraries.
#
dist : 
	tar -cf ../ensemble-2_00-i386_linux.tar bin/i386-linux lib/i386-linux
	gzip ../ensemble-2_00-i386_linux.tar
	zip -rp ../ensemble-2_00-nt.zip bin/nt lib/nt


touch_depend : 
	touch server/.depend server/.depend.nt 
	touch server/prog/.depend server/prog/.depend.nt
	touch server/socket/.depend server/socket/.depend.nt

depend: 
	cd server; $(MAKE) depend
	cd client; $(MAKE) depend

# Note 'make clean' cleans all object files. It 
# It leaves libraries, executables, and PDF documents. 
clean: 
	cd server; $(MAKE) clean 
	cd client; $(MAKE) clean 
	cd tools; $(MAKE) clean
	cd tests; $(MAKE) clean

# realclean clean
#
realclean: clean 
	$(RMDIR) bin
	$(RMDIR) lib
	cd doc ; $(MAKE) realclean 

#*************************************************************#
# Get a breakdown of size of the ML/C/Latex sources

wc:
	@ echo "Server ML code:"
	  cat server/*/*.{ml,mli} server/*/*/*.{ml,mli} server/*/*/*/*.ml | wc -l -
	@ echo "Server C code:"
	  cat server/*/*/*.[ch] server/*/*/*/*.[ch] | wc -l -
	@ echo "C-client code"
	  cat client/c/*.[ch] | wc -l -
	@ echo "Java-client code"
	  cat client/java/*.java client/java/*/*.java | wc -l -
	@ echo "C-sharp client code"
	  cat client/cs/ENS/*/*.cs | wc -l -
	@ echo "Latex Documentation"
	  cat doc/*.tex doc/layers/*.tex | wc -l -

nfiles:
	@ ls $(SRCS) mk/* | wc

#*************************************************************#


