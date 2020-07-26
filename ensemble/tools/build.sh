# script for building Ensemble on Linux 

set ENS_OSTYPE=linux
set ENS_MACHTYPE=i386
export ENS_OSTYPE
export ENS_MACHTYPE

( cd opt ; make )
( cd opt ; make socket )
( cd opt ; make hot )
( cd maestro ; make )
( cd demo ; make socketopt )
