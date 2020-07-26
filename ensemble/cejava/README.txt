Ensemble/HOT - Java Interface via JNI
=====================================

This is a first release of a JNI interface to ensemble. The JVM seems
to cooperate well with the OCAML runtime.

You can join multiple groups per VM, see new views, as well as cast
and receive messages via byte arrays. Neither heartbeat, block or exit
events are delivered so far. Neither leave, suspect, state transfer or 
the VPN functions are implemented.

When joining, you can influence the group name as well as the protocol
stack. IP Multicast transport (DEERING) is hardcoded, the rest are the
default values from hot_ens_InitJoinOps. Accordingly, you must have
ENS_DEERING_PORT set.


Installation:

After adapting the Makefile, 'make' does it all. 'make demo' shows you
whether the build worked. On my machine (Redhat 6.2, Linux i386
2.2.14, egcs 2.91), building against libhot.a works like a
charm. However, chances are that I don't correctly understand building
a shared lib from static ones (HOT, CAML runtime).



(c) 2001, Matthias Ernst (matthias.ernst@coremedia.com)
