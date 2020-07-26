/**************************************************************/
/* TRACE.C */
/* Author: Mark Hayden, 11/99 */
/* Copyright 1999 Cornell University.  All rights reserved. */
/* Copyright 1999, 2000 Mark Hayden.  All rights reserved. */
/* See license.txt for further information. */
/**************************************************************/
#include "ce_internal.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define MAX_LOGS 128
static char* logs[MAX_LOGS] ;
static int nlogs = 0 ;

void trace_add(char* s) {
    int i ;

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
    logs[nlogs] = (char*) ce_malloc(strlen(s));
    strcpy(logs[nlogs],s) ;
    printf ("Logging %s\n", s);
    nlogs ++ ;
}

int am_traced(char* s0) {
    int i ;

    for (i=0;i<nlogs;i++) {
	if (!logs[i]) continue ;
	if (strncmp(logs[i], s0, strlen(s0))) continue ;
	break ;
    }

    return (i < nlogs) ;
}

