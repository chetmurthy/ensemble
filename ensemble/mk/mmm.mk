# -*- Mode: makefile -*- 
#*************************************************************#
#
# MMM: MMM WWW stuff
#
# Author: Mark Hayden, 2/96
#
#*************************************************************#

WBAPLTSRC = config/wbaplt.ml
WBAPLT =  $(ENSROOT)/tkdemo/wbaplt_hd.ml \
	  $(ENSROOT)/tkdemo/wbbase.ml \
	  $(ENSROOT)/tkdemo/wbaplt_tl.ml


config/wbaplt.ml: $(WBAPLT)
	@ $(RM) $@
	cat $(WBAPLT) > $@
	@ $(CHMOD) 444 $@


$(LIB)/wbaplt.$(CMO): $(LIB)/safehorus.$(CMO)

$(LIB)/wbaplt.$(CMO): config/wbaplt.ml
	cd config ; $(MLCOMP) -I $(ENSROOT)/$(LIB) $(MLFLAGS) $(MMM_FLAGS) -nopervasives wbaplt.ml
	$(CP) -f config/wbaplt.$(CMO) $(LIB)/wbaplt.$(CMO)
	$(CP) -f config/wbaplt.$(CMI) $(LIB)/wbaplt.$(CMI)
	/usr/u/hayden/ensemble/tools/objinfo $(LIB)/wbaplt.$(CMO)

LIBMMMOBJS = \
	$(UTILOBJ) $(TRANSOBJ) $(APPLOBJ) $(UDPOBJ) $(LIB)/htk.$(CMO) $(LAYERSOBJ)

$(LIB)/libhorusmmm.$(CMA): $(LIBMMMOBJS)
	$(MLLIBR) -o $(LIB)/libhorusmmm.$(CMA) $(LIBMMMOBJS)

$(MMM_SRC)/libhorusmmm.$(CMA): $(LIB)/libhorusmmm.$(CMA)
	$(CP) -f $< $@
	@ $(CHMOD) 444 $@

$(MMM_APPL)/wbaplt.$(CMO): $(LIB)/wbaplt.$(CMO)
	$(CP) -f $< $@
	@ $(CHMOD) 444 $@

$(MMM_SRC)/safehorus.$(CMO): $(LIB)/safehorus.$(CMO)
	$(CP) -f $< $@
	@ $(CHMOD) 444 $@

$(MMM_SRC)/safehorus.$(CMI): $(LIB)/safehorus.$(CMI)
	$(CP) -f $< $@
	@ $(CHMOD) 444 $@

$(MMM_SRC)/ept.$(CMI): $(LIB)/ept.$(CMI)
	$(CP) -f $< $@
	@ $(CHMOD) 444 $@

#$(MMM_SRC)/time.$(CMI): $(LIB)/time.$(CMI)
#	$(CP) -f $< $@
#	@ $(CHMOD) 444 $@

$(MMM_SRC)/libcens.a: $(LIBCENS)
	$(CP) -f $< $@
	@ $(CHMOD) 444 $@

mmm: \
	$(MMM_APPL)/wbaplt.$(CMO)		\
	$(MMM_SRC)/ept.$(CMI)		\
	$(MMM_SRC)/safehorus.$(CMO)	\
	$(MMM_SRC)/safehorus.$(CMI)	\
	$(MMM_SRC)/libhorusmmm.$(CMA)	\
	$(MMM_SRC)/libcens.a

#	$(MMM_SRC)/time.$(CMI)		\

FRX	= $(MMM_SRC)/../frx

$(FRX)/wbaplt.$(CMO): $(MMM_APPL)/wbaplt.$(CMO)
	$(CP) -f $< $@

$(FRX)/mmm: /usr/u/hayden/mmm/bin/mmm
	$(CP) -f $< $@

$(FRX)/wbml: wbml
	$(CP) -f $< $@

frx: \
	  $(FRX)/mmm		\
	  $(FRX)/wbml		\
	  $(FRX)/wbaplt.$(CMO)
	cd $(FRX) ;\
	  tar cvf ens-mmm.tar mmm wbaplt.$(CMO) page.html wbml ;\
	  gCMIp -f $(FRX)/ens-mmm.tar
