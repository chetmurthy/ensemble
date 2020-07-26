#*************************************************************#
#
#   Ensemble, 1.10
#   Copyright 2001 Cornell University, Hebrew University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# Makefile for Maestro

MAKE            = make
ROOT            = .
CONF		= conf
PLATFORM        = $(ENS_MACHTYPE)-$(ENS_OSTYPE)
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

