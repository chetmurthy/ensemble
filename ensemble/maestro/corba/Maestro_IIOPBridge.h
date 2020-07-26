// $Header: /cvsroot/ensemble/maestro/corba/Maestro_IIOPBridge.h,v 1.1 2003/04/26 13:38:31 orodeh Exp $
// 
// Implementation of IIOP Bridge:  Client and Server sides.
//
// Author:  Alexey Vaysburd, Sept. 1997.

#ifndef __MAESTRO_IIOPBRIDGE_H__
#define __MAESTRO_IIOPBRIDGE_H__

#include "Maestro_CORBA.h"
#include "Maestro_GIOP.h"
#include "Maestro_Perf.h"


/******************************* IIOP Bridge ********************************/

const unsigned MASTRO_SELECT_TV_SEC = 0;
const unsigned MASTRO_SELECT_TV_USEC = 500000;

class Maestro_IIOP_BridgeBase:
  virtual public Maestro_Base
{
public:
  Maestro_IIOP_BridgeBase(); 
protected:
  unsigned msgHdrSize;		// size of GIOP message header.
};

class Maestro_IIOP_Server;
class Maestro_IIOP_Connection;

typedef Maestro_ULong Maestro_IIOP_ConnId;


/*************************** Maestro_IIOP_ConnRef ***************************/

class Maestro_IIOP_ConnRef: 
  virtual public Maestro_Base
{
public:

  Maestro_IIOP_ConnRef() {}
  Maestro_IIOP_ConnRef(Maestro_IIOP_ConnId cid_,
		       Maestro_IIOP_Connection *conn_);
  
  Maestro_IIOP_ConnRef(Maestro_IIOP_ConnRef &cr);
  int operator== (Maestro_IIOP_ConnRef &cr) { return (_cid == cr._cid); }
  Maestro_IIOP_ConnId id() { return _cid; }
  Maestro_IIOP_Connection *conn() { return _conn; }

private:
  
  Maestro_IIOP_ConnId _cid;
  Maestro_IIOP_Connection *_conn;
};

typedef Maestro_OrderedSet(Maestro_IIOP_ConnRef) 
  Maestro_IIOP_ConnRefList_Base;


/********************** Maestro_IIOP_ConnRefList ***************************/

// Maestro_IIOP_ConnRefList:  List of active connections.  
class Maestro_IIOP_ConnRefList {
public:

  Maestro_IIOP_ConnRefList() {}
  ~Maestro_IIOP_ConnRefList() { closeAll(); }

  // Close all active connections.
  void closeAll();

  // Add a connection to the active list.
  void add(Maestro_IIOP_Connection *conn);

  // Remove a connection from the active list.
  void remove(Maestro_IIOP_Connection *conn);
 
  // Get a reference to an active connection.  Increase connection's refcnt.
  // The caller is responsible for unref'ing the connection when done.
  Maestro_IIOP_Connection* ref(Maestro_IIOP_ConnId cid);

private:

  Maestro_IIOP_ConnRefList_Base active;
  Maestro_Lock mutex;
};


/*********************** Maestro_IIOP_Connection ***************************/

class Maestro_IIOP_Connection: 
  virtual public Maestro_Base
{
  friend class Maestro_IIOP_Server;

public:
  
  Maestro_IIOP_Connection(Maestro_IIOP_Server *srv_, 
			  int fd_, 
			  Maestro_IIOP_ConnId connId_);

  ~Maestro_IIOP_Connection();

  // Start dispatching incoming messages.
  virtual void start() { Maestro_Thread::create(dispatcher, this); }

  // Close this connection.  
  // Eventually the connection object will be deleted.
  void close(); 

  // Write mutex should be used to avoid interleaving of messages when
  // writing from multiple threads.
  void acquireWriteMutex(); 
  void releaseWriteMutex();
  
  // Increase reference count.
  void ref(); 

  // Decrease reference count.  If 0, delete the object.
  void unref(); 

  int fd() { return _fd; }
  Maestro_IIOP_ConnId id() { return connId; }

  // Write to this connection.
  Maestro_Status write(void *buf, unsigned nbytes);
 
  unsigned MAGIC ; 

private:

  // Dispatch incoming messages through the server's callback.
  static void dispatcher(void *arg);
 
  unsigned magic;
  int write_mutex_acquired;
  unsigned refcnt;
  int isOpen;
  Maestro_IIOP_Server *srv;
  int _fd;
  Maestro_ULong connId;
  Maestro_Lock mutex, writeMutex;
  int inside;
};


