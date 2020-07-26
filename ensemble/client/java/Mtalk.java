/**************************************************************/
/* MTALK.java */
/* Author: Ohad Rodeh 10/2003 */
/* A simple program implementing a multi-person talk. */
/**************************************************************/


import ensemble.*;

import java.io.*;

/**************************************************************/

public class Mtalk implements Runnable
{
    static Connection conn = null;
    static Member memb = null;
    BufferedReader inputStream = new BufferedReader (new InputStreamReader(System.in));
    
    /**************************************************************/
    
    // A method for the input-thread
    public void run () 
    {
	try {
	    while(true) 
		{
		    // Parse an input line and perform the required operation
		    //Console.WriteLine("reading from input");
		    String line = inputStream.readLine();
		    if (line != null) {
			synchronized (conn) 
			    {
				if (memb.current_status == Member.Normal)
				    memb.Cast(line.getBytes());
				else
				    System.out.println("Blocked currently, please try again later");
			    }
		    }
		    Thread.sleep(100);
		}
	}
	catch (Exception e)
	    {
		System.out.println("Exception occured:" + e);
	    }
    }
    
    /**************************************************************/
    
    static void MainLoop() throws Exception
    {
	// Open a special thread to read from the console
	Mtalk mt = new Mtalk();
	Thread input_thr = new Thread(mt);
	input_thr.start();
	
	//System.out.println("sleeping for a little while");
	while(true) 
	    {
		// Read all waiting messages from Ensmeble
		while (conn.Poll()) 
		    {
			Message msg = conn.Recv();
			switch(msg.mtype) 
			    {
			    case Connection.VIEW:
				System.out.println("Install:{ " + memb.current_view.name);
				System.out.println("  nmembers= " + msg.view.nmembers);
				System.out.print("  view=[");
				View v = msg.view;
				for (int i=0; i< v.endpts.length; i++)
				    {
					String endpt = v.endpts[i];
					System.out.println(":" + endpt);
				    }
				System.out.println("]");
				break;
			    case Connection.CAST:
				System.out.println("CAST (" + msg.origin + ") " +
						   new String(msg.data));
				break;
			    case Connection.SEND:
				System.out.println("SEND (" + msg.origin + ") " +
						   new String(msg.data));
				break;
			    case Connection.BLOCK:
				memb.BlockOk();
				break;
			    case Connection.EXIT:
				break;
			    }
			System.out.flush();
		    }
		
		//System.out.println("sleeping for a little while");
		Thread.sleep(100);
	    }
    }
    
    public static void main(String[] args)
    {
	try {
	    conn = new Connection ();	
	    conn.Connect();
	    
	    JoinOps jops = new JoinOps();
	    jops.group_name = "Java_Mtalk" ;
	    
	    // Create the endpoint
	    memb = new Member(conn);
	    
	    memb.Join(jops);
	    MainLoop();
	}
	catch (Exception e)
	    {
		System.out.println("Exception: " + e);
	    }
    }
}
