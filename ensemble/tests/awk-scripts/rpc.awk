#!/usr/bin/gawk -f 

# This is the line we are interested in 
#gx-4:3:latency/round: 0.000434


BEGIN {
  stage = "REG";
  num = 0;
  for (i=0; i<15; i++) {
      record["REG",i] = 0.0;
      record_num["REG",i] = 0;
      record["AUTH",i] =0.0;
      record_num["AUTH",i] = 0;
      record["SECURE",i] = 0.0;
      record_num["SECURE",i] = 0;
    }
}



$1 == "REG" {
  stage = "REG";
}


$1 == "AUTH" {
  stage = "AUTH";
}

$1 == "SECURE" {
  stage = "SECURE";
}

$1 == "size=" {
  num = $2/100;
#  printf ("size=%d\n",$2);
}

#gx-4:3:latency/round: 0.000434
{
  split ($1,t,":");
  if (t[1] == "latency/round" || t[2] == "latency/round" || t[3] == "latency/round" ) {
#    print $0;
    res = $2;
#    printf ("num=%s latency=%s\n", num, $2);
    record[stage,num] += res;
    record_num[stage,num] ++;
  }
}

# Print something readable to STDOUT. print
# something for automatic graph generation to
# a file.
function perf(stage,i) {
  if (record_num[stage,i] > 0) {
    # We want the results in milliseconds, so we multiply by 1000. 
    record[stage,i] = 1000 * (record[stage,i]/record_num[stage,i]);
    printf ("%d (num=%d) \t = %1.6f\n", i*100, record_num[stage,i],
	    record[stage,i]);
    tmp_stage = ("RPC_" stage);
    printf ("%d \t %1.6f\n", i*100, record[stage,i]) > tmp_stage;
  } else
    record_num[stage,i] = 0;
}

END {
  printf "\nREG\n";
  for (i=0; i<15; i++) perf("REG",i);
  printf "\nAUTH\n";
  for (i=0; i<15; i++) perf("AUTH",i);
  printf "\nSECURE\n";
  for (i=0; i<15; i++) perf("SECURE",i);
}



