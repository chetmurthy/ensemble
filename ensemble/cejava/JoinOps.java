package ensemble;
    
/** JoinOps binds together the list of properties requested from
 * a Group when it is created. 
 */
public class JoinOps {
    public static final String DEFAULT_PROPERTIES =
	"Gmp:Sync:Heal:Frag:Suspect:Flow:Slander";

    /** The rate of heartbeats provided. Every xxx time,
     * the {@link Callbacks#heartbeat(double)} callback will be called with the
     * current time.
     */
    public double hrtbt_rate = 10.0;

    /** What is the requested transport layer. At the time of
     * writing the supported list was is [Multicast, UDP, TCP].
     */
    public String transports = "UDP";

    /** The group-communication stack to be used. 
     */
    public String protocol = "";

    /** The group name. 
     */
    public String group_name = null;

    /** The requsted list of properties.
     */
    public String properties = DEFAULT_PROPERTIES;

    /** Both properties and protocol can be used to determine the stack.
     * use_properties arbiterates between them.
     */
    public boolean use_properties = true;

    /** Use the group-daemon server?
     */
    public boolean groupd = false;

    /** Specific parameters to pass to Ensemble.
     */
    public String params = null;

    public boolean client = false;

    /** use a debugging stack?
     */
    public boolean debug = false;

    /** Coose the endpoint name
     */
    public String endpt = "";

    /** The principal name
     */
    public String princ = "";

    /** Use a secure stack?
     */
    public boolean secure = false;
}
