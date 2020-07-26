#!/bin/sh 

for i in 20 100 200 300 400 500 600 700 800 900; do 
   ping $1 -s $i -i 2 -c 5
done



