/**************************************************************/
/* PERF.CS: performance test. */
/* Author: Ohad Rodeh 7/2003 */
/* Tests two scenarios: ping latency, and bandwith */
/* Similar to ce/ce_perf and demo/perf */
/**************************************************************/

using System;
using System.Collections;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Ensemble;

/**************************************************************/

public class Perf
{
	/* Test parameters
	 */
	static String prog = "rpc" ;
	static int nmembers = 2 ;
	static int size = 4 ;
	static double terminate_time = 10.0 ;
    static int total_num_msgs = 20000;
    static int num_recvd_msgs = 0;

	static Connection conn = null;
	static Member memb = null;
	static View v;
	static bool blocked = false ;
	static bool start = false ;
	static bool done = false ;
	static byte[] bulk_data = null;
	static int total = 0;
	static long start_time = 0;

	/**************************************************************/
	/* RPC test case
	 */
	static void RpcMainLoop(JoinOps jops) 
	{
		memb.Join(jops);
	
		while (true) {
			Message msg = conn.Recv ();

			switch (msg.mtype) {
			case UpType.VIEW: 
				v = msg.view;
				Console.Write("  view=[");
				foreach (string endpt in v.view)
				{
					System.Console.Write(":" + endpt);
				}
				Console.WriteLine("]");
				blocked = false ;
				
				if (2 == v.nmembers) {
					start = true ;
					start_time = DateTime.Now.Ticks;
					bulk_data= new byte[size] ;
					Console.WriteLine("Got initial membership");
				}
				
				if (start 
				    && 0 == v.rank) {
					Console.WriteLine("Sending first message");
					memb.Send1(1, bulk_data);
				}
				break;

			case UpType.EXIT:
				Console.WriteLine("RPC exit");
				break;

			case UpType.CAST:
				break;
			
			case UpType.SEND:
                num_recvd_msgs++;
				if (num_recvd_msgs % 1000 == 0)
					Console.WriteLine("#recv_send: " + num_recvd_msgs);
				
				if (start
				    && !blocked
				    && v.nmembers == 2) {
					if (v.rank == 0)
						memb.Send1(1, bulk_data);
					if (v.rank == 1)
						memb.Send1(0, bulk_data);
				}
				
				if (start &&
				    num_recvd_msgs >= total_num_msgs) 
				{
					start = false ;
					long now = DateTime.Now.Ticks;
					long diff = (now -start_time)/(10*1000*1000);
					Console.WriteLine("finished RPC test");
					Console.WriteLine("total=" + num_recvd_msgs);
					Console.WriteLine("time=" + diff + "sec");
					Console.WriteLine("round-trip latency=" + (double)((diff*1000*1000)/num_recvd_msgs)+ "(mircosecond)");
					//	conn.Leave(memb);

					Thread.Sleep(1000);
					System.Diagnostics.Process currentProcess = System.Diagnostics.Process.GetCurrentProcess();
					currentProcess.Kill();
				}
				break;
				
			case UpType.BLOCK:
				blocked = true ;
				memb.BlockOk();
				break;
			}
		}
	}

	/**************************************************************/
	/* Throuput test case
	 */
	
	static void ThrouMainLoop(JoinOps jops) 
	{
		memb.Join(jops);
	
		while (true) 
		{
			// handle all incoming messages
			while (conn.Poll ()) 
			{
				Message msg = conn.Recv ();
				
				switch (msg.mtype) 
				{
					case UpType.VIEW: 
						v = msg.view;
						Console.Write("  view=[");
						foreach (string endpt in v.view)
						{
							System.Console.Write(":" + endpt);
						}
						Console.WriteLine("]");
						blocked = false ;
					
						if (nmembers == v.nmembers) 
						{
							start = true ;
							start_time = DateTime.Now.Ticks;
							bulk_data= new byte[size] ;
							Console.WriteLine("Got initial membership");
						}

						if (nmembers > v.nmembers &&
							start) 
						{
							Console.WriteLine("Members have started to leave, exiting.");
							System.Diagnostics.Process currentProcess = System.Diagnostics.Process.GetCurrentProcess();
							currentProcess.Kill();
						}
						break;
					
					case UpType.EXIT:
						Console.WriteLine("RPC exit");
						break;
					
					case UpType.CAST:
                        num_recvd_msgs++;
                        total+=size;
						if (num_recvd_msgs% 10 == 0)
							Console.WriteLine("#recv_cast: " + num_recvd_msgs);
					
						if (start &&
						    num_recvd_msgs == total_num_msgs &&
                            1 == v.rank) 
						{
							start = false ;
							long now = DateTime.Now.Ticks;
							long diff = (now -start_time)/(10*1000*1000);
							Console.WriteLine("finished Throuput test");
							Console.WriteLine("total=" + total );
							Console.WriteLine("time=" + diff + "sec");
							Console.WriteLine("throughput=" + (int) total/(1024 * diff) + "Kbyte/sec");

							memb.Leave();
                            Thread.Sleep(1000);
							System.Diagnostics.Process currentProcess = System.Diagnostics.Process.GetCurrentProcess();
							currentProcess.Kill();
						}
						break;
					
					case UpType.SEND:
						break;
					
					case UpType.BLOCK:
						blocked = true ;
						memb.BlockOk();
						break;
				}
			}

			// multicast the message periodically. 
			if (start && 
				!blocked && 
				v.nmembers == nmembers && 
				0 == v.rank &&
                !done) 
			{
                Console.WriteLine("Mulitcasting messages\n"); 
                for (int i=0; i<total_num_msgs; i++)
                    memb.Cast(bulk_data);           
                done = true;
			}
		}
	}
	
	/**************************************************************/
	/* Parse command line arguments. 
	 */    
	static void ParseCmdLine(string[] args) 
	{
		for (int i = 0; i < args.Length; i++) {
			if (args[i] == "-prog") {
				prog = args[i+1];
				i++;
			} 
			else if (args[i] == "-n") {
				nmembers = int.Parse(args[i+1]);
				i++;
			} 
			else if (args[i] == "-s") {
				size = int.Parse(args[i+1]);
				i++;
			} 
			else if (args[i] == "-r") {
				total_num_msgs = int.Parse(args[i+1]);
				i++;
			} 
			else if (args[i] == "-terminate_time") {
				terminate_time = int.Parse(args[i+1]);
				i++;
			} 
		}

		Console.WriteLine("Args= ");	
		Console.WriteLine("\t prog= " + prog);	
		Console.WriteLine("\t nmembers= " + nmembers);
		Console.WriteLine("\t size= " + size);	
		Console.WriteLine("\t total_num_msgs= " + total_num_msgs);	
		Console.WriteLine("\t terminate_time= " + terminate_time);	
	}
	
	/** A simple test case. Invoke with a number of group names.
	 * Each member will cast the group name every second.
	 */
	public static void Main(string[] args) 
	{
		ParseCmdLine (args);
		conn = new Connection ();	
		conn.Connect();
		
		JoinOps jops = new JoinOps();
		jops.group_name = "CS_Perf" ;

		// Create the endpoint
		memb = new Member(conn);
					
		if (prog == "rpc")
			RpcMainLoop(jops);
		else 
			ThrouMainLoop(jops);
	}
}
