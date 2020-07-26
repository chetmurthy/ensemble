# -*- Mode: makefile -*-
#*************************************************************#
#
# INSTALL: Installation dependencies.  These copy files into
# the lib directory.
#
# Author: Mark Hayden, 6/97
#
#*************************************************************#
# Compiled ML interface files

$(ENSLIB)/ensemble$(CMI): $(ENSLIB)/ensemble.mli $(OBJD)/ensemble$(CMI) $(ECP)
	$(ECPC) $(OBJD)/ensemble$(CMI) -o $(ENSLIB)/ensemble$(CMI)

$(ENSLIB)/rpc$(CMI): $(ENSLIB)/rpc.mli $(OBJD)/rpc$(CMI) $(ECP)
	$(ECPC) $(OBJD)/rpc$(CMI) -o $(ENSLIB)/rpc$(CMI)

$(ENSLIB)/hsys$(CMI): $(ENSLIB)/hsys.mli $(OBJD)/hsys$(CMI) $(ECP)
	$(ECPC) $(OBJD)/hsys$(CMI) -o $(ENSLIB)/hsys$(CMI)

$(ENSLIB)/htk$(CMI): $(ENSLIB)/htk.mli $(OBJD)/htk$(CMI) $(ECP) $(ETOUCH)
	$(ECPC) $(OBJD)/htk$(CMI) -o $(ENSLIB)/htk$(CMI)

$(ENSLIB)/socket$(CMI): $(ENSLIB)/socket.mli $(OBJD)/socket$(CMI) $(ECP) $(ETOUCH)
	$(ECPC) $(OBJD)/socket$(CMI) -o $(ENSLIB)/socket$(CMI)

#*************************************************************#
# Null ML interface files (these are only for dependency generation)

$(ENSLIB)/ensemble.mli: $(ETOUCH) 
	$(ETOUCHC) -noaccess $(ENSLIB)/ensemble.mli

$(ENSLIB)/rpc.mli: $(ETOUCH)
	$(ETOUCHC) -noaccess $(ENSLIB)/rpc.mli

$(ENSLIB)/hsys.mli: $(ETOUCH)
	$(ETOUCHC) -noaccess $(ENSLIB)/hsys.mli

$(ENSLIB)/htk.mli: $(ETOUCH)
	$(ETOUCHC) -noaccess $(ENSLIB)/htk.mli

$(ENSLIB)/socket.mli: $(ETOUCH)
	$(ETOUCHC) -noaccess $(ENSLIB)/socket.mli

#*************************************************************#
# ML libraries

$(ENSLIB)/libensmin$(CMA): $(OBJD)/libensmin$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/libensmin -o $(ENSLIB)/libensmin

$(ENSLIB)/libenscore$(CMA): $(OBJD)/libenscore$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/libenscore -o $(ENSLIB)/libenscore

$(ENSLIB)/libensrest$(CMA): $(OBJD)/libensrest$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/libensrest -o $(ENSLIB)/libensrest

$(ENSLIB)/librpc$(CMA): $(OBJD)/librpc$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/librpc -o $(ENSLIB)/librpc

$(ENSLIB)/libhtk$(CMA): $(OBJD)/libhtk$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/libhtk -o $(ENSLIB)/libhtk

$(ENSLIB)/usocket$(CMA): $(OBJD)/usocket$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/usocket -o $(ENSLIB)/usocket

$(ENSLIB)/socket$(CMA): $(OBJD)/socket$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/socket -o $(ENSLIB)/socket

$(ENSLIB)/crypto$(CMA): $(OBJD)/crypto$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/crypto -o $(ENSLIB)/crypto

$(ENSLIB)/_nulldynlink$(CMO): $(OBJD)/_nulldynlink$(CMO) $(ECP)
	$(ECPC) -nocmi -mlext $(OBJD)/_nulldynlink -o $(ENSLIB)/_nulldynlink

$(ENSLIB)/libeth$(CMA): $(OBJD)/libeth$(CMA) $(ECP)
	$(ECPC) -nocmi -nocmo -mlext $(OBJD)/libeth -o $(ENSLIB)/libeth

#*************************************************************#
# C libraries

$(ENSLIB)/libsock$(ARC): $(OBJD)/libsock$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libsock$(ARC) -o $(ENSLIB)/libsock$(ARC)

$(ENSLIB)/libcryptoc$(ARC): $(OBJD)/libcryptoc$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libcryptoc$(ARC) -o $(ENSLIB)/libcryptoc$(ARC)

$(ENSLIB)/libceth$(ARC): $(OBJD)/libceth$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libceth$(ARC) -o $(ENSLIB)/libceth$(ARC)

$(ENSLIB)/libhot$(ARC): $(OBJD)/libhot$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libhot$(ARC) -o $(ENSLIB)/libhot$(ARC)

$(ENSLIB)/libhoto$(ARC): $(OBJD)/libhoto$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libhoto$(ARC) -o $(ENSLIB)/libhoto$(ARC)

$(ENSLIB)/libhot-crypto$(ARC): $(OBJD)/libhot-crypto$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libhot-crypto$(ARC) -o $(ENSLIB)/libhot-crypto$(ARC)

$(ENSLIB)/libhoto-crypto$(ARC): $(OBJD)/libhoto-crypto$(ARC) $(ECP)
	$(ECPC) $(OBJD)/libhoto-crypto$(ARC) -o $(ENSLIB)/libhoto-crypto$(ARC)

#*************************************************************#
# C header files

$(ENSLIB)/hot_ens.h: $(ENSROOT)/hot/include/hot_ens.h $(ECP)
	$(ECPC) -ro $(ENSROOT)/hot/include/hot_ens.h -o $(ENSLIB)/hot_ens.h

$(ENSLIB)/hot_error.h: $(ENSROOT)/hot/include/hot_error.h $(ECP)
	$(ECPC) -ro $(ENSROOT)/hot/include/hot_error.h -o $(ENSLIB)/hot_error.h

$(ENSLIB)/hot_msg.h: $(ENSROOT)/hot/include/hot_msg.h $(ECP)
	$(ECPC) -ro $(ENSROOT)/hot/include/hot_msg.h -o $(ENSLIB)/hot_msg.h

$(ENSLIB)/hot_sys.h: $(ENSROOT)/hot/include/hot_sys.h $(ECP)
	$(ECPC) -ro $(ENSROOT)/hot/include/hot_sys.h -o $(ENSLIB)/hot_sys.h

$(ENSLIB)/hot_thread.h: $(ENSROOT)/hot/include/hot_thread.h $(ECP)
	$(ECPC) -ro $(ENSROOT)/hot/include/hot_thread.h -o $(ENSLIB)/hot_thread.h

#*************************************************************#