/*************************** Maestro_IIOP_Reply ***************************/

class Maestro_IIOP_Client;

struct Maestro_IIOP_Reply {
  Maestro_IIOP_Reply(Maestro_GIOP_MsgType msgType,
		       Maestro_IIOP_Client *clt); 

  Maestro_GIOP_MsgType type;
  Maestro_IIOP_Client *client;
  Maestro_CORBA_ULong request_id;
  Maestro_GIOP_ReplyStatusType reply_status;
  Maestro_GIOP_LocateStatusType locate_status;
  Maestro_CORBA_Message msg;
  void *data;
};


/*************************** Maestro_IIOP_Client ***************************/

class Maestro_IIOP_Client: 
  virtual public Maestro_IIOP_BridgeBase
{
public:
  
  Maestro_IIOP_Client(Maestro_String host, unsigned short port);
  ~Maestro_IIOP_Client();
  
  /************************* IIOP downcalls **************************/

  virtual Maestro_Status request(Maestro_CORBA_Boolean response_expected,
				 Maestro_CORBA_OctetSequence &object_key,
				 Maestro_CORBA_String &operation,
				 Maestro_CORBA_Message &request_body,
				 /*OUT*/ Maestro_CORBA_ULong &request_id);
  
  virtual Maestro_Status locateRequest(
          Maestro_CORBA_OctetSequence &object_key,
          /*OUT*/ Maestro_CORBA_ULong &request_id);

  virtual Maestro_Status cancelRequest(Maestro_CORBA_ULong request_id);

protected:

  /*********************** IIOP message callbacks **************************/

  // Default implementation is no-op.  This should be overloaded in
  // subclasses of Maestro_IIOP_Server as required by the application.

  virtual void reply_Callback(Maestro_CORBA_ULong request_id, 
			      Maestro_GIOP_ReplyStatusType reply_status,
			      Maestro_CORBA_Message &msg) {}

  virtual void locateReply_Callback(
          Maestro_CORBA_ULong request_id, 
	  Maestro_GIOP_LocateStatusType locate_status) {}

  virtual void closeConnection_Callback() {}
  virtual void messageError_Callback() {}

  ///////////////////////////////////////////////////////////////////////////
  
  // Get a reference to the client object.  
  // The client is not deleted until all references are released.
  void ref();

  // Release a reference to the client object.
  // If all references have been released, signal the destructor.
  void unref();
 
  unsigned MAGIC;

private:

  // Connect to the server.
  void connect(char *host, unsigned short port);

  // Read an incoming message and process it in a separate thread.
  void handleIncoming();

  static void dispatcher_Thread(void *arg);

  // Dispatch IIOP Reply message.
  static void reply_Thread(void *arg);

  // Dispatch IIOP LocateReply message.
  static void locateReply_Thread(void *arg);
  
  // Dispatch IIOP MessageError message.
  static void messageError_Thread(void *arg);

  // Dispatch IIOP CloseConnection message.
  static void closeConnection_Thread(void *arg);
 
  //////////////////////////////////////////////////////////////////////////

  Maestro_Lock mutex, writeMutex;
  Maestro_Semaphore sema;
  int closed;
  int refcnt;
  int serverFd;
  unsigned magic;
  enum { ON, OFF } state;
  Maestro_CORBA_ULong requestId;
};


/************************** Maestro_IIOP_Request ***************************/

struct Maestro_IIOP_Request {
  Maestro_IIOP_Request(Maestro_GIOP_MsgType msgType,
		       Maestro_IIOP_Server *srv, 
		       Maestro_IIOP_ConnId id);
 
