/* MD5 message digest */

#ifndef __MD5_H__
#define __MD5_H__

typedef unsigned int uint32;

struct MD5Context {
    uint32 buf[4];
    uint32 bits[2];
    unsigned char in[64];
};

void MD5Init(struct MD5Context *ctx);
void MD5Update(struct MD5Context *ctx, const unsigned char *buf, unsigned int len);
void MD5Final(unsigned char *digest, struct MD5Context *ctx);

#endif /* __CE_MD5_H__ */
