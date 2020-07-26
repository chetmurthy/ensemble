# -*- Mode: makefile -*-
#*************************************************************#
#
# MAIN: primary makefile
#
# Author: Mark Hayden, 3/96
#
#*************************************************************#

.PHONY: all tk install depend clean crypto socket hot_share hoto hoti hot
.SUFFIXES: .gorp # no implicit rules (but some make's need one)

#*************************************************************#

main_all: install $(ENS_OPTIONAL)

# Build support for Atm/Unet
atm: $(OBJD)/libatm$(CMA) $(OBJD)/libcatm$(ARC) $(ECP)
	$(ECPC) -mlext $(OBJD)/libatm -o $(ENSLIB)/libatm
	$(CP) $(OBJD)/libcatm$(ARC) $(ENSLIB)/libcatm$(ARC)

mpi: $(OBJD)/libmpi$(CMA) $(OBJD)/libcmpi$(ARC) $(ECP)
	$(ECPC) -mlext $(OBJD)/libmpi -o $(ENSLIB)/libmpi
	$(CP) $(OBJD)/libcmpi$(ARC) $(ENSLIB)/libcmpi$(ARC)

# Install Ensemble stuff
install: $(OBJD) $(ENSLIB) \
	$(ENSLIB)/libenscore$(CMA) \
	$(ENSLIB)/libensmin$(CMA) \
	$(ENSLIB)/libensrest$(CMA) \
	$(ENSLIB)/_nulldynlink$(CMO) \
	$(ENSLIB)/ensemble$(CMI) \
	$(ENSLIB)/ensemble.mli	\
	$(ENSLIB)/hsys$(CMI)	\
	$(ENSLIB)/hsys.mli	\
	$(ENSLIB)/socket$(CMI)	\
	$(ENSLIB)/socket.mli	\
	$(ENSLIB)/socket$(CMA)	\
	$(ENSLIB)/usocket$(CMA)	\
	$(HSYS_BUILD)

# Install C socket library
socket:	$(OBJD) \
	$(ENSLIB)/socket$(CMA)	\
	$(ENSLIB)/libsock$(ARC)

# Install Tk libraries
tk: $(OBJD) \
	$(ENSLIB)/htk$(CMI)	\
	$(ENSLIB)/htk.mli	\
	$(ENSLIB)/libhtk$(CMA)

# Install RPC library
rpc: $(OBJD) \
	$(ENSLIB)/rpc$(CMI)	\
	$(ENSLIB)/rpc.mli	\
	$(ENSLIB)/librpc$(CMA)

# Install crypto libraries
crypto: $(OBJD) \
	$(ENSLIB)/crypto$(CMA)	\
	$(ENSLIB)/libcryptoc$(ARC)

#*************************************************************#
# A rule for creating the object code directory

obj:
	mkdir obj

$(OBJD):
	$(MKDIR) $(OBJD)

#*************************************************************#
# A rule for creating the library directory

$(ENSLIB):
	mkdir $(ENSLIB)

#*************************************************************#
# Make libraries and global interface files.

$(OBJD)/libenscore$(CMA): $(ENSCOREOBJ)
	$(MLLIBR) -o $(OBJD)/libenscore$(CMA) -linkall $(ENSCOREOBJ)

$(OBJD)/libensmin$(CMA): $(ENSMINOBJ)
	$(MLLIBR) -o $(OBJD)/libensmin$(CMA) -linkall $(ENSMINOBJ)

$(OBJD)/libensrest$(CMA): $(ENSRESTOBJ)
	$(MLLIBR) -o $(OBJD)/libensrest$(CMA) -linkall $(ENSRESTOBJ)

$(OBJD)/libhtk$(CMA): $(OBJD)/htk$(CMO)
	$(MLLIBR) -o $(OBJD)/libhtk$(CMA) -linkall $(OBJD)/htk$(CMO)

$(OBJD)/socket$(CMA): $(SOCKOBJ)
	$(MLLIBR) -o $(OBJD)/socket$(CMA) -linkall $(SOCKOBJ)

$(OBJD)/usocket$(CMA): $(USOCKOBJ)
	$(MLLIBR) -o $(OBJD)/usocket$(CMA) -linkall $(USOCKOBJ)

