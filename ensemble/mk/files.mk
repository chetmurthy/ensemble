#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# -*- Mode: makefile -*-
#*************************************************************#
#
# FILES: macros listing files of different parts of Ensemble
#
# Author: Mark Hayden, 3/96
#
#*************************************************************#
# ENSEMBLEMLI and ENSEMBLECMI list the modules of the core
# library that are exported from the Ensemble module.  The
# MLI macro is used for dependency calculation.  The CMI is
# used for generating the ensemble.ml and ensemble.mli
# files.

ENSEMBLEMLI = \
	$(ENSROOT)/util/hsys.mli	\
	$(ENSROOT)/util/queuee.mli	\
	$(ENSROOT)/util/trans.mli	\
	$(ENSROOT)/util/util.mli	\
	$(ENSROOT)/util/arraye.mli	\
	$(ENSROOT)/util/arrayf.mli	\
	$(ENSROOT)/util/trace.mli	\
	$(ENSROOT)/util/lset.mli	\
	$(ENSROOT)/util/resource.mli	\
	$(ENSROOT)/util/sched.mli	\
	$(ENSROOT)/buffer/buf.mli	\
	$(ENSROOT)/buffer/refcnt.mli	\
	$(ENSROOT)/buffer/pool.mli	\
	$(ENSROOT)/buffer/iovec.mli	\
	$(ENSROOT)/buffer/iovecl.mli	\
	$(ENSROOT)/buffer/mbuf.mli	\
	$(ENSROOT)/type/time.mli	\
	$(ENSROOT)/type/addr.mli	\
	$(ENSROOT)/type/proto.mli	\
	$(ENSROOT)/type/stack_id.mli	\
	$(ENSROOT)/type/unique.mli	\
	$(ENSROOT)/type/endpt.mli	\
	$(ENSROOT)/type/group.mli	\
	$(ENSROOT)/type/security.mli	\
	$(ENSROOT)/type/shared.mli	\
	$(ENSROOT)/type/param.mli	\
	$(ENSROOT)/type/view.mli	\
	$(ENSROOT)/type/conn.mli	\
	$(ENSROOT)/route/route.mli	\
	$(ENSROOT)/type/alarm.mli	\
	$(ENSROOT)/type/auth.mli	\
	$(ENSROOT)/type/domain.mli	\
	$(ENSROOT)/type/event.mli	\
	$(ENSROOT)/type/property.mli	\
	$(ENSROOT)/type/appl_intf.mli	\
	$(ENSROOT)/type/appl_handle.mli \
	$(ENSROOT)/type/layer.mli	\
	$(ENSROOT)/infr/async.mli	\
	$(ENSROOT)/appl/elink.mli	\
	$(ENSROOT)/infr/transport.mli	\
	$(ENSROOT)/infr/stacke.mli	\
	$(ENSROOT)/appl/arge.mli	\
	$(ENSROOT)/appl/appl.mli

ENSEMBLECMI = \
	$(OBJD)/hsys$(CMI)	\
	$(OBJD)/queuee$(CMI)	\
	$(OBJD)/trans$(CMI)	\
	$(OBJD)/util$(CMI)	\
	$(OBJD)/arraye$(CMI)	\
	$(OBJD)/arrayf$(CMI)	\
	$(OBJD)/trace$(CMI)	\
	$(OBJD)/lset$(CMI)	\
	$(OBJD)/resource$(CMI)	\
	$(OBJD)/sched$(CMI)	\
	$(OBJD)/async$(CMI)	\
	$(OBJD)/buf$(CMI)	\
	$(OBJD)/refcnt$(CMI)	\
	$(OBJD)/pool$(CMI)	\
	$(OBJD)/iovec$(CMI)	\
	$(OBJD)/iovecl$(CMI)	\
	$(OBJD)/mbuf$(CMI)	\
	$(OBJD)/time$(CMI)	\
	$(OBJD)/addr$(CMI)	\
	$(OBJD)/proto$(CMI)	\
	$(OBJD)/stack_id$(CMI)	\
	$(OBJD)/unique$(CMI)	\
	$(OBJD)/endpt$(CMI)	\
	$(OBJD)/group$(CMI)	\
	$(OBJD)/security$(CMI)	\
	$(OBJD)/shared$(CMI)	\
	$(OBJD)/param$(CMI)	\
	$(OBJD)/view$(CMI)	\
	$(OBJD)/conn$(CMI)	\
	$(OBJD)/route$(CMI)	\
	$(OBJD)/alarm$(CMI)	\
	$(OBJD)/auth$(CMI)	\
	$(OBJD)/domain$(CMI)	\
	$(OBJD)/event$(CMI)	\
	$(OBJD)/property$(CMI)	\
	$(OBJD)/appl_intf$(CMI)	\
	$(OBJD)/appl_handle$(CMI) \
	$(OBJD)/layer$(CMI)	\
	$(OBJD)/elink$(CMI)	\
	$(OBJD)/transport$(CMI)	\
	$(OBJD)/stacke$(CMI)	\
	$(OBJD)/arge$(CMI)	\
	$(OBJD)/appl$(CMI)

