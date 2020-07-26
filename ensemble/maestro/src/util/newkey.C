/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include <stdlib.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <iostream.h>
#include <fstream.h>
#include <strstream.h>
#include <iomanip.h>
#include <string.h>
#include <unistd.h>
#include "Maestro_ORB.h"

main(int argc, char *argv[]) {
  // Generate a new object key. 
  Maestro_ORB_ObjectKey objKey;
  objKey.init((argc > 1) ? argv[1] : (char*)NULL);
  Maestro_CORBA_String keyStr;
  objKey >> keyStr;
  cout << keyStr << endl;
}
