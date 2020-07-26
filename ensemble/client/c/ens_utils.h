#ifndef __ENS_UTILS_H__
#define __ENS_UTILS_H__

#ifdef __cplusplus
extern "C" {
#endif

#include "ens.h"

void EnsAddTrace(char* s);
void EnsTrace(char *name, const char *s, ...);
void EnsPanic(const char *s, ...);
void *EnsMalloc(int size);
void EnsGetUptime(int *day, int *hour, int *min, int *sec);
void EnsSleepMilli(int milliseconds);
char *StringOfStatus(ens_status_t status);
char *StringOfUpType(ens_up_msg_t upcall);

#ifdef __cplusplus
}
#endif

#endif
