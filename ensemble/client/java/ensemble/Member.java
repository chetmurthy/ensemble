package ensemble;

/** A group member */
public class Member 
{
    /** The current member status */
    /** the initial status */
    static public final int Pre = 0;       

    /** we joining the group */
    static public final int Joining = 1;

    /** Normal operation state, can send/mcast messages */
    static public final int Normal= 2;

    /** we are blocked */
    static public final int Blocked = 3;

    /** we are leaving */
    static public final int Leaving = 4;

    /** We have left the group and are in an invalid state */
    static public final int Left = 5;
    
    /** The current view */
    public View current_view ;		   

    /** Our current status */
    public int current_status = Pre; 
    
    int id = -1;                // The group id
    private Connection conn =  null;

    static public String StatusToString(int status) throws EnsembleException
    {
	switch(status) {
	case Pre:
	    return "Pre";
	case Joining:
	    return "Joining";
	case Normal:
	    return "Normal";
	case Blocked:
	    return "Blocked";
	case Leaving:
	    return "Leaving";
	case Left:
	    return "Left";
	}

	throw new EnsembleException("bad case in StatusToString:");
    }
    
    public Member(Connection conn) 
    {
	this.conn = conn;
    }
    
   
    /** Join a group 
     * @param ops  The join options passed to Ensemble.
     */
    public void Join(JoinOps ops) throws EnsembleException
    {
	conn.Join(this, ops);
    }
    
    /** Leave a group.  This should be the last call made to a given context.
     * No more events will be delivered to this context after the call returns.  
     */
    public void Leave() throws EnsembleException
    {
	conn.Leave(this);
    }
    
    /** Send a multicast message to the group.
     * @param data  The data to send.
     */
    public void Cast(byte[] data) throws EnsembleException
    {
	conn.Cast(this, data);
    }
    
    /** Send a point-to-point message to a list of members.
     * @param dests The set of destinations
     * @param data  The data to send.
     */
    public void Send(int[] dests, byte[] data) throws EnsembleException
    {
	conn.Send(this, dests, data);
    }
    
    /** Send a point-to-point message to the specified group member.
     * @param dest The destination. 
     * @param data  The data to send.
     */
    public void Send1(int dest, byte[] data) throws EnsembleException
    {
	conn.Send1(this, dest, data);
    }
    
    /** Report group members as failure-suspected. 
     * @param suspects The set of suspects.
     */
    public void Suspect(int[] suspects) throws EnsembleException
    {
	conn.Suspect(this, suspects);
    }
    
    /**  Send a BlockOk */
    public void BlockOk() throws EnsembleException
    {
	conn.BlockOk(this);
    }
}
