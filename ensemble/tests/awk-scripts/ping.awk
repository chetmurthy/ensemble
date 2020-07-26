#!/usr/bin/gawk -f 

# This script extracts information from the output of ping. 
# 
# The line we are interested in is: 
# round-trip min/avg/max = 0.3/0.3/0.3 ms


BEGIN {
  current_size = 0 ;
  avg[0] = 0;
}


#
# convert milliseconds to seconds. 
# 
$1 == "round-trip" && $2 == "min/avg/max" {
  split ($4,t,"/");
  avg[current_size] = t[2]/1000;
}

# The line is: 
#PING gx-05.cs.huji.ac.il (132.65.180.205) from 132.65.180.204 : 700 data bytes
#
$1 == "PING" && $4 == "from" && $6 == ":" && $8 == "data" && $9 == "bytes" {
  current_size = $7;
}

END {
  printf("-------------------------------------------------\n");
  printf("PING statistics\n");

  #
  # We want to see this in milliseconds. 
  #
  avg1 = avg[20] * 1000;
  printf ("%i, avg=%1.5f\n", 20, avg1);
  printf ("%i %1.5f\n", 20, avg1) > "RPC_PING";
  for (i=100; i<1000; i+=100) {
    avg1 = avg[i] * 1000;
    printf ("%i, avg=%1.5f\n", i, avg1);
    printf ("%i %1.5f\n", i, avg1) > "RPC_PING";
  }
  printf("-------------------------------------------------\n");
}



