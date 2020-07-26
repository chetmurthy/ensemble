#*************************************************************#
#
# CLEAN_ALL
#
# Author: Ohad Rodeh  7/2001
#
#*************************************************************#
#  This is needed to overcome a difference between NMAKE (WIN32)
#  and unix make. 
#
#  You need to have the SUBDIRS and MAKE variable defined.

clean_all : 
	for d in $(SUBDIRS) ; do (cd $$d; $(MAKE) -k clean); done
