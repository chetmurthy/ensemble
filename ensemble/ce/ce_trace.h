/********************************************************************/
/* trace.h --- Transis Direct (C) Interface
 * Author: Ohad Rodeh 10/98
*/
/********************************************************************/

#ifndef __CE_TRACE_H__
#define __CE_TRACE_H__

/******************************************************************/
/* This is for defining DLLs on windows. Do NOT define CE_DLL_LINK
 * in applications that use the CE library.
 */
#ifdef _WIN32
#ifdef CE_MAKE_A_DLL
#define LINKDLL __declspec( dllexport)
#else
#define LINKDLL __declspec( dllimport)
#endif
#else
/* This is unused on Unix
 */
#define LINKDLL 
#endif
/******************************************************************/

LINKDLL void trace_add(char* s) ;
LINKDLL int am_traced(char *name);


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




#endif /* __CE_TRACE_H__ */
/********************************************************************/


