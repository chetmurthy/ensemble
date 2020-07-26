#!/usr/bin/gawk -f 

# This is the line we are interested in 
#gx-22:31:PERF  3 :1-n msgs per seconds = 693.928536


BEGIN {
  stage = "REG";
  bit = 0;
  for (i=0; i<30; i++) {
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

{
  split ($1,t,":");
  if (t[3] == "PERF" || t[2] == "PERF") 
    if ($4=="msgs" && $5 == "per" && $6 == "seconds" && bit == 0) {
      n = $2 ;
      res = $8;
#    printf ("n=%d res=%f\n", n,res);
      record[stage,n] += res;
      record_num[stage,n] ++;
      bit = 1;
    } else {bit=0;}
  else {bit=0;}
}

function perf(stage,i) {
  if (record_num[stage,i] > 0) {
    record[stage,i] = record[stage,i]/record_num[stage,i];
    printf ("%d (num=%d) \t = %1.6f\n", i, record_num[stage,i],
	    record[stage,i]);
    tmp_stage = ("THR_" stage) ;
    printf ("%d \t %1.6f\n", i, record[stage,i]) > tmp_stage;
  } else
    record_num[stage,i] = 0;
}

END {
  printf "\nREG\n";
  for (i=0; i<30; i++) perf("REG",i);
  printf "\nAUTH\n";
  for (i=0; i<30; i++) perf("AUTH",i);
  printf "\nSECURE\n";
  for (i=0; i<30; i++) perf("SECURE",i);
}



