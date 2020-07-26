/**************************************************************/
/* PERF.CS: performance test. */
/* Author: Ohad Rodeh 7/2003 */
/* Tests two scenarios: ping latency, and bandwith */
/* Similar to ce/ce_perf and demo/perf */
/**************************************************************/

import ensemble.*;
import java.io.*;
import java.lang.*;
import java.util.*;

/**************************************************************/

public class Perf
{
    /* Test parameters
     */
    static String prog = "rpc" ;
    static int nmembers = 2 ;
    static int total_num_msgs = 20000;
    static int num_msgs_recvd = 0;
    static int size = 1000 ;
    static boolean quiet = false ;
    static Connection conn = null;
    static Member memb = null;
    static boolean done = false;
    
    static View v;
    static boolean blocked = false ;
    static boolean start = false ;
    static byte[] bulk_data = null;
    static byte[] ack = new byte[4];
    static int total = 0;
    static long start_time = 0;
    
    /**************************************************************/
    /* RPC test case
     */
    static void RpcMainLoop(JoinOps jops) throws Exception
    {
	memb.Join(jops);
	
	while (true) {
	    Message msg = conn.Recv ();
	    
	    switch (msg.mtype) {
	    case Connection.VIEW: 
		v = msg.view;
		System.out.println(" view= " + Arrays.asList(v.endpts));
		blocked = false ;
		
		if (2 == v.nmembers) {
		    start = true ;
		    start_time = System.currentTimeMillis();
		    bulk_data= new byte[size] ;
		    System.out.println("Got initial membership");
		}
		
		if (start &&
                    0 == v.rank && 
		    v.nmembers == 2) {
		    System.out.println("Sending first message");
		    memb.Send1(1, bulk_data);
		}

                if (1 == v.nmembers &&
                    start) {
		    System.out.println("The test has ended, exiting");
                    System.exit(0);
                }
		break;
		
	    case Connection.EXIT:
		System.out.println("RPC exit");
		break;
		
	    case Connection.CAST:
		break;
		
	    case Connection.SEND:
                num_msgs_recvd++;
		if (num_msgs_recvd % 1000 == 0)
		    System.out.println("#recv_send: " + num_msgs_recvd);
		
		if (start
		    && !blocked
		    && v.nmembers == 2) {
		    if (v.rank == 0)
			memb.Send1(1, bulk_data);
		    if (v.rank == 1)
			memb.Send1(0, bulk_data);
		}
		
		if (start &&
		    num_msgs_recvd >= total_num_msgs) 
		    {
			start = false ;
			long now = System.currentTimeMillis();
			long diff = (now -start_time)/1000;
			System.out.println("finished RPC test");
			System.out.println("total=" + num_msgs_recvd );
			System.out.println("time=" + diff + "sec");
			System.out.println("round-trip latency=" + (double)((diff*1000*1000)/num_msgs_recvd)+ "(mircosecond)");
			memb.Leave();
			
			Thread.sleep(1000);
			System.exit(0);
		    }
		break;
		
	    case Connection.BLOCK:
		blocked = true ;
		memb.BlockOk();
		break;
	    }
	}
    }
    
    /**************************************************************/
    /* Throuput test case
     */
    
    static void ThrouMainLoop(JoinOps jops) throws Exception
    {
	memb.Join(jops);
	
	while (true) {
            // handle all incoming messages
            while (conn.Poll ()) {
                Message msg = conn.Recv ();
                
                switch (msg.mtype) {
                case Connection.VIEW: 
                    v = msg.view;
                    System.out.println("view= " + Arrays.asList(v.endpts));
                    blocked = false ;
                    
                    if (nmembers == v.nmembers) {
                        start = true ;
                        start_time = System.currentTimeMillis();
                        bulk_data= new byte[size] ;
                    }
                    
                    if (nmembers > v.nmembers &&
                        start) {
                        System.out.println("Members have started to leave, exiting.");
                        System.exit(0);
                    }
                    break;
                    
                case Connection.EXIT:
                    System.out.println("RPC exit");
                    break;
                    
                case Connection.CAST:
                    total += size;
                    num_msgs_recvd++;
                    if (total % 100 == 0)
                        System.out.println("#recv msgs: " + total/size +
                                           "  #size: " + total);
                    
                    if (start &&
                        num_msgs_recvd == total_num_msgs &&
                        1 == v.rank )
                        {
                            start = false ;
                            long now = System.currentTimeMillis();
                            long diff = now - start_time;
                            System.out.println("finished througput test");
                            System.out.println("total=" + total );
                            System.out.println("time=" + diff + "msec");
                            System.out.println("throughput=" +
                                               (int) (total * 1000)/(1024 * diff) +
                                               "Kbyte/sec");
                            //	conn.Leave(memb);
                            System.exit(0);
                        }
                    break;
                    
                case Connection.SEND:
                    break;
                    
                case Connection.BLOCK:
                    blocked = true ;
                    memb.BlockOk();
                    break;
                    
                }
            }
            
            // multicast the message in a loop
            if (start
                && !blocked
                && v.nmembers == nmembers
                && 0 == v.rank
                && !done)  {
                for (int i=0; i<total_num_msgs; i++) {
                    //	System.out.println("multicasting message");
                    memb.Cast(bulk_data);
                }
                done = true;
            }
        }
    }
    
    /**************************************************************/
    /* Parse command line arguments. 
     */    
    static void ParseCmdLine(String[] args) throws Exception
    {
	for (int i = 0; i < args.length; i++) {
	    if (args[i].equals("-prog")) {
		prog = args[i+1];
		i++;
	    } 
	    else if (args[i].equals("-n")) {
		nmembers = Integer.parseInt(args[i+1]);
		i++;
	    } 
	    else if (args[i].equals("-s")) {
		size = Integer.parseInt(args[i+1]);
		i++;
	    } 
	    else if (args[i].equals("-r")) {
		total_num_msgs = Integer.parseInt(args[i+1]);
		i++;
	    } 
	    else if (args[i].equals("-quiet")) {
		quiet = true;
	    }
	}
        
	System.out.println("Args= ");	
	System.out.println("\t prog= " + prog);	
	System.out.println("\t nmembers= " + nmembers);
	System.out.println("\t size= " + size);	
        System.out.println ("\t total_num_msgs=" + total_num_msgs);
	System.out.println("\t quiet= " + quiet);	
    }
    
    /** A simple test case. Invoke with a number of group names.
     * Each member will cast the group name every second.
     */
    public static void main(String[] args) throws Exception
    {
	ParseCmdLine (args);
	conn = new Connection ();	
	conn.Connect();
	
	JoinOps jops = new JoinOps();
	jops.group_name = "CS_Perf" ;
	
	// Create the endpoint
	memb = new Member(conn);
	
	if (prog.equals("rpc"))
	    RpcMainLoop(jops);
	else 
	    ThrouMainLoop(jops);
    }
}
