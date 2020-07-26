#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
CC = javac

.SUFFIXES: .java .class
.java.class:
	javac $<

CLASSFILES= \
	ensemble/hot/Hot_Buffer.class \
	ensemble/hot/Hot_Callbacks.class \
	ensemble/hot/Hot_Endpoint.class \
	ensemble/hot/Hot_Ensemble.class \
	ensemble/hot/Hot_Error.class \
	ensemble/hot/Hot_GroupContext.class \
	ensemble/hot/Hot_JoinOps.class \
	ensemble/hot/Hot_Message.class \
	ensemble/hot/Hot_ViewID.class \
	ensemble/hot/Hot_ViewState.class \
	ensemble/hot/Hot_ObjectMessage.class \
	ensemble/hot/Hot_IO_Controller.class

all: $(CLASSFILES) EnsDemoOutboard.class
	chmod +x EnsDemoOutboard.class
	cp ../demo/outboard .

clean:
	rm -rf ensemble/hot/*.class *.class
