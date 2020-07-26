import java.util.Random;
import java.util.Vector;
import java.lang.InterruptedException;
import ensemble.hot.*;

public class ThreadTest implements Hot_Callbacks, Runnable {
    Hot_Ensemble he;
    Hot_ViewState vs;
    Hot_GroupContext gctx;
    boolean quitting;   /* quitting flag         */
    boolean started;	/* test has started flag */
    Random rand;	/* random number of casts */
    int quorum;		/* quorum value from cmd line */
    int seq;		/* seq of incoming msgs  */
    boolean blocked;	/* "blocked" flag        */

    public static void main(String[] args) {
	int quorum;

	try {
	    quorum=Integer.parseInt(args[0]);
	    
	    try {
		  // We execute downcalls in a separate thread to trigger
		  // termination bugs. (race with the outboard tcp socket
		  // closing)
		Thread mainThread = new Thread(new ThreadTest(quorum));
		mainThread.start();
		
		mainThread.join();
		Thread.sleep(3000);
	    } catch(InterruptedException e){}

	} catch (Exception e) {
	    trace ("usage: ThreadTest <quorum member>");
	    System.exit(1);
	}
	
	trace("Test successful.");
    }

    ThreadTest(int quorum) {
	quitting = false;
	rand = new Random();
	this.quorum = quorum;

	/* Initialize vars */
	started = false;
	this.seq = 0;
	blocked = false;
    }

      // The starting criterion
    private boolean mayWeStart () {
	return ((vs != null) &&  (vs.nmembers >= quorum));
    }

          // The starting criterion
    private synchronized void waitForStart () {
	trace("Waiting for start");
	try {
	    while (! mayWeStart())
		wait();
	} catch (InterruptedException e) {}
	trace("go!");
    }

    
    public void run () {
	he = new Hot_Ensemble();
	  // he.setDebug(true);

	Thread cbThread = new Thread(he);
	cbThread.start();

	Hot_JoinOps jops = new Hot_JoinOps();
	jops.heartbeat_rate = 5000;
	jops.transports = "UDP";

	  // The fifo vsync stack 
	jops.protocol = "Top:Heal:Switch:Leave:Inter:Intra:Elect:Merge:Sync:Suspect:Top_appl:Pt2ptw:Pt2pt:Frag:Stable:Mnak:Bottom";

	jops.group_name = "ThreadTestGroup";
	jops.params = "suspect_max_idle=3:int;suspect_sweep=3.000:time";
	jops.conf = this;

	Hot_GroupContext[] hgc = new Hot_GroupContext[1];
	Hot_Error hotError = he.Join(jops,hgc);
	gctx = hgc[0];		
	if (hotError != null) {
	    trace("Couldn't join group!!: " + hotError);
	    Hot_Ensemble.Panic("EXITING!!");
	}

	waitForStart ();
	doTest();
	trace("Done!");
	leaving();
    }

    static void trace(String msg){
	System.err.println(msg);
	System.err.flush();
    }


      // ~ Normalize on the [1..max] range
    int getRandom (int max) {
	float k = ((float) max-1)/((float)Integer.MAX_VALUE - (float)Integer.MIN_VALUE);
	float b = 1-k*Integer.MIN_VALUE;
	int value = rand.nextInt();
	return (int)(k*value+b);
    }
    
		   
    synchronized void doTest () {
	String sample[] = {"Sample1","Samp123","S12341234","Sqewpoi","zxcvoiu"};
	int nbRun = getRandom (1000);
	trace("nbRun= " + nbRun);

	/* Test has quorum and has started, set started to true */
	started = true;	
	for (int i = 0; i < nbRun; i++) {

	    /* Since ensemble callbacks are in a separate thread,
	     * we have to check whether ensemble is blocked (recvd a
	     * BLOCK callback) and disable sends until it is cleared.
	     */
            try {
 	        while (blocked == true)
	        {
		    System.out.println("Waiting for block to clear");
		    wait();
		}
	    } catch (InterruptedException e) {}

	    /* Since ensemble callbacks are in a separate thread,
	     * we also have to check for error return from the Cast
	     * call, and terminate the loop upon an IOException.
	     */
	    int err = Cast(sample);
	    if (err != 0)
	    {
		break;
	    }
	}
    }

    synchronized void leaving () {
	trace ("Leaving group...");
	he.Leave(gctx);

	try {
	    while (!quitting)
	    {
		System.out.println("Waiting for exit signal");
		wait();
	    }
	} catch (InterruptedException e) {}

	System.out.println("Destroying outboard");
	he.destroyOutboard();

    }

    
    public void ReceiveCast(Hot_GroupContext gctx, Object env, 
			    Hot_Endpoint origin, Hot_Message msg) {
	Hot_ObjectMessage hom = new Hot_ObjectMessage(msg);
	Object o = hom.getObject();
	
	/* add seq to output */
	trace("!! " + seq);
	seq++;
    }

    public void ReceiveSend(Hot_GroupContext gctx, Object env, 
				Hot_Endpoint origin, Hot_Message msg) {
	trace ("ReceiveSend");
    }


    public synchronized void AcceptedView(Hot_GroupContext gctx, Object env, 
			     Hot_ViewState viewState) {
	vs = viewState;

	/* view info print out */
	if (vs.rank == 0)
	{
	System.out.println("ThreadTest:view (nmemb=" + vs.nmembers + ", rank="+ vs.rank + ")");
	System.out.println("\tview_id = ("+vs.view_id.ltime+","+vs.view_id.coord.name+")");
	System.out.println("\tversion = \""+vs.version);
	System.out.println("\tgroup_name = \""+vs.group_name);
	System.out.println("\tprotocol = \""+vs.protocol);
	System.out.println("\tmy_rank = "+vs.rank);
	System.out.println("\tgroup daemon is "+ (vs.groupd ? "in use" : "not in use"));
	System.out.println("\tparameters = \""+vs.params);
	System.out.println("\txfer_view = "+vs.xfer_view);
	System.out.println("\tprimary = " + vs.primary);
	}
	if (mayWeStart())
	{
	    trace("Start signal");
	    notify();
	}

        /* add signal for clearing blocked flag, since
	 * reception of new view is the event which clears it.
	 */
	if (started == true && blocked == true)
	{
	    trace("blocked signal");
	    notify();
	}

	/* new view clears blocked flag */
	blocked = false;

    }

    public void Heartbeat(Hot_GroupContext gctx, Object env, int rate) {
	trace( "Heartbeat...");
    }

    public void Block(Hot_GroupContext gctx, Object env) {
	trace("Blocking...");

	/* we have recvd a BLOCK callback, set blocked flag */
	blocked = true;
    }

    public synchronized void Exit(Hot_GroupContext gctx, Object env) {
	trace("Exit...");

	quitting = true;

	System.out.println("Exit - signalling wait");
	notifyAll();
    }
    
    private int Cast (Object obj) {
	Hot_ObjectMessage msg = new Hot_ObjectMessage();
	msg.setObject(obj);
	int[] foo = new int[1]; // ??? Why not testing for null ?

	/* need to check for Hot_Error on Cast, since we may
	 * see a Broken Pipe or Connection reset by peer IOException
	 */
	Hot_Error hotError = he.Cast(gctx,msg,foo);
	if (hotError != null)
	{
            System.err.println("Cast: error " + hotError.toString());
	    return (-1);
	}
	else
	    return (0);

    }
}

