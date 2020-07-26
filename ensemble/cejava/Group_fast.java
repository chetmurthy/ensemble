package ensemble;

import java.io.*;
import java.lang.*;
import java.util.*;

/** An Ensemble Process Group.
 *
 * This class provides a Java wrapper to an Ensemble process group.
 * A group is constructed by providing a set of callbacks performed by
 * Ensemble when certain events occur:
 * <ul>
 * <li> Receipt of a multicast message
 * <li> Receipt of a point-to-point message
 * <li> A membership (<i>view</i>) change occurs
 * <li> etc.
 * </ul>
 *
 * The actions supported on a group are:
 * <ul>
 * <li> Join: Joining a group
 * <li> Leave: Leaving a group
 * <li> Cast: Multicasting a message
 * <li> Send: Sending a point-to-point message to several destinations
 * <li> Send1: Sending a point-to-point message to a single destination
 * <li> Prompt: Asking for a view-change
 * <li> Suspect: Suspecting a list of members, and asking for their removal
 * <li> XferDone: Support for state-transfer, the local group member
 *      has completed its state-transfer protocol.
 * <li> Rekey: requesting a rekey
 * <li> ChangeProtocol: requesting a change in the group-communication stack 
 * <li> ChangeProperties: dito
 * </ul>
 */
public class Group
{
    
    /********************************************************************/
    /* Low level CE calls
     */
    static native void natInit(String[] args);
    native long natJoin(JoinOps jops);
    native void natLeave(long group);
    native void natCast(long group, byte[] msg);
    native void natSend(long group, int[] dests, byte[] msg);
    native void natSend1(long group, int dest, byte[] msg);
    native void natPrompt(long group);
    native void natSuspect(long group, int[] suspects);
    native void natXferDone(long group);
    native void natRekey(long group);
    native void natChangeProtocol(long group, String protocol_name);
    native void natChangeProperties(long group, String properties);
    
    /********************************************************************/
    
    public long nat_env = 0;  // A pointer to the CE environment 
    private Callbacks cb = null;
    
    /********************************************************************/
    public Group(Callbacks cb){
	if (cb == null) {
	    System.out.println("Group constructor, callbacks are null");
	    System.exit(0);
	}
	this.cb = cb;
    }
    
    /** Join a group.
     *
     * @param jops   The join options passed to Ensemble.
     */
    public void join(JoinOps jops) {
	nat_env = natJoin(jops);
    }
    
    /** Leave a group. After performing the call, no other actions are
     *  allowed for this group. You may not send/cast/etc. to this group.
     */
    public void leave() {
	natLeave(nat_env);
    }
    
    /** Multicast a message to the group.
     *
     * @param msg  The message body	
     */
    public void cast(byte[] msg) {
	natCast(nat_env, msg);
    }
    
    /** Send a point-to-point message to a list of group members.
     *
     * @param dests  An array of destinations
     * @param msg    The message body	
     */
    public void send(int[] dests, byte[] msg) {
	natSend(nat_env, dests, msg);
    }
    
    /** Send a point-to-point message to a sinle member.
     *
     * @param dest   The destination rank
     * @param msg    The message body	
     */
    public void send1(int dest, byte[] msg) {
	natSend1(nat_env, dest, msg);
    }
    
    /** Ask Ensemble to perform a View change.
     */
    public void prompt() {
	natPrompt(nat_env);
    }
    
    /** Tell Ensemble you suspect a list of members. These members
     * will be removed in the next view.
     * 
     * @param suspects the list of suspected members
     */
    public void suspect(int[] suspects) {
	natSuspect(nat_env, suspects);
    }
    
    /** Inform Ensemble that state-transfer has been completed at this group
     * member. This requires that the Xfer layer is in the stack. 
     */
    public void xferDone() {
	natXferDone(nat_env);
    }
    
    /** Request a rekey.
     */
    public void rekey() {
	natRekey(nat_env);
    }
    
    /** Request a change of the group-communication stack.
     * 
     * 	@param protocol_name The new protocol
     */
    public void changeProtocol(String protocol_name) {
	natChangeProtocol(nat_env, protocol_name);
    }
    
    /** Request a change of the group-communication stack. The requested
     * set of properties is provided. 
     * 
     * 	@param properties The new properties
     */
    public void changeProperties(String properties) {
	natChangeProperties(nat_env, properties);
    }
    
    /********************************************************************/
    /* The callbacks
     */
    
    /* TODO: add view_ids and security key
     */
    private void install(View view) {
	//	if (status == PRE || status == JOINING || status == BLOCKED)
	//	    status = NORMAL;
	//	System.out.println("JAVA: install");
	cb.install(view);
    }
    
    private void exit() {
	//	System.out.println("JAVA: exit");
	//	System.out.flush();
	//	status = PRE ;
	cb.exit();
    }
    
    private void recv_cast(int origin, byte[] msg) {
	//	System.out.println("JAVA recv_cast: "+new String(msg)+" from "+origin);
	//	System.out.flush();
	cb.recv_cast(origin, msg);
    }
    
    private void recv_send(int origin, byte[] msg) {
	//	System.out.println("JAVA recv_send: "+new String(msg)+" from "+origin);
	//	System.out.flush();
	cb.recv_send(origin, msg);
    }
    
    private void flow_block(int rank, boolean onoff) {
	//	System.out.println("JAVA: flow_block"); System.out.flush();
	//	System.out.flush();
	cb.flow_block(rank, onoff);
    }
    
    private void block() {
	//	System.out.println("JAVA: block"); System.out.flush();
	//	System.out.flush();
	//status = BLOCKED;
	cb.block();
    }
    
    private void heartbeat(double time) {
	//	System.out.println("JAVA: heartbeat " + time); System.out.flush();
	//	System.out.flush();
	cb.heartbeat(time);
    }
    
    static {
	System.loadLibrary("cejava");
    }


    /** Initialize the low-level Ensemble C-library.
     *
     * @param args  The list of command line arguments
     */
    static public void init(String args []) {
	//System.out.println("args= " + java.util.Arrays.asList(args));
	//System.out.flush();
	natInit(args); 
    }
}

