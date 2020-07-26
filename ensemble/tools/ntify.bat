copy config\m-nt.h config\m.h
copy config\s-nt.h config\s.h
for %%i in (def\Makefile def\.depend mk\dynlink mk\main mk\mmm mk\ocaml mk\ocamlopt mk\preamble demo\Makefile demo\.depend) do sed -f tools\ntify.sed %%i > %%i.nt
