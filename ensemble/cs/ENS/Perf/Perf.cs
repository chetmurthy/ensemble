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
	static double rate = 0.01 ;
	static int size = 4 ;
	static double terminate_time = 10.0 ;
	static bool quiet = false ;
	static Connection conn = null;
	static Member memb = null;

	static View v;
	static bool blocked = false ;
	static bool start = false ;
	static bool flow_block = false ;
	static byte[] bulk_data = null;
	static byte[] ack = new byte[4];
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
				Console.WriteLine(" view= " + v.view);
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
				total++;
				if (total % 1000 == 0)
					Console.WriteLine("#recv_send: " + total);
				
				if (start
				    && !blocked
				    && v.nmembers == 2
				    && !flow_block) {
					if (v.rank == 0)
						memb.Send1(1, bulk_data);
					if (v.rank == 1)
						memb.Send1(0, bulk_data);
				}
				
				if (start &&
				    total >= 20000) 
				{
					start = false ;
					long now = DateTime.Now.Ticks;
					long diff = (now -start_time)/(10*1000*1000);
					Console.WriteLine("finished RPC test");
					Console.WriteLine("total=" + total );
					Console.WriteLine("time=" + diff + "sec");
					Console.WriteLine("round-trip latency=" + (double)((diff*1000*1000)/total)+ "(mircosecond)");
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

			case UpType.HEARTBEAT:
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
						Console.WriteLine(" view= " + v.view);
						blocked = false ;
					
						if (nmembers == v.nmembers) 
						{
							start = true ;
							start_time = DateTime.Now.Ticks;
							bulk_data= new byte[size] ;
							Console.WriteLine("Got initial membership");
						}
						break;
					
					case UpType.EXIT:
						Console.WriteLine("RPC exit");
						break;
					
					case UpType.CAST:
						total += size;
						if (total % 10 == 0)
							Console.WriteLine("#recv_cast: " + total);
					
						if (start &&
							total >= 200*1024 )  /* We need to receive 200K for an estimate */
						{
							start = false ;
							long now = DateTime.Now.Ticks;
							long diff = (now -start_time)/(10*1000*1000);
							Console.WriteLine("finished RPC test");
							Console.WriteLine("total=" + total );
							Console.WriteLine("time=" + diff + "sec");
							Console.WriteLine("throughput=" + (int) total/(1024 * diff) + "Kbyte/sec");
							//	conn.Leave(memb);
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
					
					case UpType.HEARTBEAT:
						break;
				}
			}

			// multicast the message periodically. 
			if (start
				&& !blocked
				&& v.nmembers == nmembers
				&& !flow_block
				&& 0 == v.rank) 
			{
	//			Console.WriteLine("multicasting message");
				Thread.Sleep((int)(rate*1000)); 
				memb.Cast(bulk_data);
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
				Console.WriteLine("prog = " + prog);
				i++;
			} 
			else if (args[i] == "-n") {
				nmembers = int.Parse(args[i+1]);
				Console.WriteLine ("nmembers" + nmembers);
				i++;
			} 
			else if (args[i] == "-r") {
				rate = float.Parse(args[i+1]);
				Console.WriteLine ("rate=" + rate);
				i++;
			} 
			else if (args[i] == "-s") {
				size = int.Parse(args[i+1]);
				Console.WriteLine ("size=" + size);
				i++;
			} 
			else if (args[i] == "-terminate_time") {
				terminate_time = int.Parse(args[i+1]);
				Console.WriteLine("terminate_time=" + terminate_time);
				i++;
			} 
			else if (args[i] == "-quiet" ) {
				quiet = true;
				Console.WriteLine("quiet mode");
			}
		}
	}
	
	/** A simple test case. Invoke with a number of group names.
	 * Each member will cast the group name every second.
	 */
	public static void Main(string[] args) 
	{
		ParseCmdLine (args);
		conn = new Connection ();	
		conn.Connect();
		
		Console.WriteLine("Args= ");	
		Console.WriteLine("\t prog= " + prog);	
		Console.WriteLine("\t nmembers= " + nmembers);
		Console.WriteLine("\t rate= " + rate);	
		Console.WriteLine("\t size= " + size);	
		Console.WriteLine("\t terminate_time= " + terminate_time);	
		Console.WriteLine("\t quiet= " + quiet);	
		
		JoinOps jops = new JoinOps();
		jops.group_name = "CS_Perf" ;

		// Create the endpoint
		memb = new Member(conn);
		jops.hrtbt_rate = 10.0 ;
			
		if (prog == "rpc")
			RpcMainLoop(jops);
		else 
			ThrouMainLoop(jops);
	}
}