$(OBJD)/librpc$(CMA): $(RPCOBJ)
	$(MLLIBR) -o $(OBJD)/librpc$(CMA) -linkall $(RPCOBJ)

$(OBJD)/crypto$(CMA): $(CRYPTOOBJ)
	$(MLLIBR) -o $(OBJD)/crypto$(CMA) -linkall $(CRYPTOOBJ)

$(OBJD)/libatm$(CMA): $(ATMOBJ)
	$(MLLIBR) -o $(OBJD)/libatm$(CMA) -linkall $(ATMOBJ)

$(OBJD)/libmpi$(CMA): $(MPIOBJ)
	$(MLLIBR) -o $(OBJD)/libmpi$(CMA) -linkall $(MPIOBJ)

#*************************************************************#
# C libraries

$(OBJD)/libcryptoc$(ARC): $(CRYPTOCOBJ)
	$(MKLIB) $(MKLIBO)$(OBJD)/libcryptoc$(ARC) $(CRYPTOCOBJ)
	$(RANLIB) $(OBJD)/libcryptoc$(ARC)

$(OBJD)/libsock$(ARC): $(SOCKCOBJ)
	$(MKLIB) $(MKLIBO)$(OBJD)/libsock$(ARC) $(SOCKCOBJ)
	$(RANLIB) $(OBJD)/libsock$(ARC)

$(OBJD)/libcatm$(ARC): $(ATMCOBJ) $(ECP)
	$(ECPC) $(LIBUNET) -o $(OBJD)/libcatm$(ARC)
	$(MKLIB) $(MKLIBO)$(OBJD)/libcatm$(ARC) $(ATMCOBJ)
	$(RANLIB) $(OBJD)/libcatm$(ARC)

$(OBJD)/libcmpi$(ARC): $(MPICOBJ) $(ECP)
	$(MKLIB) $(MKLIBO)$(OBJD)/libcmpi$(ARC) $(MPICOBJ)
	$(RANLIB) $(OBJD)/libcmpi$(ARC)

#*************************************************************#
# The obj/ensemble.ml* files are generated from exported .mli
# files

$(OBJD)/ensemble.mli: $(ENSEMBLEMLI) $(EMRG)
	$(EMRGC) -mli $(ENSEMBLEMLI) -o $(OBJD)/ensemble.mli

$(OBJD)/ensemble.ml: $(ENSEMBLEMLI) $(EMRG)
	$(EMRGC) -ml $(ENSEMBLEMLI) -o $(OBJD)/ensemble.ml

$(OBJD)/ensemble$(CMI): $(OBJD)/ensemble.mli $(ECAMLC) $(OBJD)/socket$(CMI) $(ENSEMBLECMI)
	$(ENSCOMP) $(OBJD)/ensemble.mli

$(OBJD)/ensemble$(CMO): $(OBJD)/ensemble.ml $(OBJD)/ensemble$(CMI) $(ENSEMBLECMI) $(ENSEMBLECMO)
		$(ENSCOMP) $(OBJD)/ensemble.ml

#$(OBJD)/ensemble$(CMO): $(OBJD)/ensemble.ml $(OBJD)/ensemble$(CMI) $(ECAMLC) $(OBJD)/socket$(CMI) $(OBJD)/crypto$(CMI)
#	$(ENSCOMP) $(OBJD)/ensemble.ml

$(OBJD)/rpc$(CMI): $(OBJD)/rpc$(CMO)

#$(OBJD)/crcs.ml: $(OBJD) $(ENSOBJ) $(ECRCS)
#	$(ECRCSC) -I . $(OBJD)/*$(CMI) > $(OBJD)/crcs.ml

#$(OBJD)/crcs.ml: $(OBJD) $(LINK_AVAIL) $(ECRCS)
#	$(ECRCSC) $(LINK_AVAIL) > $(OBJD)/.crcs.ml
#	$(ECPC) $(OBJD)/.crcs.ml -o $(OBJD)/crcs.ml 

#$(OBJD)/crcs$(CMO) : $(OBJD)/crcs.ml $(ECAMLC) 
#	$(ENSCOMP) $(OBJD)/crcs.ml

