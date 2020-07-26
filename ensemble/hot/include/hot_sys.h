/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/* 
 * Contents:  System functionality for HOT.
 *
 * Author:  Alexey Vaysburd, November 1996
 *
 */

#ifndef __HOT_SYS_H__
#define __HOT_SYS_H__

#include <stdarg.h>

/* Print the specified message and exit
 */
void hot_sys_Panic(const char *reason, ...);
void hot_sys_vPanic(const char *reason, va_list args);
void hot_sys_Warning(const char *reason, ...);
void hot_sys_vWarning(const char *reason, va_list args);

#ifdef WIN32
#define inline
#endif

#endif /*__HOT_SYS_H__*/
