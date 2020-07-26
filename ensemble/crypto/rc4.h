/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/

#ifndef __RC4_H__
#define __RC4_H__

typedef struct {      
   unsigned char state[256];       
   unsigned char x;        
   unsigned char y;
} rc4_key;

/* Prototypes
*/
void 
RC4_encrypt(unsigned char *buffer_ptr, int buffer_len, rc4_key *key);

void 
RC4_create_key(unsigned char *src, int n, rc4_key *key);

#endif __RC4_H__
