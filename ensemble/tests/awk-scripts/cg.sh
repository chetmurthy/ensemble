#!/bin/csh -f

echo "Cleaning up"
rm -f RPC_* LTN_* THR_* LEAVE_* JOIN_*

#latency.awk < ../perf/LATENCY
#throu.awk   < ../perf/THROU
rpc.awk     < ../RPC 
#ping.awk    < ../../perf/PING
#rekey.awk   < ../../rekey/test_dwgl_50
#rekey.awk   < ../../rekey/test_diam_50

gnuplot gn

#echo "Moving eps files to papers directory"
#mv -f *.eps $HOME/papers/sec-jrnl/perf/

echo "Removing temporary files"
rm -f RPC_* LTN_* THR_* LEAVE_* JOIN_*

