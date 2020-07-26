# -*- Mode: makefile -*- 
#*************************************************************#
#
# DYNLINK: dynamic linking stuff
#
# Author: Mark Hayden, 4/96
#
#*************************************************************#

LINK_AVAIL = \
	$(OBJD)/priq$(CMI)	\
	$(OBJD)/route$(CMI)	\
	$(OBJD)/socket$(CMI)	\
	$(OBJD)/hsys$(CMI)	\
	$(OBJD)/hsyssupp$(CMI)	\
	$(OBJD)/alarm$(CMI)	\
	$(OBJD)/appl_intf$(CMI)	\
	$(OBJD)/trans$(CMI)	\
	$(OBJD)/timestamp$(CMI)	\
	$(OBJD)/alarm$(CMI)	\
	$(OBJD)/domain$(CMI)	\
	$(OBJD)/conn$(CMI)	\
	$(OBJD)/hashtble$(CMI)	\
	$(OBJD)/queuee$(CMI)	\
	$(OBJD)/fqueue$(CMI)	\
	$(OBJD)/mcredit$(CMI)	\
	$(OBJD)/version$(CMI)	\
	$(OBJD)/param$(CMI)	\
	$(OBJD)/addr$(CMI)	\
	$(OBJD)/manage$(CMI)	\
	$(OBJD)/mutil$(CMI)	\
	$(OBJD)/proxy$(CMI)	\
	$(OBJD)/actual$(CMI)	\
	$(OBJD)/security$(CMI)	\
	$(OBJD)/ipmc$(CMI)	\
	$(OBJD)/unique$(CMI)	\
	$(OBJD)/endpt$(CMI)	\
	$(OBJD)/group$(CMI)	\
	$(OBJD)/event$(CMI)	\
	$(OBJD)/once$(CMI)	\
	$(OBJD)/property$(CMI)	\
	$(OBJD)/async$(CMI)	\
	$(OBJD)/buf$(CMI)	\
	$(OBJD)/refcnt$(CMI)	\
	$(OBJD)/powermarsh$(CMI) \
	$(OBJD)/iovec$(CMI)	\
	$(OBJD)/iovecl$(CMI)	\
	$(OBJD)/pool$(CMI)	\
	$(OBJD)/marsh$(CMI)	\
	$(OBJD)/partition$(CMI)	\
	$(OBJD)/iq$(CMI)	\
	$(OBJD)/lset$(CMI)	\
	$(OBJD)/mbuf$(CMI)	\
	$(OBJD)/arge$(CMI)	\
	$(OBJD)/appl$(CMI)	\
	$(OBJD)/glue$(CMI)	\
	$(OBJD)/proto$(CMI)	\
	$(OBJD)/request$(CMI)	\
	$(OBJD)/sched$(CMI)	\
	$(OBJD)/stack_id$(CMI)	\
	$(OBJD)/switch$(CMI)	\
	$(OBJD)/time$(CMI)	\
	$(OBJD)/trace$(CMI)	\
	$(OBJD)/transport$(CMI)	\
	$(OBJD)/layer$(CMI)	\
	$(OBJD)/util$(CMI)	\
	$(OBJD)/arrayop$(CMI)	\
	$(OBJD)/view$(CMI)	\
	$(OBJD)/bottom$(CMI)	\
	$(OBJD)/mnak$(CMI)	\
	$(OBJD)/pt2pt$(CMI)	\
	$(OBJD)/sync$(CMI)	\
	$(OBJD)/top_appl$(CMI)	\
	$(OBJD)/partial_appl$(CMI) \
	$(OBJD)/resource$(CMI)	\
	$(OBJD)/arraye$(CMI)	\
	$(OBJD)/arrayf$(CMI)	\
	$(OBJD)/linker$(CMI)	\
	$(OBJD)/protos$(CMI)	\
	$(OBJD)/lset$(CMI)	\
	\
	$(OCAML_LIB)/queue$(CMI)	\
	$(OCAML_LIB)/list$(CMI)		\
	$(OCAML_LIB)/unix$(CMI)		\
	$(OCAML_LIB)/array$(CMI)	\
	$(OCAML_LIB)/weak$(CMI)		\
	$(OCAML_LIB)/digest$(CMI)	\
	$(OCAML_LIB)/gc$(CMI)		\
	$(OCAML_LIB)/obj$(CMI)		\
	$(OCAML_LIB)/arg$(CMI)		\
	$(OCAML_LIB)/string$(CMI)	\
	$(OCAML_LIB)/pervasives$(CMI)	\
	$(OCAML_LIB)/hashtbl$(CMI)	\
	$(OCAML_LIB)/random$(CMI)

#*************************************************************#