  Maestro_GIOP_MsgType type;
  Maestro_IIOP_Server *server;
  Maestro_IIOP_ConnId cid;
  Maestro_CORBA_ULong request_id;
  Maestro_CORBA_Boolean response_expected;
  Maestro_CORBA_OctetSequence object_key;
  Maestro_CORBA_String operation;
  Maestro_CORBA_Message msg;
  Maestro_GIOP_Principal requesting_principal;
  void *data;
};


/*************************** Maestro_IIOP_Server ***************************/

class Maestro_IIOP_Server: 
  virtual public Maestro_IIOP_BridgeBase
{
  friend class Maestro_IIOP_Connection;

public:

  Maestro_IIOP_Server(unsigned short port = 0);
  ~Maestro_IIOP_Server();

  virtual void closeConnection(Maestro_IIOP_ConnId cid);
  virtual unsigned short port() { return _port; }

  /********************** IIOP Downcalls ************************/

  virtual Maestro_Status requestReply(
          Maestro_CORBA_ULong request_id,
	  Maestro_GIOP_ReplyStatusType reply_status,
	  Maestro_CORBA_Message &reply_body,
	  Maestro_IIOP_ConnId cid);

  virtual Maestro_Status locateReply(
          Maestro_CORBA_ULong request_id,
	  Maestro_GIOP_LocateStatusType locate_status,
	  Maestro_IIOP_ConnId cid);
 
protected:

  /****************** IIOP message callbacks ***********************/

  // Default implementation is no-op.  This should be overloaded in
  // subclasses of Maestro_IIOP_Server as required by the application.

  virtual void request_Callback(
          Maestro_CORBA_ULong request_id, 
	  Maestro_CORBA_Boolean response_expected,
	  Maestro_CORBA_OctetSequence &object_key,
	  Maestro_CORBA_String &operation,
	  Maestro_GIOP_Principal &requesting_principal,
	  Maestro_CORBA_Message &msg,
	  Maestro_IIOP_ConnId cid) {}

  virtual void locateRequest_Callback(
          Maestro_CORBA_ULong request_id, 
	  Maestro_CORBA_OctetSequence &object_key,
	  Maestro_IIOP_ConnId cid) {} 
  
  virtual void cancelRequest_Callback(
          Maestro_CORBA_ULong request_id, 
	  Maestro_IIOP_ConnId cid) {}

  virtual void messageError_Callback(Maestro_IIOP_ConnId cid) {}


  /*****************************************************************/

  // Bind to the specified port and listen to connection requests.
  void acceptConnections(unsigned short port);
 
  // Get a reference to the server object.  
  // The server is not deleted until all references are released.
  void ref();

  // Release a reference to the server object.
  // If all references have been released, signal the destructor.
  void unref();

  unsigned MAGIC;

  unsigned short _port;

private:

  // Connection objects invoke this method when they close.
  void connectionClosed(Maestro_IIOP_Connection *conn);

  void dispatchIncoming(Maestro_IIOP_Connection *conn); 
 
  // Accept new connections.
  static void connectionListener_Thread(void *arg);
 
  //////////////////////////////////////////////////////////////////////////

  // Dispatch IIOP Request message.
  static void request_Thread(void *arg);

  // Dispatch IIOP CancelRequest message.
  static void cancelRequest_Thread(void *arg);

  // Dispatch IIOP LocateRequest message.
  static void locateRequest_Thread(void *arg);
 
  // Dispatch IIOP MessageError message.
  static void messageError_Thread(void *arg);

  //////////////////////////////////////////////////////////////////////////

  int refcnt;
  unsigned magic;
  int listenFd;			// server listens for connections on this fd.
  int closed;
  Maestro_Semaphore sema;
  Maestro_Lock mutex;
  Maestro_IIOP_ConnRefList *active; // list of active connections.
  int isClosed;			// set to 1 if server is being deleted.
  Maestro_IIOP_ConnId connId;
};

#endif // __MAESTRO_IIOPBRIDGE_H__