ENSEMBLECMO = \
	$(OBJD)/hsys$(CMO)	\
	$(OBJD)/queuee$(CMO)	\
	$(OBJD)/trans$(CMO)	\
	$(OBJD)/util$(CMO)	\
	$(OBJD)/arraye$(CMO)	\
	$(OBJD)/arrayf$(CMO)	\
	$(OBJD)/trace$(CMO)	\
	$(OBJD)/lset$(CMO)	\
	$(OBJD)/resource$(CMO)	\
	$(OBJD)/sched$(CMO)	\
	$(OBJD)/async$(CMO)	\
	$(OBJD)/buf$(CMO)	\
	$(OBJD)/refcnt$(CMO)	\
	$(OBJD)/pool$(CMO)	\
	$(OBJD)/iovec$(CMO)	\
	$(OBJD)/iovecl$(CMO)	\
	$(OBJD)/mbuf$(CMO)	\
	$(OBJD)/time$(CMO)	\
	$(OBJD)/addr$(CMO)	\
	$(OBJD)/proto$(CMO)	\
	$(OBJD)/stack_id$(CMO)	\
	$(OBJD)/unique$(CMO)	\
	$(OBJD)/endpt$(CMO)	\
	$(OBJD)/group$(CMO)	\
	$(OBJD)/security$(CMO)	\
	$(OBJD)/shared$(CMO)	\
	$(OBJD)/auth$(CMO)	\
	$(OBJD)/param$(CMO)	\
	$(OBJD)/view$(CMO)	\
	$(OBJD)/conn$(CMO)	\
	$(OBJD)/route$(CMO)	\
	$(OBJD)/alarm$(CMO)	\
	$(OBJD)/domain$(CMO)	\
	$(OBJD)/event$(CMO)	\
	$(OBJD)/property$(CMO)	\
	$(OBJD)/appl_intf$(CMO)	\
	$(OBJD)/appl_handle$(CMO) \
	$(OBJD)/layer$(CMO)	\
	$(OBJD)/elink$(CMO)	\
	$(OBJD)/transport$(CMO)	\
	$(OBJD)/stacke$(CMO)	\
	$(OBJD)/arge$(CMO)	\
	$(OBJD)/appl$(CMO)

#*************************************************************#
# Core Ensemble stuff

ENSCOREOBJ = \
	$(OBJD)/printe$(CMO)	\
	$(OBJD)/hsys$(CMO)	\
	$(OBJD)/queuee$(CMO)	\
	$(OBJD)/trans$(CMO)	\
	$(OBJD)/util$(CMO)	\
	$(OBJD)/trace$(CMO)	\
	$(OBJD)/arraye$(CMO)	\
	$(OBJD)/arrayf$(CMO)	\
	$(OBJD)/fqueue$(CMO)	\
	$(OBJD)/queuea$(CMO)	\
	$(OBJD)/lset$(CMO)	\
	$(OBJD)/once$(CMO)	\
	$(OBJD)/priq$(CMO)	\
	$(OBJD)/resource$(CMO)	\
	$(OBJD)/sched$(CMO)	\
