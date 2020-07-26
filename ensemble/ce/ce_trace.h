/********************************************************************/
/* trace.h --- Transis Direct (C) Interface
 * Author: Ohad Rodeh 10/98
*/
/********************************************************************/

#ifndef __CE_TRACE_H__
#define __CE_TRACE_H__

#include <stdarg.h>
#include <stdio.h>
#include "mm_so.h"

/******************************************************************/

LINKDLL void trace_add(char* s) ;
LINKDLL int am_traced(char *name);
LINKDLL void ce_trace(char *name, const char *s, ...);


#ifdef CE_TRACE
/* Slower code, with trace support
 */

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

#define TRACE_D(x,y) \
{                               \
  int debug ;                   \
                                \
  debug = am_traced(NAME);      \
  if (debug==1) {               \
    printf("%s: %s %d\n",NAME,x,y);   \
    fflush(stdout);             \
  }                             \
}

#define TRACE_GEN(x) {printf x; fflush(stdout);}
#else
/* Faster code, no trace support
 */

#define TRACE(x) 
#define TRACE2(x,y) 
#define TRACE_D(x,y)
#define TRACE_GEN(x) 
#endif



#endif /* __CE_TRACE_H__ */
/********************************************************************/


