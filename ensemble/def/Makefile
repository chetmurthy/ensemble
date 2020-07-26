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
DIR = def
#*************************************************************#
all: main_all install
	cd ../demo $(SUBMAKE)
#*************************************************************#
include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/ocaml.mk
include $(ENSROOT)/mk/files.mk
include $(ENSROOT)/mk/main.mk
include $(ENSROOT)/mk/tools.mk
include $(ENSROOT)/mk/install.mk
include $(ENSROOT)/mk/cross.mk
include $(ENSROOT)/mk/dynlink.mk
include $(DEPEND)
#*************************************************************#
