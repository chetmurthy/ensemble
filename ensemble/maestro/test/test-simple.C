/**************************************************************/
/*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
// Maestro Simple ORB test.
// 
// Author:  Alexey Vaysburd, Fall 97.
// 
// This file contains server-side object implementation 
// of the grid IDL interface:
//
// interface grid {
//      readonly attribute short height;  // height of the grid
//        readonly attribute short width;   // width of the grid
//
//        attribute string str;
//
//        // set the element [n,m] of the grid, to value:
//        void set(in short n, in short m, in long value);
//
//        // return element [n,m] of the grid:
//        long get(in short n, in short m);
// };
// 
// * The object is bound to the non-replicated Simple ORB.
//
// * The client side can be implemented with any IIOP-compatible
//   ORB (e.g. Orbix 2.2 or OrbixWeb).
// 
// * After the server process is initialized, the stringified IOR 
//   of the replicated server object is stored in file grid.ior in the 
//   directory specified by the MAESTRO_ETC environment variable.  
//   The client can read-in the IOR string and use the 
//   CORBA::ORB::string_to_object() function to obtain the object reference. 

#include "Maestro_CORBA.h"
#include "Maestro_GIOP.h"
#include "Maestro_ORB.h"
#include "Maestro_ES_Simple.h"

// Skeleton for Grid object implementation.
class Grid: public Maestro_SimpleORBObjectAdaptor {
public:

  Grid(Maestro_SimpleORBObjectAdaptor_Options &ops):
      Maestro_SimpleORBObjectAdaptor(ops)
  {
    cout << "Grid constructor" << endl;
    grid = new Maestro_CORBA_Long[100];
    memset(grid, 0, sizeof(Maestro_CORBA_Long) * 100);
    memset(str, 0, 1024 * 10);

    height = "_get_height";
    width = "_get_width";
    set_str = "_set_str";
    get_str = "_get_str";
    set = "set";
    get = "get";
  }

  ~Grid() 
  {
    delete [] grid; 
    cerr << "Deleting Grid" << endl;
  }

  Maestro_GIOP_ReplyStatusType update(
      Maestro_CORBA_String &operation,
      Maestro_CORBA_Message &request,
      Maestro_CORBA_Message &reply)
  {
    // cout << "Grid::update: operation = " << operation << endl;

    if (operation == set_str) {
      Maestro_CORBA_String s;
      request >> s;
      strcpy(str, s.s);
      return MAESTRO_GIOP_REPLY_STATUS_NO_EXCEPTION;
    }
    else if (operation == get_str) {
      Maestro_CORBA_String s(str);
      reply << s;
      return MAESTRO_GIOP_REPLY_STATUS_NO_EXCEPTION;
    }
    else if (operation == height) {
      Maestro_CORBA_Short result = 10;
      reply << result;
      return MAESTRO_GIOP_REPLY_STATUS_NO_EXCEPTION;
    }
    else if (operation == width) {
      Maestro_CORBA_Short result = 10;
      reply << result;
      return MAESTRO_GIOP_REPLY_STATUS_NO_EXCEPTION;
    }
    else if (operation == set) {
      Maestro_CORBA_Long value;
      Maestro_CORBA_Short n, m;

      request >> n >> m >> value;
      //cout << "n = " << n << endl;
      //cout << "m = " << m << endl;
      //cout << "value = " << value << endl; 
      
      grid[10*n + m] = value;
      return MAESTRO_GIOP_REPLY_STATUS_NO_EXCEPTION;
    }
    else if (operation == get) {
      Maestro_CORBA_Long value;
      Maestro_CORBA_Short n, m;
      
      request >> n >> m;
      //cout << "n = " << n << endl;
      //cout << "m = " << m << endl;
      
      value = grid[10*n + m];
      //cout << "returning value: " << value << endl;
      
      reply << value;
      return MAESTRO_GIOP_REPLY_STATUS_NO_EXCEPTION;
    }
    else {
      cerr << "Grid: unknown operation: " << operation.s << endl;
      Maestro_CORBA_String exc_name("SystemException");
      Maestro_CORBA_Exception exc(exc_name, 
				  MAESTRO_CORBA_EXCEPTION_CODE_BAD_OPERATION,
				  MAESTRO_CORBA_COMPLETION_STATUS_NO);
      reply << exc;
      return MAESTRO_GIOP_REPLY_STATUS_SYSTEM_EXCEPTION;
    }
  }

 virtual void pushState(Maestro_CORBA_Message &msg)
  {
    cerr << "XFER: pushState: " << endl;

    int row, col;
    for (row = 0; row < 10; row++) {
      for (col = 0; col < 10; col++) {
	cout << grid[10*row + col] << " ";
      }
      cout << endl;
    }
    msg.write(grid, sizeof(Maestro_CORBA_Long) * 100);
  }

 virtual void getState(Maestro_CORBA_Message &msg)
  {
    cerr << "XFER: getState: " << endl;
    msg.read(grid, sizeof(Maestro_CORBA_Long) * 100);

    int row, col;
    for (row = 0; row < 10; row++) {
      for (col = 0; col < 10; col++) {
	cout << grid[10*row + col] << " ";
      }
      cout << endl;
    }
  }

  Maestro_CORBA_Long *grid;
  Maestro_CORBA_String height, width, set, get, set_str, get_str;
  char str[1024 * 10];
};


main(int argc, char *argv[]) {
  // Create an ORB dispatcher.
  Maestro_ORB_IIOPDispatcher dispatcher;

  // Create an ORB.
  Maestro_SimpleORB_Options orb_ops;
  orb_ops.dispatcher = &dispatcher;
  orb_ops.installIOR = 1;
  orb_ops.etc = &Maestro_DefaultEtc;
  orb_ops.ORBName = "Grid";

  Maestro_ES_SimpleORB orb(orb_ops);

  // Create an object (it automatically binds to the specified ORB).
  Maestro_SimpleORBObjectAdaptor_Options obj_ops;
  Maestro_CORBA_String keyStr("MAE:049f74f5a791947c345905d2000bf9e40c:grid");
  Maestro_ORB_ObjectKey key(keyStr);
  obj_ops.key = key;
  obj_ops.orb = &orb;
  Grid obj(obj_ops);

  // Create more objects if needed...

  // Activate the ORB.
  orb.activate();

  // Block the main thread.
  Maestro_Semaphore sema;
  sema.dec();
}
