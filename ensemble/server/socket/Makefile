#*************************************************************#
#
# MAKEFILE: socket library 
#
# Author: Ohad Rodeh  10/2002
#
#*************************************************************#
ENSROOT = ../..

include $(ENSROOT)/mk/config.mk
include $(ENSROOT)/mk/preamble.mk

#*************************************************************#
# Set the include paths, and include the make rules
#
INCLUDE = -I s -I s/$(KIND)
C_ADD_FLAGS = -I s -I s/$(KIND)

include $(ENSROOT)/mk/rules.mk
#*************************************************************#
# Choose whether to use the optimizing compiler or not.
#
ifdef OPT
include $(ENSROOT)/mk/ocamlopt.mk
else
include $(ENSROOT)/mk/ocaml.mk
endif
#*************************************************************#

USOCKOBJ = \
	socksupp$(CMO)	\
	u/socket$(CMO)

SSOCKOBJ = \
	socksupp$(CMO)	\
	s/ciovec$(CMO)	\
	s/common_impl$(CMO)	\
	s/$(KIND)/comm_impl$(CMO)\
	s/socket$(CMO)

SOCKCOBJ = \
	s/mm$(OBJ) \
	s/skt_utils$(OBJ) \
	s/md5c$(OBJ)	\
	s/$(KIND)/sendrecv$(OBJ)	\
	s/$(KIND)/gettimeofday$(OBJ) 	\
	s/$(KIND)/miscsupp$(OBJ)	\
	s/$(KIND)/multicasts$(OBJ) 	\
	s/$(KIND)/sockfd$(OBJ) 		\
	s/$(KIND)/sockopt$(OBJ) 	\
	s/$(KIND)/select$(OBJ) 


H_FILES = \
	$(ENSLIB)/socket$(CMI) 

#*************************************************************#

all : \
	$(ENSLIB)/usocket$(CMA) \
	$(ENSLIB)/ssocket$(CMA) \
	$(ENSLIB)/libsock$(ARC) \
	u/socket$(CMI) \
	s/socket$(CMI) \
	socket$(CMI) \
	$(H_FILES)

# Call ourselves with the optimizing compiler switch
#
opt : 
	$(MAKE) OPT=yes all


clean : 
	$(RM) s/socket.mli u/socket.mli
	$(CLEANDIR)

#*************************************************************#
# Actual rules for making the libraries
#
$(ENSLIB)/socket$(CMI) : u/socket$(CMI)
	$(CP) u/socket$(CMI) $(ENSLIB)/socket$(CMI)

u/socket.mli : socket.mli
	$(CP) socket.mli u/

s/socket.mli : socket.mli
	$(CP) socket.mli s/

$(ENSLIB)/usocket$(CMA) : socksupp$(CMI) u/socket.mli socket$(CMI) u/socket$(CMI) $(USOCKOBJ) 
	$(MLLIBR) -o $(ENSLIB)/usocket$(CMA) -linkall $(USOCKOBJ)

$(ENSLIB)/ssocket$(CMA) :  socksupp$(CMI) s/ciovec$(CMI) s/socket.mli socket$(CMI) s/socket$(CMI) $(SSOCKOBJ) 
	$(MLLIBR) -o $(ENSLIB)/ssocket$(CMA) -linkall $(SSOCKOBJ)

$(ENSLIB)/libsock$(ARC): $(SOCKCOBJ)
	$(MKLIB) $(MKLIBO)$(ENSLIB)/libsock$(ARC) $(SOCKCOBJ)
ifneq ("$(PLATFORM)" , "powerpc-darwin")
	$(RANLIB) $(ENSLIB)/libsock$(ARC)
endif

#*************************************************************#
# Dependencies
#
depend : 
	ocamldep -I u -I s -I s/$(KIND) \
	*.ml *.mli u/*.ml  u/*.mli s/*.ml s/*.mli \
	s/$(KIND)/*.ml s/$(KIND)/*.mli	> $(DEPEND)

include $(DEPEND)

#*************************************************************#