\
	$(OBJD)/buf$(CMO)	\
	$(OBJD)/refcnt$(CMO)	\
	$(OBJD)/pool$(CMO)	\
	$(OBJD)/iovec$(CMO)	\
	$(OBJD)/iovecl$(CMO)	\
	$(OBJD)/iq$(CMO)	\
	$(OBJD)/mbuf$(CMO)	\
	$(OBJD)/marsh$(CMO)	\
\
	$(OBJD)/time$(CMO)	\
	$(OBJD)/addr$(CMO)	\
	$(OBJD)/version$(CMO)	\
	$(OBJD)/proto$(CMO)	\
	$(OBJD)/stack_id$(CMO)	\
	$(OBJD)/unique$(CMO)	\
	$(OBJD)/endpt$(CMO)	\
	$(OBJD)/group$(CMO)	\
	$(OBJD)/security$(CMO)	\
	$(OBJD)/shared$(CMO)	\
	$(OBJD)/auth$(CMO)	\
	$(OBJD)/param$(CMO)	\
	$(OBJD)/view$(CMO)	\
	$(OBJD)/conn$(CMO)	\
	$(OBJD)/handler$(CMO)	\
	$(OBJD)/route$(CMO)	\
	$(OBJD)/alarm$(CMO)	\
	$(OBJD)/domain$(CMO)	\
	$(OBJD)/event$(CMO)	\
	$(OBJD)/property$(CMO)	\
	$(OBJD)/appl_intf$(CMO)	\
	$(OBJD)/appl_handle$(CMO) \
	$(OBJD)/msecchan$(CMO)	\
	$(OBJD)/tree$(CMO)	\
	$(OBJD)/tdefs$(CMO)	\
	$(OBJD)/layer$(CMO)	\
\
	$(OBJD)/async$(CMO)	\
	$(OBJD)/elink$(CMO)	\
	$(OBJD)/transport$(CMO)	\
	$(OBJD)/config_trans$(CMO) \
	$(OBJD)/glue$(CMO)	\
	$(OBJD)/stacke$(CMO)	\
\
	$(OBJD)/arge$(CMO)	\
	$(OBJD)/appl$(CMO)	\
\
	$(OBJD)/ensemble$(CMO)

#*************************************************************#
# These are an almost minimal set of additional modules to link with
# the core library.  They do not include many of the optional
# features of ensemble such as the various servers and debugging
# capabilities.  Only layers needed for vsync and vsync+total
# protocol stacks are included here.

ENSMINOBJ = \
	$(OBJD)/ipmc$(CMO)	\
	$(OBJD)/udp$(CMO)	\
	$(OBJD)/real$(CMO)	\
	$(OBJD)/unsigned$(CMO)	\
\
	$(OBJD)/top_appl$(CMO)	\
	$(OBJD)/top$(CMO)	\
	$(OBJD)/partial_appl$(CMO) \
	$(OBJD)/stable$(CMO)	\
	$(OBJD)/bottom$(CMO)	\
	$(OBJD)/mnak$(CMO)	\
	$(OBJD)/pt2pt$(CMO)	\
	$(OBJD)/suspect$(CMO)	\
	$(OBJD)/merge$(CMO)	\
	$(OBJD)/inter$(CMO)	\
	$(OBJD)/intra$(CMO)	\
	$(OBJD)/elect$(CMO)	\
	$(OBJD)/frag$(CMO)	\
	$(OBJD)/leave$(CMO)	\
	$(OBJD)/sync$(CMO)	\
	$(OBJD)/vsync$(CMO)	\
	$(OBJD)/slander$(CMO)	\
	$(OBJD)/heal$(CMO)	\
	$(OBJD)/pt2ptw$(CMO)	\
	$(OBJD)/pt2ptwp$(CMO)	\
	$(OBJD)/mcredit$(CMO)	\
	$(OBJD)/mflow$(CMO)	\
	$(OBJD)/sequencer$(CMO) \
