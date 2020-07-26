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
/* CE_SO.H : Used to help build DLLs on windows*/
/* Author: Ohad Rodeh */
/**************************************************************/

/* This is for defining DLLs on windows. Do NOT define CE_DLL_LINK
 * in applications that use the CE library.
 */
#ifndef __CE_SO_H__
#define __CE_SO_H__

#define LINKDLL 

/*
#ifndef LINKDLL 
#ifdef _WIN32

#ifdef CE_MAKE_A_DLL
#define LINKDLL __declspec( dllexport)
#else
#define LINKDLL __declspec( dllimport)
#endif

#else
#define LINKDLL 
#endif 
#endif 
*/

#endif  // __CE_SO_H__
