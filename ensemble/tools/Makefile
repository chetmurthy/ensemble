#*************************************************************#
#
#   Ensemble, (Version 1.00)
#   Copyright 2000 Cornell University
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
.SUFFIXES:
.SUFFIXES: .ml .cmo .mli .cmi

.ml.cmo:
	ocamlc -c $<
.mli.cmi:
	ocamlc -c $<

EXECS = ecamldep ecamlc ecp emv emrg elong etouch

all: $(EXECS)

OCAMLDIR	= /usr/local/src/plg/ocaml-1.03
INCLUDES	= -I $(OCAMLDIR)/utils -I $(OCAMLDIR)/parsing -I $(OCAMLDIR)/typing -I $(OCAMLDIR)/bytecomp -I $(OCAMLDIR)/asmcomp
LINKFLAGS	= $(INCLUDES)

ecamldep.ml: ecamldep.mll
	@ $(RM) ecamldep.ml
	ocamllex ecamldep.mll
	@ chmod -w ecamldep.ml

ecamldep: misc.cmo ecamldep.cmo
	ocamlc -o ecamldep misc.cmo ecamldep.cmo 

setup.ml: setup.mll ../doc/license.txt
	$(RM) setup.ml
	(echo 'let license = "' ;	\
	 cat ../doc/license.txt ;	\
	 echo '"' ;			\
	 cat setup.mll ) > setup.ml
	chmod -w setup.ml

ecp: ecp.cmo mkutil.cmo
	ocamlc -o ecp mkutil.cmo ecp.cmo

echeck.cmo: mkutil.cmo

etouch: etouch.cmo
	ocamlc -o etouch etouch.cmo

emrg: emrg.cmo mkutil.cmo
	ocamlc -o emrg mkutil.cmo emrg.cmo

elong: elong.cmo mkutil.cmo
	ocamlc -o elong mkutil.cmo elong.cmo

emv: emv.cmo mkutil.cmo
	ocamlc -o emv mkutil.cmo emv.cmo

ecamlc: mkutil.cmo echeck.cmo ecamlc.ml
	ocamlc -custom -o ecamlc unix.cma -cclib -lunix mkutil.cmo echeck.cmo ecamlc.ml
#	ocamlc -custom -o ecamlc unix.cma -cclib -lunix mkutil.cmo ecamlc.ml

setup: setup.cmo
	ocamlc -o setup setup.cmo

objinfo: objinfo.ml
	ocamlc $(LINKFLAGS) -o objinfo $(OCAMLDIR)/utils/config.ml $(OCAMLDIR)/typing/ident.ml objinfo.ml

#*************************************************************#

MSDEV	= C:\MSDEV
ARC = lib
NODEFAULTLIB = -cclib -link -cclib /NODEFAULTLIB
LIBSYS	= $(NODEFAULTLIB) \
	-cclib $(MSDEV)\LIB\ADVAPI32.$(ARC)	\
	-cclib $(MSDEV)\LIB\LIBCMT.$(ARC)	\
	-cclib $(MSDEV)\LIB\OLDNAMES.$(ARC)	\
	-cclib $(MSDEV)\LIB\KERNEL32.$(ARC)	\
	-cclib $(MSDEV)\LIB\WSOCK32.$(ARC)
NTLIB = C:\ocaml-1.03\lib

dist: dist.ml mkutil.cmo
	ocamlc -o dist -custom unix.cma -cclib -lunix mkutil.cmo dist.ml

ntdist.ml: dist.ml
	grep -v establish_server dist.ml > ntdist.ml

ntdist.cmo: ntdist.ml
	ocamlc.exe -c ntdist.ml

ntdist.exe: ntdist.cmo
	ocamlc.exe -custom -o ntdist.exe $(LIBSYS) $(NTLIB)/unix.cma -cclib $(NTLIB)/libunix.lib ntdist.cmo

clean:
	rm -f *.cm[ioa] *~ .*~ $(EXECS) ecamldep.ml setup.ml .*~

depend:
	ocamldep *.ml *.mli >.depend

include .depend
