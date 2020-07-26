// $Header: /cvsroot/ensemble/maestro/src/group/Maestro_Prim.h,v 1.5 2002/10/13 10:06:41 orodeh Exp $

#ifndef __MAESTRO_PRIM_H__
#define __MAESTRO_PRIM_H__

/************************************************************************
 *                                                                      *
 * Author:  Alexey Vaysburd  August 97                                  *
 *                                                                      *
 * Contents:  Definition of Maestro_Prim class (primary-partition mode) *
 *                                                                      *
 * Maestro_Prim delivers only primary views where state transfer has    *
 * completed.  It is assumed that all members will join the group       *
 * as servers.                                                          *
 ************************************************************************/

#pragma interface
#include "Maestro_CSX.h" 

static void trace(char *s);

class Maestro_Prim;

typedef Maestro_CSX_Options Maestro_Prim_Options;
typedef Maestro_CSX_ViewData Maestro_Prim_ViewData;
typedef Maestro_CSX_MsgOptions Maestro_Prim_MsgOptions;

typedef enum {
    MAESTRO_PRIM_MSG_SEND,
    MAESTRO_PRIM_MSG_CAST,
    MAESTRO_PRIM_MSG_SCAST,
    MAESTRO_PRIM_MSG_LSEND
} Maestro_PrimMsgType;

struct Maestro_Prim_DelayedMessage : public Maestro_Base {
    Maestro_Prim_DelayedMessage() {}
    ~Maestro_Prim_DelayedMessage() {}

    Maestro_Prim_DelayedMessage(Maestro_PrimMsgType type, 
				Maestro_EndpID &dst, 
				Maestro_Message &delayed_msg,
				Maestro_Prim_MsgOptions mops) {
	msg <<= delayed_msg;
	msgType = type;
	msgOps = mops;
	dest = dst;
    }
    
    Maestro_Prim_DelayedMessage(Maestro_PrimMsgType type, 
				Maestro_Message &delayed_msg,
				Maestro_Prim_MsgOptions mops) {
	msg <<= delayed_msg;
	msgType = type;
	msgOps = mops;
    }
    
    int operator ==(Maestro_Prim_DelayedMessage &dm) { return 0; }
    
    Maestro_EndpID dest;
    Maestro_Message msg;
    Maestro_PrimMsgType msgType;
    Maestro_Prim_MsgOptions msgOps;
};

typedef Maestro_OrderedSet(Maestro_Prim_DelayedMessage)
  Maestro_Prim_DelayedMessageList;

class Maestro_Prim : public Maestro_CSX {
public:
    Maestro_Prim(Maestro_Prim_Options &ops);
    
    Maestro_Prim(Maestro_Prim &mprim);
    virtual ~Maestro_Prim();
    virtual Maestro_Prim& operator= (Maestro_Prim &mprim);

    // Sending messages:

    MAESTRO_INLINE virtual void cast(Maestro_Message &msg);

    MAESTRO_INLINE virtual void cast(Maestro_Message &msg, 
				     Maestro_MsgSendView &sendView);    

    MAESTRO_INLINE virtual void cast(Maestro_Message &msg, 
				     Maestro_MsgSendView &sendView,
				     Maestro_ClSv_MsgOptions &msgOps);  
    
    MAESTRO_INLINE virtual void send(Maestro_EndpID &dest, 
				     Maestro_Message &msg);  

    MAESTRO_INLINE virtual void send(Maestro_EndpID &dest, 
				     Maestro_Message &msg, 
				     Maestro_MsgSendView &sendView);

    MAESTRO_INLINE virtual void send(Maestro_EndpID &dest, 
				     Maestro_Message &msg,
				     Maestro_MsgSendView &sendView,
				     Maestro_ClSv_MsgOptions &msgOps);
    
    MAESTRO_INLINE virtual void scast(Maestro_Message &msg);

    MAESTRO_INLINE virtual void scast(Maestro_Message &msg, 
				      Maestro_MsgSendView &sendView);

    MAESTRO_INLINE virtual void scast(Maestro_Message &msg, 
				      Maestro_MsgSendView &sendView,
				      Maestro_ClSv_MsgOptions &msgOps);
    
    MAESTRO_INLINE virtual void lsend(Maestro_Message &msg, 
				      Maestro_MsgSendView &sendView,
				      Maestro_ClSv_MsgOptions &msgOps);  
    