# an additional dependency for linker and crcs
#$(OBJD)/linker$(CMO): $(OBJD)/crcs$(CMO)

#*************************************************************#
# Create a version of the socket library that uses the Unix
# library.  This is so that on Unix platforms, users do not
# need to compile any C code in order to get started.

$(OBJD)/usocket:
	$(MKDIR) $(OBJD)/usocket

$(OBJD)/_usocket$(CMO): $(OBJD)/usocket $(ECAMLC) $(EMV) $(ECP) \
	  $(OBJD)/socksupp$(CMO)	\
	  $(OBJD)/socksupp$(CMI)	\
	  $(OBJD)/socket$(CMI)		\
	  $(ENSROOT)/socket/usocket.ml
	$(ECPC) $(ENSROOT)/socket/usocket.ml -o $(OBJD)/usocket/socket.ml
	$(ECPC) $(OBJD)/socket$(CMI) -o $(OBJD)/usocket/socket$(CMI)
	$(ETOUCHC) -noaccess $(OBJD)/usocket/socket.mli
	$(ECAMLCC) -I $(OBJD) -o $(OBJD)/usocket $(ENSCOMPFLAGS) $(OBJD)/usocket/socket.ml
	$(EMVC) -nocmi -mlext $(OBJD)/usocket/socket -o $(OBJD)/_usocket

#*************************************************************#
# In compiling the socket library, we need to be careful not
# to leave a socket.cmx in the $(OBJ) directory because the
# optimizing compiler will inline off of socket.cmx, which
# will cause problems when we link with usocket.cmx.

$(OBJD)/ssocket:
	$(MKDIR) $(OBJD)/ssocket

$(OBJD)/_ssocket$(CMO): $(OBJD)/ssocket $(ECAMLC) $(EMV) $(ECP) \
	  $(OBJD)/socksupp$(CMO)	\
	  $(OBJD)/socksupp$(CMI)	\
	  $(OBJD)/socket$(CMI)		\
	  $(ENSROOT)/socket/ssocket.ml
	$(ECPC) $(ENSROOT)/socket/ssocket.ml -o $(OBJD)/ssocket/socket.ml
	$(ECPC) $(OBJD)/socket$(CMI) -o $(OBJD)/ssocket/socket$(CMI)
	$(ETOUCHC) -noaccess $(OBJD)/ssocket/socket.mli
	$(ECAMLCC) -I $(OBJD) -o $(OBJD)/ssocket $(ENSCOMPFLAGS) $(OBJD)/ssocket/socket.ml
	$(EMVC) -nocmi -mlext $(OBJD)/ssocket/socket -o $(OBJD)/_ssocket

#*************************************************************#

$(OBJD)/nulldynlink:
	$(MKDIR) $(OBJD)/nulldynlink

$(OBJD)/_nulldynlink$(CMO): $(OBJD)/nulldynlink $(ECAMLC) $(EMV) $(ECP) \
	  $(ENSROOT)/util/nulldynlink.ml \
	  $(OBJD)/util$(CMO)
	$(ETOUCHC) -noaccess $(OBJD)/nulldynlink/dynlink.mli
	$(ECPC) $(CAMLLIB)/dynlink$(CMI) -o $(OBJD)/nulldynlink/dynlink$(CMI)
	$(ECPC) $(ENSROOT)/util/nulldynlink.ml -o $(OBJD)/nulldynlink/dynlink.ml
	$(ECAMLCC) -I $(OBJD) -o $(OBJD)/nulldynlink $(ENSCOMPFLAGS) $(OBJD)/nulldynlink/dynlink.ml
	$(ECPC) -nocmi -mlext $(OBJD)/nulldynlink/dynlink -o $(OBJD)/_nulldynlink

#*************************************************************#
# Rules for building HOT tools

BASIC_ENSCONF_skt = $(CUSTOM) $(LIBUNIX) $(LIBSOCK) $(LINK_THR) $(ENSLIBS) 

libhot: hot			# this should be phased out

hotshare: $(OBJD) \
	$(ENSLIB)/hot_ens.h	\
	$(ENSLIB)/hot_error.h	\
	$(ENSLIB)/hot_msg.h	\
	$(ENSLIB)/hot_sys.h	\
	$(ENSLIB)/hot_thread.h

