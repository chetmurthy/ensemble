#*************************************************************#
ENSROOT = ..
include $(ENSROOT)/mk/config.mk

#*************************************************************#
all: main_all install socket
	cd ../demo $(SUBMAKE) socketopt
#*************************************************************#

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
