/**************************************************************/
/* RandTest.cs: random stress test.
 * Author: Ohad Rodeh 7/2003 
 * Stress tests joins/leave/send/casts/etc.
 * Similar to ce/ce_rand and demo/rand 
 */
/**************************************************************/
/*
 * This tests:
 * (1) opens a single connection to Ensemble 
 * (2) creates a number endpoints
 * (3) generates a large number of events attempting to stress
 *     the system.
 */
/**************************************************************/

import ensemble.*;
import java.io.*;
import java.lang.*;
import java.util.*;

/**************************************************************/

public class Rand
{
    static int nmembers = 5;
    static int thresh = 3;
    static int max_size_msg = 1000;
    
    static String groupName = "CS_RandTest";
    static Random rand = new Random ();
    static Connection conn = null;

    // There can be send_thresh send/cast messages outstanding at any time
    static int send_thresh = 30000;
    // the total size of outgoing messages.
    static int size_outgoing = 0;

    // statistics
    static int num_cast=0, num_send1=0, num_send=0;
    
    // An array of valid Ensemble members
    static Member[] memb_a;
    
    static void SleepMilli(int milliseconds) {
	try {
	    Thread.sleep(milliseconds);
	} catch(Exception e) { e.printStackTrace(); }
    }
    
    static int base_time = 0;
    static void PrintRuntime()
    {
        int p = (Math.abs(rand.nextInt ())) % 5;
	
        if (0 == p) {
            int now = (int) System.currentTimeMillis();
            int day, hr, min, sec;
            
            if (0 == base_time) {
                day = 0;
                hr = 0;
                min = 0;
                sec = 0;
                base_time = now;
            } else {
                int diff = (now - base_time) / 1000;
                sec = diff % 60;
                min = (diff % (60 * 60)) / 60;
                hr = (diff % (60*60*24)) / (60*60);
                day = (diff % (60*60*24*365)) / (60*60*24);
            }
            
            System.out.println("RAND.java: running time=<"+ day + "d:" + hr + "h:" +
                               min +"m:" + sec + "s>  num_cast=" + num_cast +
                               " num_send=" + num_send +
                               " num_send1="+ num_send1 );
        }
    }
    
    // Create an endpoint in slot [i]
    static void CreateEndpt(int i) throws EnsembleException
    {
	JoinOps jops = new JoinOps();
	jops.group_name = groupName;
	Member m = new Member(conn);
	m.Join(jops);
	memb_a[i] = m;
        // System.out.println("Join");
    }
    
    // Print out a message contents
    static void HandleMsg(Message msg) throws EnsembleException {
	Member m = msg.m;
	
	switch(msg.mtype) {
	case Connection.VIEW:
	    System.out.println("VIEW");
	    View view = msg.view;
	    System.out.println("Install:{ " + m.current_view.name);
	    
	    System.out.println("  version= " + view.version);
	    System.out.println("  proto= " + view.proto);
	    System.out.println("  group= " + view.group);
	    System.out.println("  ltime= " + view.ltime);
	    System.out.println("  primary= " + view.primary);
	    System.out.println("  params= " + view.parameters);
	    System.out.println("  view= " + Arrays.asList(view.endpts));
	    System.out.print("  address= " + Arrays.asList(view.address));
	    System.out.println("  endpt= " + view.endpt);
	    System.out.println("  addr= " + view.addr);
	    System.out.println("  name= " + view.name);
	    System.out.println("  nmembers= " + view.nmembers);
	    
	    System.out.println("}");
	    break;
	    
	case Connection.EXIT:
	    System.out.println("EXIT");
	    break;
	    
	case Connection.CAST:
            //	System.out.println("CAST: " + new String(msg.data) +" from "+ msg.origin);
	    break;
	    
	case Connection.SEND:
            // System.out.println("SEND: " + new String(msg.data) +" from "+ msg.origin);
	    break;
	    
	    /* If we get a Block request, and the member isn't leaving,
             * respond with a BlockOk immediatly.
             */
	case Connection.BLOCK:
	    if (m.current_status != Member.Leaving) {
                // System.out.println("BLOCK");
		m.BlockOk();
	    }
	    break;
	}
    }
    
    
    static byte[] GenMsg ()
    {
        int size = (Math.abs(rand.nextInt ())) % max_size_msg;
	return new byte[size];
    }
    
    // generate a destination different than yourself. The number
    // of members must be greater than 1.
    static int GenDest (int rank, int nmembers) throws Exception
    {
	int rep = rank;
	
	if (nmembers == 1)
	    throw new Exception("GenDest in a group of size 1");
	while (rep == rank) {
	    rep = (Math.abs(rand.nextInt ())) % nmembers;
	}
	return rep;
    }
    
