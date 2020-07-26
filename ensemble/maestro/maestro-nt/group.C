/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include "Maestro_Group.h"


Maestro_Lock mutex;
int groupIsBlocked;
Maestro_EndpList groupMembers;
int myRank;


class MyGroupListener: public Maestro_GroupListener {
public:

  MyGroupListener() { myState = 0; }
  int c;

  /* Added this to MyGroupListener */
  int myState;

  void getState(/*OUT*/ Maestro_Message &stateMsg) const
  {
    cout << "GET STATE" << endl;
    stateMsg << myState;
    cout << "STATE is " << myState << endl;
  }

  void setState(/*IN*/ Maestro_Message &stateMsg)
  {
    cout << "SET STATE" << endl;
    stateMsg >> myState;
    cout << "*** Set state to " << myState << endl;
  }

  void receivedSend(Maestro_EndpID &sender, Maestro_Message &msg)
  {
    myState++;
    msg >> c;
    cout << myState << " = " << (char) c << "\n";
  }

  void receivedCast(Maestro_EndpID &sender, Maestro_Message &msg)
  {
    myState++;
    msg >> c;
    cout << myState << " = " << (char) c << "\n";
  }

  void receivedLsend(Maestro_EndpID &sender, Maestro_Message &msg)
  {
    myState++;
    msg >> c;
    cout << myState << " = " << (char) c << "\n";
  }

  void receivedScast(Maestro_EndpID &sender, Maestro_Message &msg)
  {
    myState++;
    msg >> c;
    cout << myState << " = " << (char) c << "\n";
  }

  void acceptedView(Maestro_ViewData &view)
  {
    cout << "VIEW" << endl;
    cout << "members: " << endl << view.members << endl;
    cout << "servers: " << endl << view.servers << endl;
    cout << "clients: " << endl << view.clients << endl;

    mutex.lock();
    groupIsBlocked = 0;
    groupMembers = view.members;
    myRank = view.myRank;
    mutex.unlock();
  }

  void blocked()
  {
    cout << "BLOCKED" << endl;
    mutex.lock();
    groupIsBlocked = 1;
    mutex.unlock();
  }
};


int main(int argc, char **argv) {
  Maestro_GroupOptions ops;
  ops.groupName = "lapa";
  ops.serverFlag = ((argc > 1) && (argv[1][0] = 's'));
  ops.properties = "Total:Gmp:Sync:Heal:Switch:Frag:Suspect:Flow";

  cout << ((ops.serverFlag) ?
	   "Joining as a SERVER" : "Joining as a CLIENT") << endl;

  MyGroupListener listener;
  Maestro_Group *group = new Maestro_Group(listener, ops);

  int c = 'A';

  while (1) {
    Maestro_Message msg;

    mutex.lock();
    if (!groupIsBlocked) {
      msg << c;
      c  = ((c == 'Z') ? 'A' : (c + 1));
      group->cast(msg);

      msg.reset();
      msg << c;
      c  = ((c == 'Z') ? 'A' : (c + 1));
      group->scast(msg);
    }
    mutex.unlock();
#ifdef WIN32
    Sleep(2);
#else
    sleep(2);
#endif
  }

  delete group;
  return 0;
}
