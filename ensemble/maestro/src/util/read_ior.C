/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include "Maestro_IIOPBridge.h"
#include "Maestro_ETC.h"
#include "Maestro_ORB.h"

main(int argc, char* argv[]) {
  if (argc < 2) {
    cerr << "Usage: " << argv[0] << " <ior filename>" << endl;
    exit(1);
  }

  // Extract IOR from stringified representation.
  Maestro_String fname(argv[1]);
  Maestro_CORBA_String repres;
  Maestro_DefaultEtc.lookup(fname, repres);
  cout << "Looked up string: " << endl << repres.s << endl;

  Maestro_IOP_IOR ior;
  ior << repres;

  cout << "type_id = " << ior.type_id.s << endl;

  Maestro_IOP_TaggedProfileList profList;
  profList = ior.profiles;
  cout << "There are " << profList.size() << " profiles in the IOR" << endl;
  
  int i;
  for (i = 0; i < profList.size(); i++) {
    cout << "------------- Profile " << i << " ---------------" << endl;
    Maestro_IOP_TaggedProfile &profile = profList[i];
    Maestro_CORBA_OctetSequence &pbody_encaps = profile.profile_data;
    cout << "Profile tag is " << profile.tag << endl;
  
    Maestro_IIOP_ProfileBody pbody;
    pbody.readFrom(pbody_encaps);
    cout << "IIOP Profile body: " << endl;
    cout << "\tversion: " << (int) pbody.iiop_version.major << "." <<
      (int) pbody.iiop_version.minor << endl;
    cout << "\thost: " << pbody.host.s << endl;
    cout << "\tport: " << pbody.port << endl;

    Maestro_ORB_ObjectKey object_key(pbody.object_key);
    Maestro_CORBA_String str;
    object_key >> str;
    cout << "\tobject key: " << str.s << endl;
  }
}
