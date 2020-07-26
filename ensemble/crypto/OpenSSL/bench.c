/**************************************************************/
/*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include <sys/time.h>
#include <unistd.h>
#define LEN 1000

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/crypto.h>

#include <openssl/rc4.h>
#include <openssl/des.h>
#include <openssl/idea.h>

/* Diffie-Hellman
 */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <openssl/crypto.h>
#include <openssl/bio.h>
#include <openssl/bn.h>
#include <openssl/dh.h>

static const char rnd_seed[] =
"string to make the random number generator think it has entropy";
static unsigned char key16[16]=
{0x12,0x34,0x56,0x78,0x9a,0xbc,0xde,0xf0,
 0x34,0x56,0x78,0x9a,0xbc,0xde,0xf0,0x12};
unsigned char iv[8];
char buf[32] = {'1', '1', '1', '1', '1', '1', '1', '1',
		'2', '2', '2', '2', '2', '2', '2', '2',
		'3', '3', '3', '3', '3', '3', '3', '3',
		'4', '4', '4', '4', '4', '4', '4', '4'};

struct timeval t1,t2;
float milli;

void rc4_test() {
  int i;
  RC4_KEY rc4_ks;

  int test=1;

  switch (test) {
  case 0:
    for(i=0; i<32; i++) printf("%d ", buf[i]);
    printf("\n");
    
    RC4_set_key(&rc4_ks,16,key16);
    RC4(&rc4_ks,32,buf,buf);
    for(i=0; i<32; i++) printf("%d ", buf[i]);
    printf("\n");
    
    RC4_set_key(&rc4_ks,16,key16);
    RC4(&rc4_ks,32,buf,buf);
    for(i=0; i<32; i++) printf("%d ", buf[i]);
    printf("\n");
    break;

  case 1:
    {
      char buf_long[LEN];
      
      gettimeofday (&t1, NULL);
      
      for (i=0; i<1000; i++) {
	RC4_set_key(&rc4_ks,16,key16);
	RC4(&rc4_ks,LEN,buf_long,buf_long);
      }

      gettimeofday (&t2, NULL);
      milli = (t2.tv_usec - t1.tv_usec)  + (t2.tv_sec - t1.tv_sec) * 1000000;
      printf ("RC4: time for encryption (%d * %d) bytes = %f\n",1000,LEN, 
	      milli/1000000);
  }
  break;
  
 default:
   printf ("Test not defined\n");
    exit(0);
  }
}



void des_test() {
  int i;
  des_cblock *buf_as_des_cblock = NULL;
  static des_cblock key ={0x12,0x34,0x56,0x78,0x9a,0xbc,0xde,0xf0};
  unsigned char iv[8];
  des_key_schedule sch;

  int test=1;
  
  switch (test) {
  case 0:
    memset(iv,0,sizeof(iv));
    des_set_key(&key,sch);
    des_ncbc_encrypt(buf,buf,5,sch,&iv,DES_ENCRYPT);
    for(i=0; i<32; i++) printf("%c ", buf[i]);
    printf("\n");
    
    memset(iv,0,sizeof(iv));
    des_set_key(&key,sch);
    des_ncbc_encrypt(buf,buf,5,sch,&iv,DES_DECRYPT);
    for(i=0; i<32; i++) printf("%c ", buf[i]);
    printf("\n");
    break; 
    
  case 1:
    {
      char buf_long[LEN];

      gettimeofday (&t1, NULL);
      
      for (i=0; i<1000; i++) {
	des_set_key(&key,sch);
	des_ncbc_encrypt(buf_long,buf_long,LEN,sch,&iv,DES_DECRYPT);
      }
      
      gettimeofday (&t2, NULL);
      milli = (t2.tv_usec - t1.tv_usec)  + (t2.tv_sec - t1.tv_sec) * 1000000;
      printf ("DES: time for encryption (%d * %d) bytes = %f\n",1000,LEN, 
	      milli/1000000);
    }
    break;
    
  default:
    printf ("Test not defined\n");
    exit(0);
  }
}