\
	$(OBJD)/fpmb$(CMO)	\

#*************************************************************#
# All other modules are listed here.

ENSRESTOBJ = \
	$(OBJD)/pgp$(CMO)	\
	$(OBJD)/arrayop$(CMO)	\
	$(OBJD)/powermarsh$(CMO) \
	$(OBJD)/timestamp$(CMO)	\
	$(OBJD)/hsyssupp$(CMO)	\
	$(OBJD)/bypassr$(CMO)	\
	$(OBJD)/raw$(CMO)	\
	$(OBJD)/signed$(CMO)	\
	$(OBJD)/scale$(CMO)	\
	$(OBJD)/debug$(CMO)	\
	$(OBJD)/appl_old$(CMO)  \
	$(OBJD)/appl_debug$(CMO) \
	$(OBJD)/appl_aggr$(CMO) \
	$(OBJD)/appl_power$(CMO) \
	$(OBJD)/appl_compat$(CMO) \
	$(OBJD)/appl_lwe$(CMO)	\
	$(OBJD)/appl_multi$(CMO) \
	$(OBJD)/handle$(CMO) \
	$(OBJD)/reflect$(CMO)	\
	$(OBJD)/heap$(CMO)	\
	$(OBJD)/partition$(CMO) \
	$(OBJD)/eth$(CMO)	\
\
	$(OBJD)/protos$(CMO)	\
\
	$(OBJD)/mutil$(CMO)	\
	$(OBJD)/proxy$(CMO)	\
	$(OBJD)/member$(CMO)	\
	$(OBJD)/coord$(CMO)	\
	$(OBJD)/actual$(CMO)	\
	$(OBJD)/manage$(CMO)	\
\
	$(OBJD)/netsim$(CMO)	\
	$(OBJD)/tcp$(CMO)	\
\
	$(OBJD)/switch$(CMO)	\
	$(OBJD)/exchange$(CMO)	\
	$(OBJD)/rekey$(CMO)	\
	$(OBJD)/secchan$(CMO)	\
\
	$(OBJD)/local$(CMO)	\
	$(OBJD)/cltsvr$(CMO)	\
	$(OBJD)/xfer$(CMO)	\
	$(OBJD)/subcast$(CMO)	\
	$(OBJD)/migrate$(CMO)	\
	$(OBJD)/optrekey$(CMO)	\
	$(OBJD)/realkeys$(CMO)	\
	$(OBJD)/perfrekey$(CMO)	\
	$(OBJD)/encrypt$(CMO)	\
	$(OBJD)/primary$(CMO)	\
	$(OBJD)/present$(CMO)	\
\
	$(OBJD)/window$(CMO)	\
\
	$(OBJD)/collect$(CMO)	\
	$(OBJD)/request$(CMO)	\
	$(OBJD)/total$(CMO)	\
	$(OBJD)/totem$(CMO)	\
	$(OBJD)/seqbb$(CMO)	\
	$(OBJD)/tops$(CMO)	\
	$(OBJD)/asym$(CMO)	\
\
	$(OBJD)/assert$(CMO)	\
	$(OBJD)/delay$(CMO)	\
	$(OBJD)/drop$(CMO)	\
	$(OBJD)/chk_secchan$(CMO) \
	$(OBJD)/chk_rekey$(CMO) \
	$(OBJD)/chk_fifo$(CMO)	\
	$(OBJD)/chk_total$(CMO)	\
	$(OBJD)/chk_sync$(CMO)	\
	$(OBJD)/pr_stable$(CMO)	\
	$(OBJD)/pr_suspect$(CMO) \
	$(OBJD)/gcast$(CMO)	\
	$(OBJD)/pbcast$(CMO)	\
	$(OBJD)/zbcast$(CMO)	\
	$(OBJD)/chk_causal$(CMO) \
	$(OBJD)/mcausal$(CMO)	\
	$(OBJD)/causal$(CMO)	\
\
	$(OBJD)/dtbl$(CMO)	\
	$(OBJD)/dtblbatch$(CMO)	\
	$(OBJD)/disp$(CMO)	\
	$(OBJD)/dbg$(CMO)	\
	$(OBJD)/dbgbatch$(CMO)

