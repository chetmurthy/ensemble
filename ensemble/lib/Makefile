#*************************************************************#
#
#   Ensemble, 1.10
#   Copyright 2001 Cornell University, Hebrew University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk


clean::
	$(RM) *.h *.mli
	$(RMDIR) $(ENSLIB)

# Don't know what platforms are built, so 
# only attempt to remove the supported platforms
# Users can add there own here if desired

realclean:	clean
	$(RMDIR) nt
	$(RMDIR) i386-linux
	$(RMDIR) sparc-sunos4
	$(RMDIR) sparc-solaris

