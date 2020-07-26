#*************************************************************#
#
# Main CEJAVA Makefile
#
# Author: Ohad Rodeh 7/2002
#
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/cejava/cejava.mk
#*************************************************************#

# Java 2 SDK (1.2 or 1.3 should do)
J2SDK = $(JAVA_HOME)

CEINCLUDE= -I $(ENSROOT)/lib/$(PLATFORM)

all: compileClasses generateHeader compileJni buildLibrary rand #buildDocumentation

compileClasses: 
	javac -d classes View.java JoinOps.java Callbacks.java Group.java 

rand : 
	javac -classpath classes RandTest.java

generateHeader:
	javah -classpath classes ensemble.Group

compileJni:
	$(CC) -c  -I . -I $(J2SDK)/include -I $(J2SDK)/include/$(J2SDK_PLATFORM) $(CEINCLUDE) ensemble_Ce.c

buildLibrary:
	$(MKSHRLIB) $(MKSHRLIBO)libcejava$(SO) ensemble_Ce$(OBJS) ../ce/libce_mt.so #$(ARCS)
	mv -f libcejava.so lib/

buildDocumentation:
	$(J2SDK)/bin/javadoc -public -classpath classes -d javadoc Callbacks.java JoinOps.java Group.java View.java

clean:
	rm -fr ensemble_Ce.h ensemble_Ce.o javadoc/* classes/* lib/*
	rm -f hs_err* core* *class *.o *.obj

demo:
	$(J2SDK)/bin/java  -Djava.class.path=.:classes -Djava.library.path=lib RandTest  "-n" "5" "-t" "5" 

#"-trace" "CE_INBOARD" "-ctrace" "CE_INBOARD_C" "-ctrace" "CE_INBOARD_MT"



#	$(J2SDK)/bin/java -Djava.class.path=classes -Djava.library.path=lib ensemble.Group "Group A" "Group B"

