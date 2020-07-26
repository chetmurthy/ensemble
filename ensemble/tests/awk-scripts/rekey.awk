#!/usr/bin/gawk -f 

# These are the lines we are interested in. All the 
# rest are irrelevent. 
#
#gx-23:370: Cleanup -- removing all secure channels.
#gx-23:123: Join, time to rekey = 0.102 0.111 10 [||]
#gx-23:158: Leave, time to rekey = 0.094 0.102 9 [||]
#gx-16:47:REKEY_DIAMM:Time for patch = 0.088 10
#
#gx-10:66:OPTREKEYM: 15 FinalTree= 249
#gx-10:66:PERFREKEYM: 15 sum=2 max=2
#
#Ignore these lines:
#gx-22:101:REKEY_DIAMM:Reconstruction Complete

BEGIN {
  for (i=1; i<=60; i++) {
    num[i] = 0;
    note[i] = "";
    ltn[i,0] = 0;
    ltn_diam[i,0] = 0;
    ack_diam[i,0] = 0;
    cold_start[i,0] = 0; #Did this iteration start from an empty cache?
  }
  counter = 0;

  cold_bit = 0;     # Cleanup flags

  diamond = 0;  # is the a diam_rekey file?
}


$2 == "Cleanup" {
    cold_bit = 1;
}

function cold(n) {
  if (cold_bit == 1) {
    cold_start[n,num[n]] = 1;
    cold_start[n+1,num[n+1]] = 1;
    cold_start[n-1,num[n-1]] = 1;
    cold_bit = 0;
  }
}

$2 == "Join," {
  n = $9;
  res = $7;
  note[n] = "Join";
  ltn[n,num[n]] = res;
  cold(n);
  num[n]++;
}


#The line is: 
#gx-23:158: Leave, time to rekey = 0.094 0.102 9 [||]
$2 == "Leave," {
  n = $9;
  res = $7;
  note[n] = "Leave";
  ltn[n,num[n]] = res;
  cold(n);
  num[n]++;
}


#The line is:
#gx-16:47:REKEY_DIAMM:Time for patch = 0.088 10
#
#Ignore:
#gx-22:101:REKEY_DIAMM:Reconstruction Complete
#
# Also handle:
#gx-10:66:OPTREKEYM: 15 FinalTree= 249
#gx-10:66:PERFREKEYM: 15 sum=2 max=2
#
{
  split ($1,t,":");
  if ((t[3] == "REKEY_DIAMM") && ($3 != "Complete")) {
    n = $6;
    res = $5;
    ltn_diam[n,num[n]] = res;
    diamond = 1;
  }
}


#gx-1:126:PERFREKEYM: ACK2 done, 55 sum=2
$2 == "ACK2" {
  n  = $4 ;
  split ($5,t,"=");
  ack2 = t[2];
  ack2_diam[n,num[n]-1] = ack2 ;
#  printf("%d Ack2=%d\n", n, ack2);
}

function cov(E, x) {
  return (x-E)*(x-E);
}


#Compute the number of non-zero entries in the array
#
function non_zero(i,arr){
  n=0;

  if (num[i] > 0) {
    for (j=0; j<=num[i]; j++) {
      if (cold_start[i,j] == 0) {
	n++;
      }
    }
  }
  return n;
}

#Compute the expectancy.
#
function expt(i,arr) {
  S = 0;

  if (num[i] > 0) {
    for (j=0; j<=num[i]; j++) {
      if (cold_start[i,j] == 0) {
	S += arr[i,j];
      } 
    }
  }

  return S;
}

#Comute the variance.
#
function var(i,S,arr) {
    Vltn = 0;

    if (num[i] > 0) {
      for (j=0; j<=num[i]; j++) {
	if (cold_start[i,j] == 0) {
	  Vltn += cov(S,arr[i,j]);
	}
      }
    }
    return Vltn;
}

END {
  for (i=0; i<=60; i++){
    if (diamond == 0) {
      n = non_zero(i,ltn);
      Sltn = 0;
      Vltn = 0;
      Ssize = 0;
      Ssum = 0;
      Smax = 0;
      if (n > 0) {
	Sltn = expt(i,ltn);
	Sltn = Sltn/n;
	Vltn = var(i,Sltn,ltn);
	Vltn = sqrt(Vltn/n);
      } 
      
      if (n>0) { 
	printf ("dWGL nmembers=%d %s n=%d E=%1.3f V=%1.3f\n", 
		i,note[i],n,Sltn, Vltn);
	
# To files
	if (note[i] == "Join") {
	  printf ("%d\t %1.3f\n", i, Sltn) > "JOIN_DWGL_LTN";
	} else {
	  printf ("%d\t %1.3f\n", i, Sltn)  > "LEAVE_DWGL_LTN";
	}
      }
    } else {
      n = non_zero(i,ltn_diam);
      Sltn = 0;
      Vltn = 0;
      Sack2 = 0 ;
      if (n>0) {
	Sltn = expt(i,ltn_diam);
	Sltn = Sltn/n;
	Vltn = var(i,Sltn,ltn_diam);
	Vltn = sqrt(Vltn/n);
	Sack2 = expt(i,ack2_diam);
	Sack2 = Sack2/n;
      } 
      
      if (n > 0 ) {
	printf ("DIAMOND nmembers=%d %s n=%d E=%1.3f V=%1.3f ACK2=%1.3f\n",
		i,note[i],n,Sltn,Vltn, Sack2);
	
#To files
	if (note[i] == "Join") {
	  printf ("%d\t %1.3f\n", i, Sltn) > "JOIN_DIAM_LTN";
	  printf ("%d\t %1.3f\n", i, Sack2) > "JOIN_DIAM_ACKS2";
	} else {
	  printf ("%d\t %1.3f\n", i, Sltn)  > "LEAVE_DIAM_LTN";
	  printf ("%d\t %1.3f\n", i, Sack2) > "LEAVE_DIAM_ACKS2";
	}
      }
    }
  }
}



