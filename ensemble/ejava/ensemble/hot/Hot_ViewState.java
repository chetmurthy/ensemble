package ensemble.hot;

public class Hot_ViewState {
    public String version;
    public String group_name;
    public Hot_Endpoint[] members;
    public int nmembers;
    public int rank;
    public String protocol;
    public boolean groupd;
    public Hot_ViewID view_id;
    public String params;
    public boolean xfer_view;
    public boolean primary;
    public boolean[] clients;

    public String toString() {
	StringBuffer ret=new StringBuffer();
	ret.append("viewID= " + view_id + ", rank=" + rank + ", group_name=" + 
		   group_name + ", nmembers=" + nmembers + ", members=");
	for(int i=0; i < members.length; i++)
	    ret.append((Hot_Endpoint)members[i] + " ");
	return ret.toString();
    }

}
