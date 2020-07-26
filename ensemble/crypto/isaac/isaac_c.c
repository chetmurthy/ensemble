/**************************************************************/
/*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* ISAAC_C.C */
/* Author: Ohad Rodeh, 11/98 */
/**************************************************************/
#include <stdio.h>
#include "caml/mlvalues.h"
#include "rand.h"
#include <memory.h>

value isaacml_Init(
  value s_v
) {
  char *s;
  int len;
  randctx *ctx;
  int i;

  s = String_val(s_v);
  len = min (string_length(s_v), RANDSIZ);

  ctx = (randctx*) malloc (sizeof(randctx));
  ctx->randa=ctx->randb=ctx->randc=(ub4)0;
  for (i=0; i<256; ++i) ctx->randrsl[i]=(ub4)0;

  memcpy(ctx->randrsl, s, len);
  randinit(ctx,TRUE);

  return (value) ctx;
}

value isaacml_Rand(
    value ctx_v,
    value ret_v
) {
  randctx *ctx;
  int r,i; 
  char s[4];

  ctx = (randctx*) ctx_v;
  r = rand(ctx);
  for (i=0; i<4; i++) {
    s[i] = r % 256 ;
    r = (r - (r % 256)) >> 8;
  }
  memcpy(String_val(ret_v),s,4);
  return Val_unit;
}
