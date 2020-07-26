/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include "skt.h"

void serror(cmdname, cmdarg)
     const char * cmdname;
     value cmdarg;
{
  /* unix_error is from unixsupport.c */
  extern void unix_error(int errcode, const char * cmdname, value arg);
  unix_error(h_errno, cmdname, cmdarg);
}

#ifndef _WIN32
value win_version(){ invalid_argument("Calling win_version on a Unix system");}
#else

value
win_version(){
  DWORD dwVersion, MajorVersion, MinorVersion;
  char *rep;
  int len;
  value rep_v;
  
  dwVersion = GetVersion();
  
  // Get the Windows version.
  MajorVersion =  (DWORD)(LOBYTE(LOWORD(dwVersion)));
  MinorVersion =  (DWORD)(HIBYTE(LOWORD(dwVersion)));

  switch (MinorVersion){
  case 0:
    switch (MajorVersion) {
    case 3:
      rep = "NT3.5";
      break;
    case 4:
      rep = "NT4.0";
      break;
    case 5:
      rep = "2000";
      break;
    default:
      printf("major=%d\n", MajorVersion); fflush(stdout);
      invalid_argument ("Bad major version in WIN32 system");
      break;
    }
    break;

  case 1:
    switch (MajorVersion){
    case 4:
      rep = "95/98";
      break;
    case 3:
      rep = "3.11";
      break;
    default:
      printf("major=%d\n", MajorVersion); fflush(stdout);
      invalid_argument ("Bad major version in WIN32 system");
      break;
    }
    break;

  default:
    printf("minor=%d\n", MajorVersion); fflush(stdout);
    invalid_argument ("Bad minor version in WIN32 system");
    break;
  }

  len = strlen(rep);
  rep_v = alloc_string(len);
  memcpy(String_val(rep_v), rep, len);
  return rep_v;
}

#endif
