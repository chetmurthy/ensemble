#*************************************************************#
#
#   Ensemble, (Version 1.00)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# Makefile for Maestro

MAKE            = make
ROOT            = .
CONF		= conf
PLATFORM        = $(MACHTYPE)-$(OSTYPE)
OBJDIR          = $(CONF)/$(PLATFORM)

all:    $(OBJDIR)
	(cd $(OBJDIR); $(MAKE))

conf:
	if [ ! -d conf ]; then mkdir conf; fi

$(OBJDIR): conf
	if [ ! -d $(OBJDIR) ];                          \
	then                                            \
		mkdir $(OBJDIR);                        \
		ln Makefile.tem $(OBJDIR)/Makefile;	\
		touch $(OBJDIR)/.depend;                \
	fi

clean:	$(OBJDIR)
	(cd $(OBJDIR); $(MAKE) clean)

realclean:	clean
	rm -rf $(OBJDIR)

depend:	$(OBJDIR)
	mkdir -p $(OBJDIR)
	touch $(OBJDIR)/.depend
	(cd $(OBJDIR); $(MAKE) depend)