hoto: hotshare \
	install \
	$(ENSLIB)/libhoto$(ARC)	\
	outboard		\
	hot_testo		

hoti: hotshare \
	$(ENSLIB)/libhot$(ARC)	\
	hot_test

hotml: hotshare \
	$(OBJD)/libhotml$(CMA)

hot: hoto hoti hotml


# Create an object file containing the ML code
# We have to use ENSCONFDEP_skt because the hot_inboard_c.c
# uses the socket version of the fd representation.
$(OBJD)/hot$(OBJ): $(ENSCONFDEP_skt) $(HOT_INBOARDOBJ)
	$(RM) hot.c
	$(MLCOMP) -output-obj -o hot$(OBJ) $(BASIC_ENSCONF_skt) $(HOT_INBOARDOBJ) $(HOT_MLLINK)
	$(RM) $(OBJD)/hot$(OBJ)
	$(MV) hot$(OBJ) $(OBJD)/hot$(OBJ)

# Put all the libraries, ML code, and runtime into one library
$(OBJD)/libhot$(ARC): $(HOT_INBOARDCOBJ) $(OBJD)/hot$(OBJ) $(OBJD)/libsock$(ARC)
	$(PARTIALLD) $(PARTIALLDO) $(OBJD)/libhot$(OBJ) \
	  $(OBJD)/hot$(OBJ)	\
	  $(HOT_INBOARDCOBJ)	\
	  $(OBJD)/libsock$(ARC)	\
	  $(OCAML_LIB)/libunix$(ARCS) \
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)$(OBJD)/libhot$(ARC) $(OBJD)/libhot$(OBJ)
	$(RANLIB) $(OBJD)/libhot$(ARC)

# Put HOT objects into one library
$(OBJD)/libhoto$(ARC): $(HOT_OUTBOARDCOBJ)
	$(MKLIB) $(MKLIBO)$(OBJD)/libhoto$(ARC) $(HOT_OUTBOARDCOBJ)
	$(RANLIB) $(OBJD)/libhoto$(ARC)

# Generate the outboard executable
outboard: $(ENSCONFDEP_skt) $(HOT_OUTBOARDOBJ)
	$(MLLINK) -o $(ENSROOT)/demo/outboard$(EXE) $(CUSTOM) $(LIBSYS) $(BASIC_ENSCONF_skt) $(HOT_OUTBOARDOBJ)

# Generate the outboard executable
$(OBJD)/libhotml$(CMA): $(ENSCONFDEP) $(HOT_SHAREDOBJ)
	$(MLLIBR) -o $(OBJD)/libhotml$(CMA) $(HOT_SHAREDOBJ)

#*************************************************************#
# Building HOT with optional CRYPTO lib


CRYPTO_ENSCONF_skt = $(CUSTOM) $(LIBUNIX) $(LIBSOCK) $(LINK_THR) $(ENSLIBS) $(CRYPTO_LINK)

libhot-crypto: hotc

hotocrypto: hotshare \
	install \
	$(ENSLIB)/libhoto-crypto$(ARC)	\
	outboard-crypto		\
	hot_testo-crypto 	\
	hot_sec_testo		

hotcrypto: hotshare \
	$(ENSLIB)/libhot-crypto$(ARC)	\
	hot_test-crypto 	\
	hot_sec_test

hotmlcrypto: hotshare \
	$(OBJD)/libhotml-crypto$(CMA)

hotc: hotocrypto hotcrypto hotmlcrypto


# CRYPTO equivalent to above

# Create an object file containing the ML code
# We have to use ENSCONFDEP_skt because the hot_inboard_c.c
# uses the socket version of the fd representation, includes CRYPTO_LINK
$(OBJD)/hot-crypto$(OBJ): $(ENSCONFDEP_skt) $(HOT_INBOARDOBJ)
	$(RM) hot-crypto.c
	$(MLCOMP) -output-obj -o hot-crypto$(OBJ) $(CRYPTO_ENSCONF_skt) $(HOT_INBOARDOBJ) $(HOT_MLLINK)
	$(RM) $(OBJD)/hot-crypto$(OBJ)
	$(MV) hot-crypto$(OBJ) $(OBJD)/hot-crypto$(OBJ)