    void join();
    void leave();
    
protected:
    
    // View callbacks:
    
    virtual void prim_ViewMsg_Callback(Maestro_Prim_ViewData &viewData, 
				       /*OUT*/ Maestro_Message &viewMsg) {}
    
    virtual void prim_AcceptedView_Callback(Maestro_Prim_ViewData& viewData,
					    Maestro_Message &msg) {}

    // Disconnection callback:
    // (invoked when view size shrinks below the quorum level).

    virtual void prim_PrimarityLost_Calllback(Maestro_Prim_ViewData& viewData) {
	error->panic("Maestro_Prim:  Quorum is lost (%d members in the view, quorum = %d); exiting", viewData.nGrpMembers, quorumSize);
    }

    // Message callbacks:
    
    virtual void prim_ReceiveCast_Callback(Maestro_EndpID &origin, 
					   Maestro_Message &msg)  {}
    
    virtual void prim_ReceiveScast_Callback(Maestro_EndpID &origin, 
					    Maestro_Message &msg) {}
    
    virtual void prim_ReceiveSend_Callback(Maestro_EndpID &origin, 
					   Maestro_Message &msg)  {}
    
    virtual void prim_ReceiveLsend_Callback(Maestro_EndpID &origin, 
					    Maestro_Message &msg) {}
    
    // Heartbeat callback:
    
    virtual void prim_Heartbeat_Callback(unsigned time) {}
    
    // The group is blocked for a view change:
    
    virtual void prim_Block_Callback() {}
    
    // The member has left the group:
    
    virtual void prim_Exit_Callback() {}
    
    // State transfer callbacks:  
    virtual void askState_Callback(Maestro_EndpID &origin, 
				   Maestro_XferID &xferID,
				   Maestro_Message &requestMsg) {}
    
    virtual void stateTransfer_Callback(Maestro_XferID &xferID) { 
	xferDone(xferID); 
    }
    
    // State transfer callbacks (async mode):
    
    virtual void gotState_Callback(Maestro_XferID &xferID,
				   Maestro_Message &stateMsg) {}
    
    virtual void xferCanceled_Callback(Maestro_XferID &xferID) {}
    
private:
    
    /************************* Callbacks ************************************/
    
    // View callbacks:
    
    void csx_ViewMsg_Callback(Maestro_Prim_ViewData &viewData, 
			      /*OUT*/ Maestro_Message &viewMsg);
    
    MAESTRO_INLINE void csx_AcceptedView_Callback(
	Maestro_Prim_ViewData& viewData,
	Maestro_Message &viewMsg);
    
    // Message callbacks:
    
    void csx_ReceiveCast_Callback(Maestro_EndpID &origin, 
				  Maestro_Message &msg) {
	prim_ReceiveCast_Callback(origin, msg);
    }
    
    void csx_ReceiveScast_Callback(Maestro_EndpID &origin, 
				   Maestro_Message &msg) {
	prim_ReceiveScast_Callback(origin, msg);
    }
    
    void csx_ReceiveSend_Callback(Maestro_EndpID &origin, 
				  Maestro_Message &msg) {
	prim_ReceiveSend_Callback(origin, msg);
    }
    
    void csx_ReceiveLsend_Callback(Maestro_EndpID &origin, 
				   Maestro_Message &msg) {
	prim_ReceiveLsend_Callback(origin, msg);
    }
    
    
    // Heartbeat callback:
    
    void csx_Heartbeat_Callback(unsigned time) { 
//	trace("heartbeat");
	prim_Heartbeat_Callback(time); 
    }
    
    // The member has left the group:
    
    void csx_Exit_Callback() { prim_Exit_Callback(); }
    
    // The group is blocked for a view change:
    
    void csx_Block_Callback();

    // Messages delayed while state transfer is in progress or the view is
    // not primary.
    Maestro_Prim_DelayedMessageList delayedMsgs;
    Maestro_Lock primLock;
    Maestro_Semaphore joinSema;
    int quorumSize;
    enum {
	PRIM_BOGUS,	        // undefined state
	PRIM_JOINING,	        // we didn't install a primary view yet
	PRIM_PRIMARY,		// we have a primary view; can send messages
	PRIM_BLOCKED,		// view change/state transfer is in progress
	PRIM_LEAVING		// we are leaving; no more messages
    } state;
};

#endif // __MAESTRO_PRIM_H__
