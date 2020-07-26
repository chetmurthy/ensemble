/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include "rc4.h"

#define swap_byte(x,y) t = *(x); *(x) = *(y); *(y) = t

void 
prepare_key(unsigned char *key_data_ptr, int key_data_len, rc4_key *key)
{
  unsigned char t;
  unsigned char index1;
  unsigned char index2;
  unsigned char* state;
  short counter;

  state = &key->state[0];
  for(counter = 0; counter < 256; counter++)
    state[counter] = counter;
  key->x = 0;
  key->y = 0;
  index1 = 0;
  index2 = 0;
  for(counter = 0; counter < 256; counter++) {
    index2 = (key_data_ptr[index1] + state[counter] + index2) % 256;
    swap_byte(&state[counter], &state[index2]);
    index1 = (index1 + 1) % key_data_len;
  }
}

void 
RC4_create_key(unsigned char *src, int n, rc4_key *key) {
  int hex,i;
  char digit[5];
  char seed[256];
  char data[256];
  
  memcpy(data,src,n);
  /*
    n = strlen(data); 
    if (n&1) {
    strcat(data,"0");
    n++;
    }
  */
  if (n&1) {
    data[n] = '0';
    n++;
  }
  n/=2;
  strcpy(digit,"AA");
  digit[4]='\0';
  for (i=0;i<n;i++)	{
    digit[2] = data[i*2];
    digit[3] = data[i*2+1];
    sscanf(digit,"%x",&hex);
    seed[i] = hex;
  }
  prepare_key(seed,n,key);
}

void 
RC4_encrypt(unsigned char *buffer_ptr, int buffer_len, rc4_key *key)
{
  unsigned char t;
  unsigned char x;
  unsigned char y;
  unsigned char* state;
  unsigned char xorIndex;
  short counter;

  x = key->x;
  y = key->y;
  state = &key->state[0];
  for(counter = 0; counter < buffer_len; counter++)
  {
    x = (x + 1) % 256;
    y = (state[x] + y) % 256;
    swap_byte(&state[x], &state[y]);
    xorIndex = (state[x] + state[y]) % 256;
    buffer_ptr[counter] ^= state[xorIndex];
  }
  key->x = x;
  key->y = y;
}

#ifdef MAIN
#include <sys/time.h>
#include <unistd.h>

main (int argc, char **argv) { 
  char buf[1000];
  rc4_key ctx;
  int i;
  static struct timeval bt, et;  
  float elapsed, etime, btime; 
  int times = 1000;

  if (argc > 2) {
    printf ("usage %s <times>\n", argv[0]);
    exit(1);
  }
  if (argc == 2) 
    times = atoi(argv[1]);

  gettimeofday(&bt, (void*)NULL);
  for (i=0; i<times; i++) {
    RC4_create_key ("01234", 5, &ctx);
    RC4_encrypt(buf,1000,&ctx);
  }
  gettimeofday(&et, (void*)NULL);

  etime = et.tv_sec * 1000000 + et.tv_usec;
  btime = bt.tv_sec * 1000000 + bt.tv_usec;
  elapsed = etime - btime;
  printf ("elapsed=%6.0f(usec)\n", elapsed);
}
#endif