# Put all the libraries, ML code, and runtime into one library
$(OBJD)/libhot-crypto$(ARC): $(HOT_INBOARDCOBJ) $(OBJD)/hot-crypto$(OBJ) $(OBJD)/libsock$(ARC)
	$(PARTIALLD) $(PARTIALLDO) $(OBJD)/libhot-crypto$(OBJ) \
	  $(OBJD)/hot-crypto$(OBJ)	\
	  $(HOT_INBOARDCOBJ)	\
	  $(OBJD)/libsock$(ARC)	\
	  $(OCAML_LIB)/libunix$(ARCS) \
	  $(MLRUNTIME)
	$(MKLIB) $(MKLIBO)$(OBJD)/libhot-crypto$(ARC) $(OBJD)/libhot-crypto$(OBJ)
	$(RANLIB) $(OBJD)/libhot-crypto$(ARC)

$(OBJD)/libhoto-crypto$(ARC): $(HOT_OUTBOARDCOBJ)
	$(MKLIB) $(MKLIBO)$(OBJD)/libhoto-crypto$(ARC) $(HOT_OUTBOARDCOBJ) $(CRYPTOLIB_C)
	$(RANLIB) $(OBJD)/libhoto-crypto$(ARC)

# Generate the outboard executable
outboard-crypto: $(ENSCONFDEP_skt) $(HOT_OUTBOARDOBJ)
	$(MLLINK) -o $(ENSROOT)/demo/outboard-crypto$(EXE) $(CUSTOM) $(LIBSYS) $(CRYPTO_ENSCONF_skt) $(HOT_OUTBOARDOBJ)

# Generate the outboard executable
$(OBJD)/libhotml-crypto$(CMA): $(ENSCONFDEP) $(HOT_SHAREDOBJ)
	$(MLLIBR) -o $(OBJD)/libhotml-crypto$(CMA) $(HOT_SHAREDOBJ)

hot_test-crypto$(UNIXRULE): $(OBJD)/libhot-crypto$(ARC) $(OBJD)/hot_test$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_test-crypto$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhot-crypto$(ARC) \
	  $(HOT_LINK) \
	  $(CRYPTOLIB_C)

hot_testo-crypto$(UNIXRULE): $(OBJD)/libhoto-crypto$(ARC) $(OBJD)/hot_test$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_testo-crypto$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhoto-crypto$(ARC) \
	  $(HOT_LINK) \
	  $(CRYPTOLIB_C)


hot_sec_test$(UNIXRULE): $(OBJD)/libhot-crypto$(ARC) $(OBJD)/hot_sec_test$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_sec_test$(EXE) \
	  $(OBJD)/hot_sec_test$(OBJ) \
	  $(OBJD)/libhot-crypto$(ARC) \
	  $(HOT_LINK) \
	  $(CRYPTOLIB_C)

hot_sec_testo$(UNIXRULE): $(OBJD)/libhoto-crypto$(ARC) $(OBJD)/hot_sec_test$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_sec_testo$(EXE) \
	  $(OBJD)/hot_sec_test$(OBJ) \
	  $(OBJD)/libhoto-crypto$(ARC) \
	  $(HOT_LINK) \
	  $(CRYPTOLIB_C)
#*************************************************************#

# Generate the hot_test executable
hot_test$(UNIXRULE): $(OBJD)/libhot$(ARC) $(OBJD)/hot_test$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_test$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(HOT_LINK)

# Generate the outboard test
hot_testo$(UNIXRULE): $(OBJD)/libhoto$(ARC) $(OBJD)/hot_test$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_testo$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhoto$(ARC) \
	  $(HOT_LINK)

# Generate the performance test
hot_perf$(UNIXRULE): $(OBJD)/libhoto$(ARC) $(OBJD)/hot_perf$(OBJ) 
	$(CC) -g -o $(ENSROOT)/demo/hot_perf$(EXE) \
	  $(OBJD)/hot_perf$(OBJ) \
	  $(OBJD)/libhoto$(ARC) \
	  $(HOT_LINK)

