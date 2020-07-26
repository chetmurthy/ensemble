#*************************************************************#
#
#   Ensemble, 2_00
#   Copyright 2004 Cornell University, Hebrew University
#           IBM Israel Science and Technology
#   All rights reserved.
#
#   See ensemble/doc/license.txt for further information.
#
#*************************************************************#
#*************************************************************#
ENSROOT = ..
include ../mk/config.mk
include ../mk/preamble.mk
#*************************************************************#

pdf : ref.pdf tut.pdf 

all: pdf 

TUT_SRC = \
	tut.tex		\
	install.tex	\
	config.tex	\
	def.tex		\
	demo.tex	\
	appl_ml.tex	\
	appl_c.tex	\
	appl_csharp.tex	\
	appl_java.tex	\
	property.tex	\
	pgp.tex		\
	view_state.tex


REF_SRC = \
	layers/*.tex \
	ref.tex		\
	id.tex		\
	def.tex		\
	event.tex	\
	event_prot.tex	\
	layer_antmy.tex	\
	layer_model.tex	\
	layer_hdlrs.tex	\
	layer_ref.tex	\
	vsync.tex	\
	exec_ref.tex	\
	membership.tex	\
	bimodal.tex	\
	transport.tex	\
	security.tex	\
	unsafe.tex

ref.pdf : $(REF_SRC)
	pdflatex ref
	pdflatex ref
	pdflatex ref

ref_hack : $(REF_SRC)
	pdflatex ref

tut.pdf : $(TUT_SRC)
	pdflatex tut
	pdflatex tut
	pdflatex tut

tut_hack : $(TUT_SRC)
	pdflatex tut

#projects.dvi: projects.tex
#	latex projects
#	latex projects
#	dvips projects.dvi -o projects.ps 

clean:
	$(RM) *~ *.log *.aux *.toc *.lof *.lot *.pdf
	$(RM) TAGS layers/*.aux .nfs* *~ .*~ 
	cd layers; $(MAKE) clean
	$(RMDIR) tut ref 

realclean: clean
	$(RM) *.pdf

force: clean all

tags:
	etags *.tex ../layers/*/*.tex

build : 
	cd ..; tar -cf doc-$(VERSION).tar doc/*.pdf; gzip -f doc-$(VERSION).tar; mv doc-$(VERSION).tar.gz ..
