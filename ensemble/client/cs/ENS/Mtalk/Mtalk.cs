/**************************************************************/
/* MTALK.CS */
/* Author: Ohad Rodeh 7/2003 */
/* A simple program implementing a multi-person talk. */
/**************************************************************/


using System;
using System.Collections;
using System.Net;
using System.Threading;
using Ensemble;

/**************************************************************/

public class Mtalk 
{
	static Connection conn = null;
	static Member memb = null;
	
	/**************************************************************/
	
	// A method for the input-thread
	void run () 
	{
		while(true) 
		{
			// Parse an input line and perform the required operation
			//Console.WriteLine("reading from input");
			string line = Console.ReadLine();
			lock (conn) 
			{
				if (memb.current_status == Member.Status.Normal)
					memb.Cast(System.Text.Encoding.ASCII.GetBytes(line));
				else
					Console.WriteLine("Blocked currently, please try again later");
			}
			Thread.Sleep(100);
		}
	}

	/**************************************************************/

	static void MainLoop()
	{
		
		// Open a special thread to read from the console
		Mtalk mt = new Mtalk();
		Thread input_thr = new Thread(new ThreadStart(mt.run));
		input_thr.Start();
		
		while(true) 
		{
			// Read all waiting messages from Ensmeble
			while (conn.Poll()) 
			{
				Message msg = conn.Recv();
				switch(msg.mtype) 
				{
					case UpType.VIEW:
						Console.WriteLine("Install:{ " + memb.current_view.name);
						Console.WriteLine("  nmembers= " + msg.view.nmembers);
						Console.Write("  view=[");
						foreach (string endpt in msg.view.view)
						{
							System.Console.Write(":" + endpt);
						}
						Console.WriteLine("]");
						break;
					case UpType.CAST:
						Console.WriteLine("CAST (" + msg.origin + ") " + System.Text.Encoding.ASCII.GetString(msg.data));
						break;
					case UpType.SEND:
						Console.WriteLine("SEND (" + msg.origin + ") " + System.Text.Encoding.ASCII.GetString(msg.data));
						break;
					case UpType.BLOCK:
						memb.BlockOk();
						break;
					case UpType.EXIT:
						break;
				}
				Console.Out.Flush();
			}
			//Console.WriteLine("sleeping for a little while");
			Thread.Sleep(100);
		}
	}

	public static void Main(string[] args)
	{
		conn = new Connection ();	
		conn.Connect();
		
		JoinOps jops = new JoinOps();
		jops.group_name = "CS_Mtalk" ;

		// Create the endpoint
		memb = new Member(conn);
		
		memb.Join(jops);
		MainLoop();
	}
}
