package ensemble.hot;

import java.util.*;


public class Hot_GroupContext {
    private static int idCount = 0;
    private static Vector allGctx = new Vector();
    public int id;
    public Hot_Endpoint[] view;
    public Hot_GroupContext next;
    public Hot_Callbacks conf;
    public Object env;
    public boolean group_blocked;
    public boolean joining;
    public boolean leaving;
    public int ltime;
	
    private Hot_GroupContext() {
	id = 0;
	view = null;
	group_blocked = false;
	joining = false;
	leaving = false;
    }

    public synchronized static Hot_GroupContext Alloc() {
	Hot_GroupContext gctx = new Hot_GroupContext();
	gctx.id = idCount++;
	allGctx.addElement(gctx);
	return gctx;	
    }
	
    public synchronized static void Release(Hot_GroupContext gc) {
	// delete this one from the Vector
	allGctx.removeElement(gc);
    }
	
    public synchronized static Hot_GroupContext Lookup(int id) {
	// should use a hash table rather than a vector, but....
	Hot_GroupContext gc = null;
	for (int i = 0;i < allGctx.size();i++) {
	    gc = (Hot_GroupContext)allGctx.elementAt(i);
	    if (gc.id == id) {
		return gc;
 	    }
	}
	String s = "lookup_gctx: id not found!! (" + id + ")";
	Hot_Ensemble.Panic(s);
	return null;
    }


    public String toString() {
	StringBuffer ret=new StringBuffer();
	ret.append("id=" + id + ", group_blocked=" + group_blocked + 
		   ", joining=" + joining + ", leaving=" + leaving); 
	return ret.toString();
    }

}