# Yet more stuff that is no longer used/supported.
#	$(OBJD)/credit$(CMO)	\
#	$(OBJD)/rate$(CMO)	\
#	$(OBJD)/smq$(CMO)	\
#	$(OBJD)/dag$(CMO)	\
#	$(OBJD)/bypass$(CMO)	\
#	$(OBJD)/safe$(CMO)
#	$(OBJD)/bypfifo$(CMO)	\
#	$(OBJD)/side$(CMO)	\
#	$(OBJD)/mngchan$(CMO)	\
#*************************************************************#
# Socket library

SOCKOBJ = \
	$(OBJD)/socksupp$(CMO)	\
	$(OBJD)/_ssocket$(CMO)

USOCKOBJ = \
	$(OBJD)/socksupp$(CMO)	\
	$(OBJD)/_usocket$(CMO)

SOCKCOBJ = \
	$(OBJD)/static_string$(OBJ) \
	$(OBJD)/gettimeofday$(OBJ) \
	$(OBJD)/heapc$(OBJ)	\
	$(OBJD)/md5c$(OBJ)	\
	$(OBJD)/multicasts$(OBJ) \
	$(OBJD)/select$(OBJ)	\
	$(OBJD)/sendopt$(OBJ)	\
	$(OBJD)/sockfd$(OBJ)	\
	$(OBJD)/sockopt$(OBJ)	\
	$(OBJD)/ethc$(OBJ)	\
	$(OBJD)/spawn$(OBJ)	\
	$(OBJD)/sendrecv$(OBJ)	\
	$(OBJD)/stdin$(OBJ)

#*************************************************************#
# ATM Files

ATMOBJ = \
	$(OBJD)/atm$(CMO)

ATMCOBJ = \
	$(OBJD)/atm_unet$(OBJ)	\
	$(OBJD)/atm_ocaml$(OBJ)

#*************************************************************#
# MPI Files

MPIOBJ = \
	$(OBJD)/mpi$(CMO)

MPICOBJ = \
	$(OBJD)/mpic$(OBJ)

#*************************************************************#
# Crypto Stuff

CRYPTOOBJ = \
        $(OBJD)/isaac$(CMO)     \
	$(OBJD)/rc4$(CMO)

CRYPTOCOBJ = \
        $(OBJD)/isaac_c$(OBJ)   \
        $(OBJD)/randport$(OBJ)  \
	$(OBJD)/rc4_c$(OBJ)	

#*************************************************************#
# HOT files

HOT_SHAREDOBJ = \
	$(OBJD)/hot_util$(CMO)

HOT_INBOARDOBJ = \
	$(HOT_SHAREDOBJ)		\
	$(OBJD)/hot_appl$(CMO)		\
	$(OBJD)/hot_inboard$(CMO)

HOT_OUTBOARDOBJ = \
	$(HOT_SHAREDOBJ)		\
	$(OBJD)/hot_outboard$(CMO)

HOT_SHAREDCOBJ = \
	$(OBJD)/hot_mem$(OBJ)	\
	$(OBJD)/hot_error$(OBJ)	\
	$(OBJD)/hot_sys$(OBJ)	\
	$(OBJD)/hot_msg$(OBJ)	\
	$(OBJD)/$(HOT_THREAD_OBJ) # see config.mk

HOT_INBOARDCOBJ = \
	$(HOT_SHAREDCOBJ)		\
	$(OBJD)/hot_inboard_c$(OBJ)

HOT_OUTBOARDCOBJ = \
	$(HOT_SHAREDCOBJ)		\
	$(OBJD)/hot_outboard_c$(OBJ)

#*************************************************************#
# RvR's RPC support

RPCOBJ = \
	$(OBJD)/xlist$(CMO)	\
	$(OBJD)/scanf$(CMO)	\
	$(OBJD)/eval$(CMO)	\
	$(OBJD)/sockio$(CMO)	\
	$(OBJD)/rpc$(CMO)

#*************************************************************#