# Purified version of outboard test
p_test$(UNIXRULE): $(OBJD)/libhoto$(ARC) $(OBJD)/hot_test$(OBJ) 
	$(PURIFY) $(CC) -g -o $(ENSROOT)/demo/p_test$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhoto$(ARC) \
	  $(HOT_LINK) $(PURIFY_LIB)

# Generate the hot_test executable
hot_test2$(UNIXRULE): $(OBJD)/libhot$(ARC) $(OBJD)/hot_test2$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_test2$(EXE) \
	  $(OBJD)/hot_test2$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(HOT_LINK)

hot_test2o$(UNIXRULE): $(OBJD)/libhoto$(ARC) $(OBJD)/hot_test2$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_test2o$(EXE) \
	  $(OBJD)/hot_test2$(OBJ) \
	  $(OBJD)/libhoto$(ARC) \
	  $(HOT_LINK)

hot_test3$(UNIXRULE): $(OBJD)/libhot$(ARC) $(OBJD)/hot_test3$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_test3$(EXE) \
	  $(OBJD)/hot_test3$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(HOT_LINK)

hot_ping$(UNIXRULE): $(OBJD)/libhot$(ARC) $(OBJD)/hot_ping$(OBJ)
	$(CC) -g -o $(ENSROOT)/demo/hot_ping$(EXE) \
	  $(OBJD)/hot_ping$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(HOT_LINK)

hot_pingo$(UNIXRULE): $(OBJD)/libhoto$(ARC) $(OBJD)/hot_ping$(OBJ) outboard
	$(CC) -g -o $(ENSROOT)/demo/hot_pingo$(EXE) \
	  $(OBJD)/hot_ping$(OBJ) \
	  $(OBJD)/libhoto$(ARC) \
	  $(HOT_LINK)

# Purified version of hot_test
phot_test: $(OBJD)/libhot$(ARC) $(OBJD)/hot_test$(OBJ)
	purify $(CC) -g -o $(ENSROOT)/demo/hot_test$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(HOT_LINK)

#*************************************************************#
# NT version of the hot_test

hot_test$(NTRULE): $(OBJD)/libhot$(ARC) $(OBJD)/hot_test$(OBJ) $(OBJD)\libsock$(ARC)
	cl \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(MLRUNTIME) \
	  $(OCAML_LIB)/libunix$(ARCS) \
	  $(OBJD)/libsock$(ARC) \
	  $(LIBSYSCL)
	$(RM) $(ENSROOT)/demo/hot_test$(EXE)
	$(MV) hot_test-nt$(EXE) $(ENSROOT)/demo/hot_test$(EXE)

hot_testo$(NTRULE): $(OBJD)/libhoto$(ARC) $(OBJD)/hot_test$(OBJ) $(OBJD)\libsock$(ARC)
	cl \
	-o hot_testo-nt$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhoto$(ARC) \
	  $(LIBSYSCL)
	$(RM) $(ENSROOT)/demo/hot_testo$(EXE)
	$(MV) hot_testo-nt$(EXE) $(ENSROOT)/demo/hot_testo$(EXE)

hot_test2$(NTRULE): $(OBJD)/libhot$(ARC) $(OBJD)/hot_test2$(OBJ) $(OBJD)\libsock$(ARC)
	cl \
	  $(OBJD)/hot_test2$(OBJ) \
	  $(OBJD)/libhot$(ARC) \
	  $(MLRUNTIME) \
	  $(OCAML_LIB)/libunix$(ARCS) \
	  $(OBJD)/libsock$(ARC) \
	  $(LIBSYSCL)
	$(RM) $(ENSROOT)/demo/hot_test2$(EXE)
	$(MV) hot_test2-nt$(EXE) $(ENSROOT)/demo/hot_test2$(EXE)

hot_test-crypto$(NTRULE): $(OBJD)/libhot-crypto$(ARC) $(OBJD)/hot_test$(OBJ) $(OBJD)\libsock$(ARC)
	cl \
	-o hot_test-crypto-nt$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhot-crypto$(ARC) \
	  $(MLRUNTIME) \
	  $(OCAML_LIB)/libunix$(ARCS) \
	  $(OBJD)/libsock$(ARC) \
	  $(LIBSYSCL)
	$(RM) $(ENSROOT)/demo/hot_test-crypto$(EXE)
	$(MV) hot_test-crypto-nt$(EXE) $(ENSROOT)/demo/hot_test-crypto$(EXE)

