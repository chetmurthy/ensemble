#*************************************************************#
#
#   Ensemble, (Version 1.00)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
ENSROOT = ..
DIR = opt
#*************************************************************#
all: main_all install socket
	cd ../demo $(SUBMAKE) socketopt
#*************************************************************#
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/ocamlopt.mk
include $(ENSROOT)/mk/files.mk
include $(ENSROOT)/mk/main.mk
include $(ENSROOT)/mk/tools.mk
include $(ENSROOT)/mk/install.mk
include $(DEPEND)
#*************************************************************#

fast: $(OBJD)/_ssocket$(CMO)
	cp $(OBJD)/_ssocket$(CMO) $(OBJD)/socket.cmx
	-$(RM) $(OBJD)/hsys$(CMO)
