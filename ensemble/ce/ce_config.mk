MLFLAGS = #-p
CFLAGS = -O2 #-p

CE_LINK_FLAGS_i386-linux = -ltermcap -lm
CE_LINK_FLAGS_sparc-solaris = -lposix4 -ltermcap -lsocket -lnsl -lm -ldl

CE_LINK_FLAGS = $(CE_LINK_FLAGS_$(PLATFORM))

