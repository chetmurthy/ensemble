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
