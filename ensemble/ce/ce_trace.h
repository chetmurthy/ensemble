/********************************************************************/
/* trace.h --- Transis Direct (C) Interface
 * Author: Ohad Rodeh 10/98
*/
/********************************************************************/

#ifndef __CE_TRACE_H__
#define __CE_TRACE_H__

void trace_add(char* s) ;
int am_traced(char *name);


#define TRACE(x) {\
  int debug ;                   \
                                \
  debug = am_traced(NAME);      \
  if (debug==1) {               \
    printf("%s:%s\n",NAME,x);   \
    fflush(stdout);             \
  }                             \
}

#define TRACE2(x,y) \
{                               \
  int debug ;                   \
                                \
  debug = am_traced(NAME);      \
  if (debug==1) {               \
    printf("%s:%s:%s\n",NAME,x,y);   \
    fflush(stdout);             \
  }                             \
}




#endif __CE_TRACE_H__
/********************************************************************/


