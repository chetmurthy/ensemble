/**************************************************************/
/* PERFTEST.JAVA: performance test. */
/* Author: Ohad Rodeh 7/2002 */
/* Tests two scenarios: ping latency, and bandwith */
/* Similar to ce/ce_perf and demo/perf */
/**************************************************************/
import java.lang.* ;
import java.io.* ;
import java.util.* ; 
import ensemble.*;
/**************************************************************/

public class PerfTest
{
    /* Test parameters
     */
    static String prog = "rpc" ;
    static int nmembers = 2 ;
    static double rate = 0.01 ;
    static int size = 4 ;
    static double terminate_time = 10.0 ;
    static boolean quiet = false ;
    
    static void sleep(int milliseconds) {
	try {
	    Thread.sleep(milliseconds);
	} catch(Exception e) { e.printStackTrace(); }
    }

    /* Test object variables
     */
    View v;
    boolean blocked = false ;
    boolean start = false ;
    boolean first_time = false ;
    boolean flow_block = false ;
    byte []msg = null;
    double start_time = 0.0 ;
    int total = 0;
    double next = 0.0 ;
    
    /**************************************************************/
    /* RPC test case
     */
    final Group rpc = new Group(new Callbacks() {
	    public void install(View view) {
		v = view;
		System.out.println("  view= " + 
				   java.util.Arrays.asList(view.view));
		blocked = false ;

		if (view.nmembers == 2) {
		    start = true ;
		    msg = new byte[size] ;
		}
	    }
	    
		public void exit() {
		    System.out.println("RT exit");
		    System.out.flush();
		    System.exit(0);
		}
		
		public void recv_cast(int origin, byte[] msg) {
		}
		
		public void recv_send(int origin, byte[] msg) {
		    total++;
		    if (total % 1000 == 0)
			System.out.println("RT recv_send: " + total);
		    
		    if (start
			&& !blocked
			&& v.nmembers == 2
			&& !flow_block) {
			if (v.rank == 0)
			    rpc.send1(1, msg);
			if (v.rank == 1)
			    rpc.send1(0, msg);
		    }
		}
		
		public void flow_block(int rank, boolean onoff) {
		    flow_block = onoff ;
		}

		public void block() {
		    blocked = true ;
		}
		
		public void heartbeat(double time) {
		    if (start && !first_time) {
			first_time = true ;
			start_time = time ;
		    }
		    
		    if (start
			&& !blocked
			&& v.nmembers == 2
			&& !flow_block) {
			if (v.rank == 0)
			    rpc.send1(1, msg);
			if (v.rank == 1)
			    rpc.send1(0, msg);
		    }

		    if (start &&
			time - start_time > terminate_time) {
			start = false ;
			System.out.println("finished RPC test");
			System.out.println("total=" + total );
			System.out.println("time=" + terminate_time);
			System.out.println("round-trip latency=" +
					   (time - start_time)/total   
					   + "(sec)");
			rpc.leave();
		    }
		}
	});

    /**************************************************************/
    /* Throuput test case
     */

    final Group throu = new Group(new Callbacks() {
	    public void install(View view) {
		v = view;
		System.out.println("  view= " + 
				   java.util.Arrays.asList(view.view));
		blocked = false ;

		if (view.nmembers == 2) {
		    start = true ;
		    msg = new byte[size] ;
		}
	    }
	    
		public void exit() {
		    System.out.println("RT exit");
		    System.out.flush();
		    System.exit(0);
		}
		
		public void recv_cast(int origin, byte[] msg) {
		}
		
		public void recv_send(int origin, byte[] msg) {
		    total++;
		    if (total % 1000 == 0)
			System.out.println("RT recv_send: " + total);
		    
		    if (start
			&& !blocked
			&& v.nmembers == 2
			&& !flow_block) {
			if (v.rank == 0)
			    throu.send1(1, msg);
			if (v.rank == 1)
			    throu.send1(0, msg);
		    }
		}
		
		public void flow_block(int rank, boolean onoff) {
		    flow_block = onoff ;
		}

		public void block() {
		    blocked = true ;
		}
		
		public void heartbeat(double time) {
		    if (start && !first_time) {
			first_time = true ;
			start_time = time ;
			next = time;
		    }
		    
		    if (start
			&& !blocked
			&& v.nmembers == 2
			&& !flow_block) {
			while (time > next) {
			    //System.out.println("Sending bcast");
			    throu.cast(msg);
			    next += rate;
			    total += size;
			}
		    }

		    if (start &&
			time - start_time > terminate_time) {
			start = false ;
			System.out.println("finished THROU test");
			System.out.println("total=" + total );
			System.out.println("time=" + terminate_time);
			System.out.println("throughput= " +
					   total/(1024 * (time - start_time))
					   + "(K/sec)" );
			throu.leave();
		    }
		}
	});


    /**************************************************************/
    /* Parse command line arguments. 
     */    
    static String[] parse_cmd_line(String[] args) {
	int len=0;
	boolean valid ;
	    
	for (int i = 0; i < args.length; i++) {
	    valid = false ;
	    if (args[i].equals("-prog")) {
		//		System.out.println("in -t");
		prog = args[i+1];
		System.out.println("prog = " + prog);
		valid = true ;
	    } else 
		if (args[i].equals("-n")) {
		    nmembers = Integer.parseInt(args[i+1]);
		    System.out.println ("nmembers" + nmembers);
		    valid = true ;
		} else
		    if (args[i].equals("-r")) {
			rate = Float.parseFloat(args[i+1]);
			System.out.println ("rate=" + rate);
			valid = true ;
		    } else 
			if (args[i].equals("-s")) {
			    size = Integer.parseInt(args[i+1]);
			    System.out.println ("size=" + size);
			valid = true ;
			} else 
			    if (args[i].equals("-terminate_time")) {
				terminate_time = Integer.parseInt(args[i+1]);
				System.out.println("terminate_time=" + terminate_time);
				valid = true ;
			    } else 
				if (args[i].equals("-quiet")) {
				    quiet = true;
				    System.out.println("quiet mode");
				    valid = true ;
				} else
				    len++;
	    if (valid) {
		args[i] = null;
		args[i+1] = null;
		i++;
	    }
	}

	String[] new_args = new String[len];
	for(int i=0, j=0; i<args.length; i++) {
	    if (args[i] != null) {
		new_args[j] = args[i];
		j++;
	    }
	}
	
	return new_args;
    }

    /** A simple test case. Invoke with a number of group names.
     * Each member will cast the group name every second.
     */
    public static void main(final String args[]) throws Exception {
	String new_args [] = parse_cmd_line (args);
	Group.init(new_args);

	System.out.println("Args= ");	
	System.out.println("\t prog= " + prog);	
	System.out.println("\t nmembers= " + nmembers);
	System.out.println("\t rate= " + rate);	
	System.out.println("\t size= " + size);	
	System.out.println("\t terminate_time= " + terminate_time);	
	System.out.println("\t quiet= " + quiet);	

	JoinOps jops = new JoinOps();
	PerfTest pt = new PerfTest ();
	jops.group_name = "java.PerfTest" ;
	if (prog.equals("rpc")) {
	    jops.hrtbt_rate = 1.0 ;
	    pt.rpc.join(jops);
	} else {
	    jops.hrtbt_rate = rate ;
	    pt.throu.join(jops);
	}
	Thread.sleep(100000000);
    }
}
