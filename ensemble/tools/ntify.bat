rem 
rem Don't do this for config, it contain NT specific options
rem 

for %%i in (mk/cross mk/dynlink mk/files mk/install mk/main mk/mmm mk/ocaml mk/ocamlopt mk/preamble mk/sub mk/tools) do
      sed -f tools/ntify.sed %%i.mk > %%i.nmk


rem for i in (demo/Makefile.base demo/Makefile.opt \
rem     Makefile .depend */Makefile */.depend) do 
rem       sed -f tools/ntify.sed $i > $i.nt

