/**************************************************************/
/* Hot_Callbacks.java */
/* Author: Jason Dale */
/**************************************************************/

package ensemble.hot;

public interface Hot_Callbacks {

    /* Called when EJava receives a cast of a serialized Object 
     * from another EJava app (the default).
     */
    public abstract void ReceiveCast(Hot_GroupContext gctx, Object env, 
					Hot_Endpoint origin, Hot_Message msg);

    /* New function to receive a cast of a byte stream from another
     * app (typically HOT or Maestro) but can also be used by another
     * EJava app if the cast was sent with handleCastByteStream()
     */
    public void ReceiveCastByteStream(Hot_GroupContext gctx, Object env, 
				Hot_Endpoint origin, Hot_Message msg);

    /**
    Called when Ensemble receives a point-to-point message for you
    */
    public abstract void ReceiveSend(Hot_GroupContext gctx, Object env, 
					Hot_Endpoint origin, Hot_Message msg);

    /**
    Called to update you with the new view
    */
    public abstract void AcceptedView(Hot_GroupContext gctx, Object env, 
					Hot_ViewState viewState);

    /**
    Called to issue you a heartbeat
    */
    public abstract void Heartbeat(Hot_GroupContext gctx, Object env, int rate);


    /**
    Called to let you know Ensemble is blocking
    */
    public abstract void Block(Hot_GroupContext gctx, Object env);


    /**
    Called upon an Exit
    */
    public abstract void Exit(Hot_GroupContext gctx, Object env);

}