void  idea_test() {
  int i;
  IDEA_KEY_SCHEDULE idea_ks, idea_ks_dec;
  
  int test = 1;
  
  switch (test) {
  case 0: 
    memset(iv,0,sizeof(iv));
    idea_set_encrypt_key(key16,&idea_ks);
    idea_cbc_encrypt(buf,buf,
		     (unsigned long)24,&idea_ks,
		     iv,IDEA_ENCRYPT);
    for(i=0; i<32; i++) printf("%c ", buf[i]);
    printf("\n");
    
    memset(iv,0,sizeof(iv));
    idea_set_decrypt_key(&idea_ks,&idea_ks_dec);
    idea_cbc_encrypt(buf,buf,
		     (unsigned long)24,&idea_ks_dec,
		     iv,IDEA_DECRYPT);
    for(i=0; i<32; i++) printf("%c ", buf[i]);
    printf("\n");
    break;
    
  case 1:
    {
      char buf_long[LEN];
      
      gettimeofday (&t1, NULL);
      
      for (i=0; i<1000; i++) {
	idea_set_encrypt_key(key16,&idea_ks);
	idea_cbc_encrypt(buf_long,buf_long,
			 (unsigned long)LEN,&idea_ks,
			 iv,IDEA_ENCRYPT);
      }
      
      gettimeofday (&t2, NULL);
      milli = (t2.tv_usec - t1.tv_usec)  + (t2.tv_sec - t1.tv_sec) * 1000000;
      printf ("IDEA: time for encryption (%d * %d) bytes = %f\n",1000,LEN, 
	      milli/1000000);
    }
    break;
    
  default:
    printf ("Test not defined\n");
    exit(0);
  }
}


#define TIMES 50
void DH_test (){
  int fd,len;
  char *buf = (char*) malloc (200);
  DH *a, *b;

  int alen, aout, blen, bout;
  char *abuf, *bbuf;
  int i;
  
  /* Initialization
   */
#ifdef WIN32
  CRYPTO_malloc_init();
#endif
  RAND_seed(rnd_seed, sizeof rnd_seed);

  fd = open("/cs/phd/orodeh/local/e/ensemble/crypto/OpenSSL/key1024",O_RDONLY);
  len = read(fd, buf, 200);
  printf ("len=%d\n",len); fflush(stdout);
  if (len < 10) {
    printf ("Error, did not read enouth bytes from the file\n");
    exit(0);
  }
  
  a = d2i_DHparams(NULL,&buf,len);
  b=DH_new();
  if (b == NULL) {
    printf ("malloc failed");
    exit(0);
  }
  
  b->p=BN_dup(a->p);
  b->g=BN_dup(a->g);
  if ((b->p == NULL) || (b->g == NULL)) {
    printf("malloc failed\n");
    exit(0);
  }
  
  if (!DH_generate_key(a)) {
    printf ("generate key failed\n");
    exit(0);
  }
  if (!DH_generate_key(b)) {
    printf ("generate key failed\n");
    exit(0);
  }
  
  alen=DH_size(a);
  abuf=(unsigned char *)Malloc(alen);
  /*aout=DH_compute_key(abuf,b->pub_key,a);
  
  printf("key1 =");
  for (i=0; i<aout; i++) printf("%02X",abuf[i]);
  printf ("\n"); 
  */
  
  blen=DH_size(b);
  bbuf=(unsigned char *)Malloc(blen);
  /*  bout=DH_compute_key(bbuf,a->pub_key,b);

  printf("key2 =");
  for (i=0; i<aout; i++)  printf("%02X",bbuf[i]);
  printf ("\n");
  */
  
  gettimeofday (&t1, NULL);
  
  for (i=1; i<TIMES; i++) {
    aout=DH_compute_key(abuf,b->pub_key,a);
    bout=DH_compute_key(bbuf,a->pub_key,b);
  }
  
  gettimeofday (&t2, NULL);
  milli = (t2.tv_usec - t1.tv_usec)  + (t2.tv_sec - t1.tv_sec) * 1000000;
  milli = milli/1000000;
  printf ("DH: time for 2 exponentiations * %d, 1024bit keys = %1.6f\n", TIMES, 
	  milli);
  printf ("time per op=%f\n", (milli/ (2 * TIMES)));
}

int main (){
  printf ("This is a benchmark that studies the performance of OpenSSL\n");
  rc4_test ();
  des_test ();
  idea_test ();
  DH_test();
}



