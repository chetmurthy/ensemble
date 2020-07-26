Summary: toolkit for building reliable distributed applications
Name: ensemble
Version: 0.70
Release: 1
Copyright: distributable
Group: Development/Libraries
Source: ftp.cornell.edu:/pub/ensemble/ensemble-0.70.tar.gz
%description

Ensemble is a toolkit for building reliable distributed applications.
It has been available for free public release since 1996 and has been
used in commercial products, research projects, and for teaching.

Ensemble provides a library of protocols that can be used for quickly
building complex distributed applications.  A simple way to see what
Ensemble does is to try out the "ensemble" demonstration program
(included in the distribution).  You can run several instances of
this program and see them find each other and allow you to send
messages back and forth, detect failures, etc....  For more
information, see the tutorial (tut.ps).

When using Ensemble as a library, an application registers 10 or so
event handlers with Ensemble, and then the Ensemble protocols handle
the details of reliably sending and receiving messages, transferring
state, implementing security, detecting failures, and managing
reconfigurations in the system.

The source distribution includes interfaces to numerous languages.
For this RPM, we include only: the C library and header files (the
"HOT" interface), the C++ library (the "Maestro" interface), several
system executables and demo programs, and the documentation (split
into a tutorial and reference manual).

The binary RPM version of this software includes the Objective Caml
run-time system, which is copyright 1996, 1997, 1998, 1999 INRIA.
However, Objective CAML is not needed in order to use these libraries
and programs.

%prep
%setup -n ensemble

%build
sh tools/build.sh

%install
sh tools/install.sh

%files
%doc README INSTALL.htm BUGS doc/ref.ps doc/tut.ps tools/00-INDEX doc/license.txt
%doc doc/maestro/Maestro.htm
%doc doc/maestro/Maestro_CSX.htm
%doc doc/maestro/Maestro_ClSv.htm
%doc doc/maestro/Maestro_GroupMember.htm
%doc doc/maestro/Maestro_Overview.htm
%doc doc/maestro/Maestro_Types.htm
%doc doc/maestro/Maestro_Xfer.htm
%doc doc/maestro/async-xfer-example.htm
%doc doc/maestro/example.htm
%doc doc/maestro/groupd.htm
%doc doc/maestro/hot_thread.htm
%doc doc/maestro/maestro-logo-small.jpg
%doc doc/maestro/maestro-logo.jpg
%doc doc/maestro/multi-threaded.example.htm
%doc doc/maestro/single-threaded.example.htm
%doc doc/maestro/sync-xfer-example.htm

/usr/bin/groupd
/usr/bin/gossip
/usr/bin/ensemble
/usr/bin/mtalk
/usr/bin/outboard

/usr/lib/libhot.a
/usr/lib/libmae.a

%dir /usr/include/ensemble
/usr/include/ensemble/hot_ens.h
/usr/include/ensemble/hot_error.h
/usr/include/ensemble/hot_mem.h
/usr/include/ensemble/hot_msg.h
/usr/include/ensemble/hot_sys.h
/usr/include/ensemble/hot_thread.h
/usr/include/ensemble/Maestro_ETC.h
/usr/include/ensemble/Maestro_GIOP.h
/usr/include/ensemble/Maestro_IIOPBridge.h
/usr/include/ensemble/Maestro_ORB.h
/usr/include/ensemble/Maestro_Adaptor.h
/usr/include/ensemble/Maestro_CSX.h
/usr/include/ensemble/Maestro_ClSv.h
/usr/include/ensemble/Maestro_ES_ReplicatedUpdates.h
/usr/include/ensemble/Maestro_ES_Simple.h
/usr/include/ensemble/Maestro_GroupMember.h
/usr/include/ensemble/Maestro_Prim.h
/usr/include/ensemble/Maestro_Group.h
/usr/include/ensemble/Maestro.h
/usr/include/ensemble/Maestro_Config.h
/usr/include/ensemble/Maestro_OrderedSet.h
/usr/include/ensemble/Maestro_Perf.h
/usr/include/ensemble/Maestro_Types.h
