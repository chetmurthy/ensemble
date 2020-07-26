#*************************************************************#
ENSROOT = ..
include ../mk/config.mk
#*************************************************************#

.SUFFIXES: .dvi .tex 
.tex.dvi:
	latex $< 
#*************************************************************#

all: ref.ps tut.ps hot.ps #projects.ps

tut.dvi: \
	tut.tex		\
	install.tex	\
	config.tex	\
	def.tex		\
	demo.tex	\
	appl_ml.tex	\
	appl_c.tex	\
	appl_text.tex	\
	exec_tut.tex	\
	property.tex	\
	pgp.tex		\
	view_state.tex


ref.dvi: layers/*.tex \
	ref.tex		\
	id.tex		\
	def.tex		\
	event.tex	\
	event_prot.tex	\
	rpc.tex		\
	layer_antmy.tex	\
	layer_model.tex	\
	layer_hdlrs.tex	\
	layer_ref.tex	\
	vsync.tex	\
	exec_ref.tex	\
	membership.tex	\
	bimodal.tex	\
	security.tex	\
	unsafe.tex

ref.ps : ref.dvi
	latex ref
	latex ref
	dvips ref.dvi -o ref.ps 

hot.ps : hot.dvi
	latex hot
	latex hot
	dvips hot.dvi -o hot.ps 

tut.ps : tut.dvi
	latex tut
	latex tut
	dvips tut.dvi -o tut.ps 

projects.dvi: projects.tex
	latex projects
	latex projects
	dvips projects.dvi -o projects.ps 

clean:
	$(RM) *.dvi *~ *.log *.aux *.toc *.lof *.lot TAGS layers/*.aux

realclean: clean
	$(RM) *.ps 

force: clean all

tags:
	etags *.tex ../layers/*/*.tex

