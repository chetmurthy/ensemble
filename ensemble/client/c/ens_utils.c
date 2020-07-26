/**************************************************************/
/* ENS_UTILS.C */
/* Author: Ohad Rodeh  11/2003 */
/**************************************************************/
#include "ens_utils.h"

#include <stdio.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <sys/time.h>
#endif

#define MAX_LOGS 16
static char* logs[MAX_LOGS] ;
static int nlogs = 0 ;

void EnsAddTrace(char* s)
{
    int i ;
    
//    printf("trace_add\n"); fflush(stdout);
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
    logs[nlogs] = (char*) EnsMalloc(strlen(s)+1);
    if (logs[nlogs] == NULL) {
	printf("Error, out of memory\n");
	exit(1);
    }
    strcpy(logs[nlogs],s) ;
    printf ("Logging %s\n", s);
    nlogs ++ ;
}

static int AmTraced(char* s0)
{
    int i ;

    for (i=0;i<nlogs;i++) {
	if (!logs[i]) continue ;
	if (strncmp(logs[i], s0, strlen(s0))) continue ;
	break ;
    }

    return (i < nlogs) ;
}

#ifdef ENS_TRACE
void EnsTrace(char *name, const char *s, ...)
{
    va_list args;
    static int debugging = -1;

    if (AmTraced(name) == 0) return;
    
    fprintf(stderr, "%s:", name);
    va_start(args, s);
    vfprintf(stderr, s, args);
    fprintf(stderr, "\n");
    va_end(args);
    fflush(stderr);
}
#else 
void EnsTrace(char *name, const char *s, ...)
{
}
#endif


void EnsPanic(const char *s, ...)
{
    va_list args;
    va_start(args, s);
    
    fprintf(stderr, "Ensemble: Fatal error(");
    vfprintf(stderr, s, args);
    fprintf(stderr, ")");
    fprintf(stderr, "\n");
    va_end(args);

    fflush(stderr);
    exit(1);
}

void *EnsMalloc(int size)
{
    void *ptr;
    
    ptr = malloc(size);
    if (ptr == NULL) {
	printf("Out of memory, exiting\n");
	exit(1);
    }
    return ptr;
}


/**************************************************************/
/* Update the total running time
 */
#ifndef _WIN32
void EnsGetUptime(int *day, int *hour, int *min, int *sec)
{
    struct timeval tv;
    static int first_time = 1;
    static int initial_time = 0;
    
    if (gettimeofday(&tv,NULL) == -1)
	perror("Could not get the time of day");

    if (first_time){
	initial_time = tv.tv_sec;
	first_time = 0;
	*day = 0;
	*hour = 0;
	*min = 0;
	*sec = 0;
    } else {
	int diff= tv.tv_sec - initial_time;
	*sec = diff % 60;
	*min = (diff % (60 * 60)) / 60;
	*hour = (diff % (60*60*24)) / (60*60);
	*day = (diff % (60*60*24*365)) / (60*60*24);
    }
}
#else
void EnsGetUptime(int *day, int *hour, int *min, int *sec)
{
    static int first_time = 1;
    static unsigned int initial_time;
    
    if (initial_time == 0) {
	initial_time = GetTickCount() / 1000;
	first_time = 0;
	*day = 0;
	*hour = 0;
	*min = 0;
	*sec = 0;
    } else {
	int diff= (GetTickCount() / 1000) - initial_time;
	*sec = diff % 60;
	*min = (diff % (60 * 60)) / 60;
	*hour = (diff % (60*60*24)) / (60*60);
	*day = (diff % (60*60*24*365)) / (60*60*24);	
    }
}

#endif
/**************************************************************/
#ifdef _WIN32
void EnsSleepMilli(int milliseconds)
{
    Sleep(milliseconds);
}
#else
void EnsSleepMilli(int milliseconds)
{
    int retcode;
    struct timeval tv;

    tv.tv_sec = milliseconds / 1000;
    tv.tv_usec = (milliseconds - tv.tv_sec*1000) * 1000;
    retcode = select(0, NULL, NULL, NULL, &tv) ;

    if (-1 == retcode)
	EnsPanic("Could not wait for %d milliseconds", milliseconds);
}
#endif

/**************************************************************/

// Utility functions.

#define CASE(s) case s: return #s ; break

char *StringOfStatus(ens_status_t status)
{
    switch (status) {
        CASE(Pre);
        CASE(Joining);
        CASE(Normal);
        CASE(Blocked);
        CASE(Leaving);
        CASE(Left);
    default:
        EnsPanic("no such status");
    }

    return "";
}

char *StringOfUpType(ens_up_msg_t upcall)
{
    switch (upcall) {
	CASE(VIEW); 
	CASE(CAST); 
	CASE(SEND); 
	CASE(BLOCK); 
	CASE(EXIT);
    default:
	EnsPanic("no such upcall");
    }

    return "";
}
#undef CASE

/**************************************************************/

