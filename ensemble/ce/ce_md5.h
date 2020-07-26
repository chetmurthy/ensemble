/* MD5 message digest */

#ifndef __CE_MD5_H__
#define __CE_MD5_H__

/* Caml already contains the implementation of these
 * functions. 
 */

typedef unsigned long uint32 ;

struct MD5Context {
    uint32 buf[4];
    uint32 bits[2];
    unsigned char in[64];
};

void MD5Init(struct MD5Context *ctx);
void MD5Update(struct MD5Context *ctx, unsigned char *buf, unsigned int len);
void MD5Final(unsigned char *digest, struct MD5Context *ctx);

#endif /* __CE_MD5_H__ */
