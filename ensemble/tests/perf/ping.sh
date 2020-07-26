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
#!/bin/sh 

for i in 20 100 200 300 400 500 600 700 800 900; do 
   ping $1 -s $i -i 2 -c 5
done



