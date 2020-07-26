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

using System;
using System.Collections;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Ensemble;
/**************************************************************/

public class Rand
{
	static int nmembers = 5;
	static int thresh = 3;
	static string groupName = "CS_RandTest";
	static Random rand = new Random ();
	static Connection conn = null;
	static int sleep_timeout = 100;   // The number of milliseconds to wait prior to sending actions. 

	// An array of valid Ensemble members
	static Member[] memb_a;

	// Create an endpoint in slot [i]
	static void CreateEndpt(int i) 
	{
		JoinOps jops = new JoinOps();
		jops.group_name = groupName;
		Member m = new Member(conn);
		m.Join(jops);
		memb_a[i] = m;
		
		Console.WriteLine("Join");
	}
	
	// Print out a message contents
	static void HandleMsg(Message msg) {
		Member m = msg.m;

		switch(msg.mtype) {
		case UpType.VIEW:
			Console.WriteLine("VIEW");
			View view = msg.view;
			Console.WriteLine("Install:{ " + m.current_view.name);
			Console.Write("  view=[");
			foreach (string endpt in view.view)
			{
				System.Console.Write(":" + endpt);
			}
			Console.WriteLine("]");
			Console.WriteLine("  version= " + view.version);
			Console.WriteLine("  proto= " + view.proto);
			Console.WriteLine("  group= " + view.group);
			Console.WriteLine("  ltime= " + view.ltime);
			Console.WriteLine("  primary= " + view.primary);
			Console.WriteLine("  params= " + view.parameters);
			Console.Write("  address= " + view.address);
			Console.WriteLine("  endpt= " + view.endpt);
			Console.WriteLine("  addr= " + view.addr);
			Console.WriteLine("  name= " + view.name);
			Console.WriteLine("  nmembers= " + view.nmembers);
					
			Console.WriteLine("}");
			break;
			
		case UpType.EXIT:
			Console.WriteLine("EXIT");
			break;
			
		case UpType.CAST:
			Console.WriteLine("CAST: " + System.Text.Encoding.ASCII.GetString(msg.data) +" from "+ msg.origin);
			break;

		case UpType.SEND:
			Console.WriteLine("SEND: " + System.Text.Encoding.ASCII.GetString(msg.data) +" from "+ msg.origin);
			break;

			// If we get a Block request, and the member isn't leaving, respond with a BlockOk immediatly.
		case UpType.BLOCK:
			if (m.current_status != Member.Status.Leaving) {
				Console.WriteLine("BLOCK");
				m.BlockOk();
			}
			break;
		}
	}
	
	
	static byte[] GenMsg ()
	{
		string s = "Hello World";
		return System.Text.Encoding.ASCII.GetBytes(s);
	}
	
	// generate a destination different than yourself. The number
	// of members must be greater than 1.
	static int GenDest (int rank, int nmembers) 
	{
		int rep = rank;
		
		if (nmembers == 1)
			throw new Exception("GenDest in a group of size 1");
		while (rep == rank) {
			rep = (rand.Next ()) % nmembers;
		}
		return rep;
	}
	
	static int[] GenDests(int rank, int nmembers){
		int[] a = new int[2];
		a[0] = GenDest(rank, nmembers); 
		a[1] = GenDest(rank, nmembers); 
		return a;
	}

	// Perform a random action for member [i]
	static public void RandAction (int i) 
	{
		int p = (rand.Next ()) % 100;
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
			|| m.current_status != Member.Status.Normal)
			return;

		int my_rank = m.current_view.rank;
		if (p < 6) {
			Console.WriteLine("id=" + my_rank + " Leave");
			m.Leave();
			memb_a[i] = null;
		}  else  if (p < 20) {
			int[] dests =  GenDests(my_rank, m.current_view.nmembers);
			Console.WriteLine("id=" + my_rank + " Suspect " + dests[0] + " " + dests[1]);
			m.Suspect(dests);
		} else if (p < 40) {
			Console.WriteLine("id=" + my_rank + " Cast");
			m.Cast(GenMsg());
		} else if (p < 70) {
			Console.WriteLine("id=" + my_rank + " Send1");
			m.Send1(GenDest(my_rank, 
					    m.current_view.nmembers), 
				   GenMsg());
		} else {
			Console.WriteLine("id=" + my_rank + " Send");
			m.Send(GenDests(my_rank, m.current_view.nmembers), 
				  GenMsg());
		}
	}
	
	/********************************************************************************/
	/* Parse command line arguments. 
	 */    
	static void ParseCmdLine(string[] args) {
		try {
			for (int i = 0; i < args.Length; i++) {
				if (args[i] == "-t") {
					//		Console.WriteLine("in -t");
					thresh = int.Parse(args[i+1]);
					Console.WriteLine("thresh = " + thresh);
					args[i] = null;
					args[i+1] = null;
					i++;
				} else if (args[i] == "-n") {
					//		Console.WriteLine("in -n");		
					nmembers = int.Parse(args[i+1]);
					Console.WriteLine("nmembers = " + nmembers);
					i++;
				} 
			}
		} catch (System.FormatException) {
			throw new Exception("Bad formatting for [-t] or [-n] command line arguments.");

		}
	}
	
	/** A simple test case. Invoke with a number of group names.
	 * Each member will cast the group name every second.
	 */
	public static void Main(string[] args) {
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
			while (conn.Poll ()) {
				Message msg = conn.Recv ();
				HandleMsg(msg);
				Console.Out.Flush();
			} 
			
			// Sleep for a while
			Thread.Sleep(sleep_timeout);
			
			// Generate some random actions, one for each member.
			for (i=0; i<nmembers; i++)
				RandAction(i);
		}
	}
}
