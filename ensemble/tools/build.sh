#*************************************************************#
#
#   Ensemble, (Version 0.70p1)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
# script for building Ensemble on Linux 

set OSTYPE=linux
set MACHTYPE=i386
export OSTYPE
export MACHTYPE

( cd opt ; make )
( cd opt ; make socket )
( cd opt ; make hot )
( cd maestro ; make )
( cd demo ; make socketopt )
