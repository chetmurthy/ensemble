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
/* TRACE.C */
/* Author: Mark Hayden, 11/99 */
/* Copyright 1999 Cornell University.  All rights reserved. */
/* Copyright 1999, 2000 Mark Hayden.  All rights reserved. */
/* See license.txt for further information. */
/**************************************************************/
#define CE_MAKE_A_DLL
#include "ce_trace.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define MAX_LOGS 128
static char* logs[MAX_LOGS] ;
static int nlogs = 0 ;

LINKDLL void trace_add(char* s) {
    int i ;
    
    printf("trace_add\n"); fflush(stdout);
    for (i=0;i<nlogs;i++) {
	if (!logs[i]) continue ;
	if (strcmp(logs[i], s) ==0) break ;
    }
    if (i < nlogs) {
	return ;
    }
    if (nlogs >= MAX_LOGS) {
      printf("TRACE:log_add:table overflow\n") ;
	return ;
    }
    logs[nlogs] = (char*) malloc(strlen(s)+1);
    if (logs[nlogs] == NULL) {
	printf("Error, out of memory\n");
	exit(1);
    }
    strcpy(logs[nlogs],s) ;
    printf ("Logging %s\n", s);
    nlogs ++ ;
}

LINKDLL int am_traced(char* s0) {
    int i ;

    for (i=0;i<nlogs;i++) {
	if (!logs[i]) continue ;
	if (strncmp(logs[i], s0, strlen(s0))) continue ;
	break ;
    }

    return (i < nlogs) ;
}

#ifdef CE_TRACE
LINKDLL void
ce_trace(char *name, const char *s, ...)
{
    va_list args;
    static int debugging = -1;

    if (debugging == -1) {
	debugging = (getenv("CE_TRACE") != NULL) ;
    }
    
    if (!debugging) return;
    if (am_traced(name) == 0) return;
    
    fprintf(stderr, "%s:", name);
    va_start(args, s);
    vfprintf(stderr, s, args);
    fprintf(stderr, "\n");
    va_end(args);
    fflush(stderr);
}
#else 
void ce_trace(char *name, const char *s, ...){}
#endif



