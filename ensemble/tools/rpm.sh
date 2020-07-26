VERSION=0.70
base=/usr/src/redhat
#( su hayden -c "cd ../tar ; make" )
#cp ../../ensemble-dist/ensemble.tar.gz $base/SOURCES/ensemble-$VERSION.tar.gz
cd $base/SOURCES
#zcat ensemble-$VERSION.tar.gz | tar xf - ensemble/tools/rpm.spec
#rpm -ba $base/SOURCES/ensemble/tools/rpm.spec
rpm -ba /home/hayden/ensemble/tools/rpm.spec
