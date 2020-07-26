package ensemble;

/**
 * The set of information contained in a view. 
 */
public class View {
    public int nmembers;
    public String version;     /** The Ensemble version */
    public String group;       /** group name  */
    public String proto;       /** protocol stack in use  */
    public int ltime;          /** logical time  */
    public boolean primary;    /** this a primary view?  */
    public String parameters;  /** parameters used for this group  */
    public String[] address;   /** list of communication addresses  */
    public String[] endpts;    /** list of endpoints in this view  */
    public String endpt;       /** local endpoint name  */
    public String addr;        /** local address  */
    public int rank;           /** local rank  */
    public String name;        /** My name. This does not change thoughout the lifetime of this member. */
    public ViewId view_id;     /** view identifier */
}

