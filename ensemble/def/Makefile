#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/config.mk
#*************************************************************#
all: main_all install
	cd ../demo $(SUBMAKE)
#*************************************************************#
include $(ENSROOT)/mk/preamble.mk
include $(ENSROOT)/mk/ocaml.mk
include $(ENSROOT)/mk/files.mk
include $(ENSROOT)/mk/main.mk
include $(ENSROOT)/mk/tools.mk
include $(ENSROOT)/mk/install.mk
include $(ENSROOT)/mk/dynlink.mk
include $(DEPEND)
#*************************************************************#
