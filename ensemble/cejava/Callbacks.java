package ensemble;

/** Callbacks binds together the list of callbacks a group has
 * to implement. Each event is the application "answer" to a specific
 * event.
 */
public interface Callbacks {

    /** A new view has been installed. 
     */
    public abstract void install(View view);

    /** The group is leaving, and this is the final callback to the group.
     */
    public abstract void exit();

	/** A message has been received from the indicated origin.
	 *
	 * @param origin message origin
	 * @param msg    message body
	 */
    public abstract void recv_cast(int origin, byte[] msg);

   /** A message has been received from the indicated origin.
	 * 
	 * @param origin message origin
	 * @param msg    message body
	 */
    public abstract void recv_send(int origin, byte[] msg);

    /** Too many messages are being sent to a specific destination, 
     * or to the whole group.
     *
     * @param rank   the member to which we need to stop sending messages.
     *               (-1) for multicast traffic.
     * @param onoff  Should we stop (true), or continue (false)
     */
    public abstract void flow_block(int rank, boolean onoff);

    /** The group is blocked in preparation for a view-change. Stop sending
     * messages until the {@link #install} callback.
     */
    public abstract void block();

    /** Every predetemined timeout, this callback is invoked with the
     * current time. 
     */
    public abstract void heartbeat(double time);
}
