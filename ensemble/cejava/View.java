package ensemble;

/** A group view. */
public class View {

    //*******************************************************************
    // ViewState

    /** The Ensemble version
     */
    public String version;

    /** The protocol stack in use
     */
    public String proto;

    /** The coordinator's rank
     */
    public int coord;

    /** The logical time
     */
    public int ltime;


    /** Is this a primary view?
     */
    public boolean primary;


    /** Are we using the group-daemon
     */
    public boolean groupd;


    /** Is this a state-transfer view?
     */
    public boolean xfer_view;


    /** The parameters used for this group
     */
    public String params;

    /** The time this group has been up and running
     */
    public double uptime;

    /** The list of endpoints in this view
     */
    public String[] view;

    /** This list of communication addresses
     */
    public String[] address;

    //*******************************************************************
    // local

    /** The local endpoint name
     */
    public String endpt;

    /** The local address
     */
    public String addr;

    /** The local rank
     */
    public int rank;

    /** The group name. This does not change thoughout the lifetime of
     * the group.
     */
    public String name;

    /** The number of members in the view
     */
    public int nmembers;

    /** Am I the coordinator?
     */
    public boolean am_coord;
    
    //*******************************************************************

    View(String version , String proto ,
	 int coord, int ltime, boolean primary,
	 boolean groupd, boolean xfer_view, 
	 String params, double uptime,
	 String[] view, String[] address,
	 // LocalState
	 String endpt, String addr,
	 int rank, String name,
	 int nmembers, boolean am_coord){
	this.version  = version;
	this.proto = proto;
	this.coord = coord;
	this.ltime = ltime;
	this.primary = primary ;
	this.groupd = groupd;
	this.xfer_view = xfer_view;
	this.params = params ;
	this.uptime = uptime;
	this.view = view;
	this.address = address ;
	this.endpt = endpt;
	this.addr = addr;
	this.rank = rank ;
	this.name = name;
	this.nmembers = nmembers ;
	this.am_coord = am_coord;
    }
}
