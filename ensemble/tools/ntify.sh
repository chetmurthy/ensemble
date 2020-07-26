#!/bin/bash -f

echo "Creating:" 

# mk dir
# 
# Don't do this for config.mk and clean_all.mk, they contain NT specific options
#
for i in mk/files mk/ocaml mk/ocamlopt mk/preamble mk/rules mk/sub; do
      echo "  " $i
      sed -f tools/ntify.sed $i.mk > $i.nmk
done

# top level 
for i in Makefile server/Makefile doc/Makefile doc/layers/Makefile tools/Makefile \
         tests/Makefile ; do
      echo "  " $i
      sed -f tools/ntify.sed $i > $i.nt
done

# client directory
sed -f tools/ntify.sed client/Makefile > client/Makefile.nt
sed -f tools/ntify.sed client/c/Makefile > client/c/Makefile.nt
sed -f tools/ntify.sed client/java/Makefile > client/java/Makefile.nt
sed -f tools/ntify.sed client/java/ensemble/Makefile > client/java/ensemble/Makefile.nt
sed -f tools/ntify.sed client/cs/Makefile > client/cs/Makefile.nt

# server dir
for i in prog appl mm crypto crypto/fake crypto/real groupd \
         infr layers route socket socket/u socket/s socket/s/unix socket/s/nt \
         trans type util; do 
      echo "  " $i/Makefile
      sed -f tools/ntify.sed server/$i/Makefile > server/$i/Makefile.nt
done

# layers inside the server directory
for i in bypass gossip other security transis debug total vsync \
	flow scale trans; do
      echo "  " server/layers/$i/Makefile
      sed -f tools/ntify.sed server/layers/$i/Makefile > server/layers/$i/Makefile.nt
done


