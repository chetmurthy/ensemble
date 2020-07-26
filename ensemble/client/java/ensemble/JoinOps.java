package ensemble;

/**************************************************************/
/** JoinOps binds together the list of properties requested from
 * a Group when it is created. 
 */
public class JoinOps {
    public String group_name = null;  /** group name.   */

    /** The default set of properties */
    public final String DEFAULT_PROPERTIES =
	"Gmp:Switch:Sync:Heal:Frag:Suspect:Flow:Slander";
    /** requsted list of properties.  */    
    public String properties = DEFAULT_PROPERTIES; 

    public String parameters = null;  /** parameters to pass to Ensemble.  */
    public String princ = null;       /** principal name  */
    public boolean secure = false;    /** a secure stack?  */
}
