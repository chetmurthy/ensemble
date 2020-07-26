/**************************************************************/
/*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
// $Header: /cvsroot/ensemble/maestro/src/corba/Maestro_ETC.C,v 1.2 1998/03/02 19:07:10 tclark Exp $
// 
// Support for publishing IOR's.
//
// Author:  Alexey Vaysburd, Sept. 1997.

#pragma implementation
#include "Maestro_Types.h"
#include "Maestro_ETC.h"


/******************************* ETC ********************************/

void 
Maestro_Etc::install(Maestro_String &name,
		     Maestro_CORBA_String &data) 
{
  Maestro_CORBA_OctetSequence seq;
  seq.size(data.size);
  memcpy(seq.data(), data.s, data.size);
  install(name, seq);
}

void 
Maestro_Etc::install(Maestro_String &name,
		     Maestro_CORBA_OctetSequence &data) 
{
  char *etc;
  Maestro_ErrorHandler err;
  
  if ((etc = getenv("MAESTRO_ETC")) == NULL)
    err.panic("Maestro_Etc:  environment variable MAESTRO_ETC must be set");
  
  unsigned size = name.size + strlen(etc) + 1;
  char *p = new char[size];
  memset(p, 0, size);
  ostrstream fname(p, size);
  fname << etc << "/" << name.s;
  
  ofstream ofs(p);
  if (!ofs) err.panic("Maestro_Etc:install: could not open %s", p);
  ofs << data.data();
  ofs.close();
}

void 
Maestro_Etc::lookup(Maestro_String &name, 
		    Maestro_CORBA_String &data,
		    unsigned long maxSize)
{
  Maestro_CORBA_OctetSequence seq;
  lookup(name, seq, maxSize);
  data = (char*) seq.data();
}

void 
Maestro_Etc::lookup(Maestro_String &name, 
		    Maestro_CORBA_OctetSequence &data,
		    unsigned long maxSize)
{
  char *etc;
  Maestro_ErrorHandler err;
  
  if ((etc = getenv("MAESTRO_ETC")) == NULL)
    err.panic("Maestro_Etc:  environment variable MAESTRO_ETC must be set");
  
  unsigned size = name.size + strlen(etc) + 1;
  char *p = new char[size];
  memset(p, 0, size);
  ostrstream fname(p, size);
  fname << etc << "/" << name.s;
  
  char *buf = new char[maxSize];
  ifstream ifs(p);
  if (!ifs) err.panic("Maestro_Etc:lookup: could not open %s", p);
  ifs.getline(buf, maxSize); 
  ifs.close();

  data.size(strlen(buf));
  memcpy(data.data(), buf, strlen(buf));
  delete [] buf;
}

Maestro_Etc Maestro_DefaultEtc;
