#!/bin/sh -f

echo "Creating:" 

#
# Don't do this for config.mk and clean_all.mk, they contain NT specific options
#
for i in mk/dynlink mk/files mk/install \
    mk/main mk/mmm mk/ocaml mk/ocamlopt mk/preamble \
    mk/sub mk/tools; do
      echo "  " $i
      sed -f tools/ntify.sed $i.mk > $i.nmk
done

for i in demo/Makefile demo/Makefile.base demo/Makefile.opt \
    demo/life/Makefile demo/tk/Makefile demo/dbm/Makefile \
    Makefile ce/Makefile ; do
      echo "  " $i
      sed -f tools/ntify.sed $i > $i.nt
done

#
# Don't do this for maestro and ejava: they have their own build process.
#
for i in appl buffer crypto def doc groupd hot infr \
	 layers lib mk opt route rpc socket trans tools type util; do
      echo "  " $i/Makefile
      sed -f tools/ntify.sed $i/Makefile > $i/Makefile.nt
done

for i in bypass gossip other security transis debug total vsync \
	flow scale trans; do
      echo "  " layers/$i/Makefile
      sed -f tools/ntify.sed layers/$i/Makefile > layers/$i/Makefile.nt
done