    static int[] GenDests(int rank, int nmembers) throws Exception
    {
	int[] a = new int[2];
	a[0] = GenDest(rank, nmembers); 
	a[1] = GenDest(rank, nmembers); 
	return a;
    }
    
    static void RCast(Member m) throws Exception
    {
        if (size_outgoing < send_thresh) {
            int my_rank = m.current_view.rank;
            // System.out.println("id=" + my_rank + " Cast");
            num_cast++;
            byte [] msg = GenMsg() ;
            size_outgoing += msg.length;
            m.Cast(msg);
        } 
    }
    
    static void RSend1(Member m) throws Exception
    {
        if (size_outgoing < send_thresh) {
            int my_rank = m.current_view.rank;
            // System.out.println("id=" + my_rank + " Send1");
            num_send1++;
            byte [] msg = GenMsg() ;
            size_outgoing += msg.length;
            m.Send1(GenDest(my_rank, m.current_view.nmembers), msg);
        }
    }
    
    static void RSend(Member m) throws Exception
    {
         if (size_outgoing < send_thresh) {
            int my_rank = m.current_view.rank;
            num_send++;
            // System.out.println("id=" + my_rank + " Send");
            byte [] msg = GenMsg() ;
            size_outgoing += msg.length;
            m.Send(GenDests(my_rank, m.current_view.nmembers), msg);
         } 
    }

    // Perform a random action for member [i]
    static public void RandAction (int i) throws Exception
    {
        //        System.out.println("RandAction");
	int p = (Math.abs(rand.nextInt ())) % 100;
	Member m = memb_a[i];
	
	// The endpoint is dead, create a new one. 
	if (null == m) {
	    if (p<40) 
		CreateEndpt(i);
	    return;
	} 
	
	//  If the group has not been initialized yet, then do nothing.
	if (null == m.current_view) return;
	
	/* If there aren't enough members in the group, or if
	 * the group isn't in a Normal state, do nothing.
	 */
	if (m.current_view.nmembers < thresh
	    || m.current_view.nmembers ==1
	    || m.current_status != Member.Normal)
	    return;
	
        int q = (Math.abs(rand.nextInt ())) % m.current_view.nmembers;
        if (p < 1 && q == 0) {
	    m.Leave();
	    memb_a[i] = null;
	}  else  if (p < 2 && q==0) {
	    int[] dests =  GenDests(m.current_view.rank, m.current_view.nmembers);
	    m.Suspect(dests);
        } else  if (p < 40) {
            RCast(m);
	} else if (p < 70) {
            RSend1(m);
	} else {
            RSend (m);
	}
    }
    
    static void RecvMsgs () throws Exception
    {
        while (conn.Poll ()) {
            Message msg = conn.Recv ();
            HandleMsg(msg);
        }
        System.out.flush();
    }
        
    /********************************************************************************/
    /* Parse command line arguments. 
     */    
    static void ParseCmdLine(String[] args) throws Exception {
	try {
	    for (int i = 0; i < args.length; i++) {
		if (args[i].equals("-t")) {
		    thresh = Integer.parseInt(args[i+1]);
		    System.out.println("thresh = " + thresh);
		    args[i] = null;
		    args[i+1] = null;
		    i++;
		} else if (args[i].equals("-n")) {
		    nmembers = Integer.parseInt(args[i+1]);
		    System.out.println("nmembers = " + nmembers);
		    i++;
		} else if (args[i].equals("-s")) {
		    max_size_msg = Integer.parseInt(args[i+1]);
		    System.out.println("max_size_msg = " + max_size_msg);
		    i++;
		} 
	    }
	    System.out.flush();
	} catch (NumberFormatException e) {
	    throw new Exception("Bad formatting for [-t] or [-n] command line arguments.");
	    
	}
    }
    
    /** A simple test case. Invoke with a number of group names.
     * Each member will cast the group name every second.
     */
    public static void main(String[] args) throws Exception {
	int i;
            
	ParseCmdLine (args);
	conn = new Connection ();	
	conn.Connect();
	
	// Create an initial set of endpoints
	memb_a = new Member[nmembers];
	for(i=0; i<nmembers; i++)
	    CreateEndpt (i);
	
	// The main loop
	while(true) {
	    // While there are pending messages --- read them
            RecvMsgs ();
            
            if (size_outgoing >= send_thresh) {
                PrintRuntime();
                // We have filled the queue to the server, stop sending for a while
                for (int j=0; j<5; j++) {
                    SleepMilli(200);
                    RecvMsgs();
                }
                size_outgoing = 0;
            }

            // Generate some random actions, one for each member.
            for (i=0; i<nmembers; i++)
                RandAction(i);
        }
    }
}
