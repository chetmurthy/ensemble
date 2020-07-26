# script for installing Ensemble on Linux 

PLATFORM=$ENS_MACHTYPE-$ENS_OSTYPE

# Ensemble demos and utilities
install demo/groupd			/usr/bin
install demo/gossip			/usr/bin
install demo/ensemble			/usr/bin
install demo/mtalk			/usr/bin
install demo/outboard			/usr/bin

# HOT C libraries
install lib/$PLATFORM/libhot.a		/usr/lib
#install lib/$PLATFORM/libhoto.a	/usr/lib
#install demo/outboard			/usr/lib

# Maestro C++ library
install maestro/conf/i386-linux/libmae.a /usr/lib

# HOT C and Maestro C++ header files
install -d /usr/include/ensemble
install hot/include/hot_ens.h				/usr/include/ensemble
install hot/include/hot_error.h				/usr/include/ensemble
install hot/include/hot_mem.h				/usr/include/ensemble
install hot/include/hot_msg.h				/usr/include/ensemble
install hot/include/hot_sys.h				/usr/include/ensemble
install hot/include/hot_thread.h			/usr/include/ensemble
install maestro/src/corba/Maestro_ETC.h			/usr/include/ensemble
install maestro/src/corba/Maestro_GIOP.h		/usr/include/ensemble
install maestro/src/corba/Maestro_IIOPBridge.h		/usr/include/ensemble
install maestro/src/corba/Maestro_ORB.h			/usr/include/ensemble
install maestro/src/group/Maestro_Adaptor.h		/usr/include/ensemble
install maestro/src/group/Maestro_CSX.h			/usr/include/ensemble
install maestro/src/group/Maestro_ClSv.h		/usr/include/ensemble
install maestro/src/group/Maestro_ES_ReplicatedUpdates.h /usr/include/ensemble
install maestro/src/group/Maestro_ES_Simple.h		/usr/include/ensemble
install maestro/src/group/Maestro_GroupMember.h		/usr/include/ensemble
install maestro/src/group/Maestro_Prim.h		/usr/include/ensemble
install maestro/src/group/Maestro_Group.h		/usr/include/ensemble
install maestro/src/type/Maestro.h			/usr/include/ensemble
install maestro/src/type/Maestro_Config.h		/usr/include/ensemble
install maestro/src/type/Maestro_OrderedSet.h		/usr/include/ensemble
install maestro/src/type/Maestro_Perf.h			/usr/include/ensemble
install maestro/src/type/Maestro_Types.h		/usr/include/ensemble
