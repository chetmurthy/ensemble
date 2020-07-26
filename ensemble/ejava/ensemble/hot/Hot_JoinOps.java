package ensemble.hot;

public class Hot_JoinOps {
    public int heartbeat_rate;
    public String transports;
    public String group_name;
    public String protocol;
    public String properties;
    public boolean use_properties;
    public String params;
    public boolean groupd;
    public Hot_Callbacks conf;
    public Object env;
    public String[] argv;
    public boolean debug;
    public boolean client;
    public String princ;
    public String key;
    public boolean secure;

    public String outboard;

    public Hot_JoinOps() {
	heartbeat_rate = 5000;
	transports = "UDP";
	protocol = "Top:Heal:Switch:Leave:Inter:Intra:Elect:Merge:Sync:Suspect:Top_appl:Pt2pt:Frag:Stable:Mnak:Bottom";
	group_name = "<Ensemble_Default_Group>";
	properties = "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow";
	params = "";	// IS THIS RIGHT????
	use_properties = true;
	groupd = false;
	argv = null;
	env = null;
	client = false;
	princ = "";
	key = "";
	secure = false;
    }

// End class Hot_JoinOps
}
