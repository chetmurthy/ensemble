#!/bin/sh -f

echo "Creating:" 

#
# Don't do this for config.mk and clean_all.mk, they contain NT specific options
#
for i in mk/files mk/ocaml mk/ocamlopt mk/preamble mk/sub; do
      echo "  " $i
      sed -f tools/ntify.sed $i.mk > $i.nmk
done

for i in demo/Makefile demo/life/Makefile demo/tk/Makefile demo/dbm/Makefile \
    Makefile Makefile.top ce/Makefile hot/Makefile crypto/Makefile; do
      echo "  " $i
      sed -f tools/ntify.sed $i > $i.nt
done

#
# Don't do this for maestro and ejava: they have their own build process.
#
for i in appl mm crypto crypto/isaac crypto/OpenSSL doc doc/layers groupd \
    infr layers mk route socket socket/s socket/u trans tools type util; do
      echo "  " $i/Makefile
      sed -f tools/ntify.sed $i/Makefile > $i/Makefile.nt
done

for i in bypass gossip other security transis debug total vsync \
	flow scale trans; do
      echo "  " layers/$i/Makefile
      sed -f tools/ntify.sed layers/$i/Makefile > layers/$i/Makefile.nt
done

#
# take care of the dependencies
echo "   .depend" 
sed -f tools/ntify.sed .depend > .depend.nt
