#*************************************************************#
#
#   Ensemble, 1_42
#   Copyright 2003 Cornell University, Hebrew University
#           IBM Israel Science and Technology
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
.PHONY: perf rekey

#*************************************************************#

.SUFFIXES: .cmo .cmi .ml .mli
.mli.cmi:
	ocamlc  -c $<
.ml.cmo:
	ocamlc  -c $<

#*************************************************************#
all : tools

tools : aux.cmi aux.cmo coord.cmi coord.cmo client.cmo \
	perf/throu.cmo perf/latency.cmo perf/rpc.cmo \
	rekey/rekey.cmo


test1 : tools test1.cmo
	ocamlc -custom -o test1 unix.cma str.cma aux.cmo coord.cmo test1.cmo


MACH = hfstore2 hfstore3 hfstore4 hfstore6

#*************************************************************#

start : 
	echo $(MACH)
	for i in $(MACH); do \
	    echo $$i; \
	    rsh $$i "ocaml -I /home/orodeh/e/1.34/ensemble/tests /home/orodeh/e/1.34/ensemble/tests/client.mls >& /dev/null &" ; \
	done


kill : 
	for i in $(MACH); do \
	   echo $$i ; \
	   rsh $$i "killall ocaml" ; \
	done

#*************************************************************#

client : 
	ocaml client.mls 

try : 	
	ocaml try.mls $(MACH)

uptime : 	
	ocaml uptime.mls $(MACH)

rpc : 
	cd perf; ocaml rpc.mls $(MACH)

throu : 
	cd perf; ocaml throu.mls -lo 4 -hi 4 -step 1 $(MACH)

latency : 
	cd perf; ocaml latency.mls $(MACH)

rekey : 
	cd rekey; ocaml rekey.mls $(MACH)

#*************************************************************#
depend :
	ocamldep *.ml *.mli > .depend

include .depend

clean : 
	rm -f *.cm*
#*************************************************************#