hot_testo-crypto$(NTRULE): $(OBJD)/libhoto-crypto$(ARC) $(OBJD)/hot_test$(OBJ) $(OBJD)\libsock$(ARC)
	cl \
	-o hot_testo-crypto-nt$(EXE) \
	  $(OBJD)/hot_test$(OBJ) \
	  $(OBJD)/libhoto-crypto$(ARC) \
	  $(LIBSYSCL)
	$(RM) $(ENSROOT)/demo/hot_testo-crypto$(EXE)
	$(MV) hot_testo-crypto-nt$(EXE) $(ENSROOT)/demo/hot_testo-crypto$(EXE)

#*************************************************************#
# The ATM transport C file requires special header files

$(OBJD)/atm_unet$(OBJ) : $(ENSROOT)/atm/trans/atm_unet.c
	$(CC) -o $(OBJD)/atm_unet$(OBJ) $(CFLAGS) -c $(INCUNET) $(ENSROOT)/trans/atm/atm_unet.c

$(OBJD)/mpic$(OBJ) : $(ENSROOT)/trans/mpi/mpic.c
	$(CC) -o $(OBJD)/mpic$(OBJ) $(CFLAGS) -c $(INCMPI) $(ENSROOT)/trans/mpi/mpic.c

#*************************************************************#
# Maestro now included in main makefile

maestro:
	cd ../maestro; $(MAKE)

maestro-nt:
	cd ..\maestro\maestro-nt& make

maestro_test: maestro
	cd ../maestro/test; $(MAKE)

#*************************************************************#

clean:
	$(RM) *~ .*~ *.[oa] core .err gmon.out mon.out *.obj
	$(RMDIR) $(OBJD)
	$(MKDIR) $(OBJD)
#	(cd ../lib; $(MAKE) clean)
#	(cd ../demo; $(MAKE) clean)
#	(cd ../maestro; $(MAKE) clean)

realclean: clean
	$(RMDIR) obj
	$(MKDIR) obj


#	(cd ../lib; $(MAKE) realclean)
#	(cd ../demo; $(MAKE) realclean)
#	(cd ../maestro; $(MAKE) realclean)

#*************************************************************#

ML_SRCDIRS = util appl route infr trans type buffer \
  trans/atm trans/mpi rpc socket hot groupd \
  layers/trans layers/other layers/flow layers/bypass	 \
  layers/total layers/gossip layers/debug layers/vsync	 \
  layers/scale layers/security \
  crypto crypto/isaac crypto/OpenSSL

C_SRCDIRS = socket hot crypto/isaac crypto/OpenSSL

depend: $(OBJD) $(ECAMLDEP)
	$(ECAMLDEP) $(DEPFLAGS)\
	  -com "$(ENSCOMP)" \
	  -cc "$(CC)" \
	  -dep $(OBJD) \
	  -depend $(ECAMLC) \
	  -ensroot $(ENSROOT) \
	  -mlsrcdirs $(ML_SRCDIRS) \
	  -csrcdirs $(C_SRCDIRS) > $(DEPEND)

#
#   OLD version
#
#depend: $(OBJD) $(ECAMLDEP)
#	$(ECAMLDEP) $(DEPFLAGS)	\
#	  -com '$$(ENSCOMP)'		\
#	  -depend '$$(ECAMLC)'		\
#	  $(SRCDIRS:%=-I $(ENSROOT)/%)	\
#	  $(ENSROOT)/socket/*.c		\
#	  $(ENSROOT)/hot/*.c		\
#	  $(ENSROOT)/crypto/*.c		\
#	  $(ENSROOT)/crypto/*/*.c	\
#	  $(SRCDIRS:%=$(ENSROOT)/%/*.mli) \
#	  $(SRCDIRS:%=$(ENSROOT)/%/*.ml) > $(DEPEND)

#*************************************************************#
