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
ENSROOT = ..
include $(ENSROOT)/mk/config.mk

.SUFFIXES: .java .class
.java.class:
	javac $<

all: EnsDemoOutboard.class
	$(CP) $(ENSROOT)/bin/$(PLATFORM)/outboard$(EXE) .
	javac ensemble/hot/*.java
	chmod +x EnsDemoOutboard.class

clean:
	rm -rf ensemble/hot/*.class *.class 

doc : 
	mkdir -p docs
	javadoc ensemble/hot/*.java -d docs
