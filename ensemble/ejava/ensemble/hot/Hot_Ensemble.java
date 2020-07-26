//**************************************************************
//*
//*  Ensemble, (Version 1.00)
//*  Copyright 2000 Cornell University
//*  All rights reserved.
//*
//*  See ensemble/doc/license.txt for further information.
//*
//**************************************************************
package ensemble.hot;

import java.io.*;
import java.net.*;

public class Hot_Ensemble extends java.lang.Object implements java.lang.Runnable {
    public final int HOT_ENS_MSG_SEND_UNSPECIFIED_VIEW = 0;
    public final int HOT_ENS_MSG_SEND_NEXT_VIEW = 1;
    public final int HOT_ENS_MSG_SEND_CURRENT_VIEW = 2;

    private Hot_Mutex WriteMutex;
    private Hot_Mutex CriticalMutex;

    private boolean outboardValid;
    private Hot_IO_Controller hioc;
    private Process ensOutboardProcess;
    private Socket ensOutboardSocket;
    private static boolean debug;
    private static boolean use_byteStream;   // flag to use byte stream communic.
	
    /**
    Destroys the associated outboard process. All instances of Hot_Ensemble
    (in an instance of the VM) use the same outboard process (currently). 
    So, if you destroy the outboard process for one instance, it gets
    destroyed for all instances. A future version of Ensemble/Java will
    change this restriction.
    */
    public void destroyOutboard() {
	if (ensOutboardProcess != null) {
	    ensOutboardProcess.destroy();
            ensOutboardProcess = null;
            outboardValid = false;
	}
    }

	
    /**
    Constructs a Hot_Ensemble object starting the Ensemble Outboard process
    on a random port between 5000 and 8000
    */
    public Hot_Ensemble() {
	int port = 0;
	use_byteStream = false;  // default to Hot_ObjectMessages
	ServerSocket s = null;
	while (port == 0) {
            port = (int)((Math.random() * 3000) + 5000);
	    try {
		s = new ServerSocket(port);
	    } catch (Exception e) {
		System.out.println("cant use port: " + port);
		port = 0;
            }
	}
	try {
            s.close();
	} catch (Exception e) {
	
	}
	init(port);
    }

    /* New constructor which allows the user to specify that this
     * connection will use a byte stream instead of the default
     * serialized Object - used to interface with HOT C apps.
     */
    public Hot_Ensemble(boolean use_BS) {
	int port = 0;
	use_byteStream = use_BS;
	ServerSocket s = null;
	while (port == 0) {
            port = (int)((Math.random() * 3000) + 5000);
	    try {
		s = new ServerSocket(port);
	    } catch (Exception e) {
		System.out.println("cant use port: " + port);
		port = 0;
            }
	}
	try {
            s.close();
	} catch (Exception e) {
	
	}
	init(port);
    }

    /**
    Constructs a Hot_Ensemble object starting the Ensemble Outboard 
    process on the specified port. If you use this version of the
    constructor, you are expected to make sure the port is not already in 
    use. You can check for successful startup by invoking isOutboardStarted();
    */
    public Hot_Ensemble(int port) {
	try {
	    ensOutboardSocket = new Socket(InetAddress.getLocalHost(), port);
	    hioc = new Hot_IO_Controller(ensOutboardSocket.getInputStream(),
					 ensOutboardSocket.getOutputStream());
	    outboardValid = true;
	    System.out.println("outboard: outboard found on port " + port);
	    initCritical();
	    initWriteCritical();
	}
	catch(Exception e) {
	    System.err.println(e);
	    System.exit(-1);
	}
    }
	

    /**
    Sets up child process, creates the new IO Controller from this child process
    */
    private void init(int port) {
//	String outboard = "outboard -tcp_channel -tcp_port " + Integer.toString(port);

	//String outboard = "outboard -modes DEERING:UDP -deering_port 12222  -tcp_channel -tcp_port " +  Integer.toString(port);
	
	String outboard = "outboard -verbose -tcp_channel -tcp_port " + 
	  Integer.toString(port) + " -trace HOT_OUTBOARD";
	//String outboard="outboard -deering_port 77777 -tcp_channel -tcp_port " +
	//  Integer.toString(port);

	debug = false;

	if (outboardValid != true) {
            try {
		ensOutboardProcess = Runtime.getRuntime().exec(outboard);

		// Added by TC - wait for forked process to start up.
		try {
		    System.out.println("Waiting for the outboard process to start");
		    Thread.sleep(2500);
		}
		catch (InterruptedException e) {
		    System.out.println(e);
		    System.out.println("Sleep");
		}
		// End Added by TC.

		ensOutboardSocket = new Socket(InetAddress.getLocalHost(),
						port);
		hioc = new Hot_IO_Controller(ensOutboardSocket.getInputStream(),
						 ensOutboardSocket.getOutputStream());

		outboardValid = true;
		System.out.println("outboard: outboard started on port " + port);
            } catch (SecurityException e) {
		System.out.println(e);
		System.out.println("Security exception, can't run inside web browser.");
		System.exit(2);
            } catch (IOException e) {
		System.out.println(e);
		System.out.println("Some IO garbage at ensemble outboard startup.");
		System.exit(3);
            }

            // do the hot_ens_init stuff  (nothing here yet because there isn't 
	    // really anything useful to us in there)
	    initCritical();
	    initWriteCritical();
        }
    }

	
    /**
    Set whether or not to display lots of debug information.  Default: false
    */
    public void setDebug(boolean b) {
	debug = b;
    }


    /**
    Join the Ensemble group specified in the Hot_JoinOps structure
    */
    public Hot_Error Join(Hot_JoinOps jops, Hot_GroupContext[] gctx) {
	if (!outboardValid)
            return new Hot_Error(55,"Outboard process is not valid!");
	trace("Hot_Ensemble::Join begin");
	Hot_Error err = null;
	Hot_GroupContext gc = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
	 	gc = Hot_GroupContext.Alloc();
		gc.joining = true;
		gc.leaving = false;
		gc.conf = jops.conf;
		gc.env = jops.env;
		gctx[0] = gc;
	    }
	    // New version
	    hioc.begin_write();
	    hioc.write_hdr(gctx[0], hioc.DN_JOIN);
	    hioc.write_int(jops.heartbeat_rate);
	    hioc.write_string(jops.transports);
	    hioc.write_string(jops.protocol);
	    hioc.write_string(jops.group_name);
	    hioc.write_string(jops.properties);
	    hioc.write_bool(jops.use_properties);
	    hioc.write_bool(jops.groupd);
	    hioc.write_string(jops.params);
	    hioc.write_bool(jops.client);
	    hioc.write_bool(jops.debug);
	    hioc.write_string(jops.princ);
	    hioc.write_string(jops.key);
	    hioc.write_bool(jops.secure);
	    try {
	        hioc.end_write();
	    } 
	    catch (IOException e) {
		err = new Hot_Error(0, e.toString());
	    }	        
	}
	trace("Hot_Ensemble::Join end");
	return err;
    }

	
    /**
    Leave the Ensemble group specified in the Hot_GroupContext
    */
    public Hot_Error Leave(Hot_GroupContext gc) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	Hot_Error err = null;
	synchronized(WriteMutex) {
            synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_leave: this member is already leaving");
		}
		gc.leaving = true;
            }
	    // write the downcall.
	    hioc.begin_write();
	    hioc.write_hdr(gc, hioc.DN_LEAVE);
	    try {
	        hioc.end_write();
	    } 
	    catch (IOException e) {
		err = new Hot_Error(0, e.toString());
	    }	        
	}
	return err;
    }

	
    /**
    Broadcast a Hot_Message to the group specified in the Hot_GroupContext
    */
    public Hot_Error Cast(Hot_GroupContext gc, Hot_Message msg, int[] send_view) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");

	trace("Hot_Ensemble::Cast begin");
	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_leave: member is leaving");
		}
		if (send_view != null) {
		    send_view[0] = gc.group_blocked ? 
			HOT_ENS_MSG_SEND_NEXT_VIEW : HOT_ENS_MSG_SEND_CURRENT_VIEW;
		}
	    }
  	    // write the downcall
	    hioc.begin_write();
	    hioc.write_hdr(gc, hioc.DN_CAST);

	    hioc.write_msg(msg);
	    try {
	        hioc.end_write();
	    } 
	    catch (IOException e) {
		err = new Hot_Error(0, e.toString());
	    }	        
	}
	trace("Hot_Ensemble::Cast end");

	return err;
    }


    /**
    Send a Hot_Message to member specified by the Hot_Endpoint in the group 
    specified by the Hot_GroupContext
    */
    public Hot_Error Send(Hot_GroupContext gc, Hot_Endpoint dest, 
			  Hot_Message msg, int[] send_view) {
	int i =0;
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");

	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_Send: member is leaving");
		}
		if (send_view != null) {
		    send_view[0] = gc.group_blocked ? 
			HOT_ENS_MSG_SEND_NEXT_VIEW : HOT_ENS_MSG_SEND_CURRENT_VIEW;
		}
	    }
	    if (gc.group_blocked) {
                hioc.begin_write();
	        hioc.write_hdr(gc, hioc.DN_SEND_BLOCKED);
	        hioc.write_endpID(dest);
	        hioc.write_msg(msg);
	        try {
		    hioc.end_write();
	        } 
	        catch (IOException e) {
	            err = new Hot_Error(0, e.toString());
	        }	        
	    }
	    else {
	        synchronized(CriticalMutex) {
		    for (i = 0; i < gc.view.length; i++) {
			if (dest.equals(gc.view[i]))
			    break;
		    }
                    hioc.begin_write();
                    hioc.write_hdr(gc, hioc.DN_SEND);
                    hioc.write_int(i);
                    hioc.write_msg(msg);
		    try {
                        hioc.end_write();
	            } 
	            catch (IOException e) {
	                err = new Hot_Error(0, e.toString());
	            }	        
		}
	    }
	}
	return err;
    }


    /**
    NOT SUPPORTED CURRENTLY IN THE ML
    */
    public Hot_Error Suspect(Hot_GroupContext gc, Hot_Endpoint[] suspects) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_Suspect: member is leaving");
		}
	    }
            // write the downcall
	    hioc.begin_write();
            hioc.write_hdr(gc, hioc.DN_SUSPECT);
            hioc.write_endpList(suspects);
	    try {
	        hioc.end_write();
            } 
            catch (IOException e) {
                err = new Hot_Error(0, e.toString());
            }	        
        }
	return err;
    }


    /**
    Infrom Ensemble that state-transfer is complete. 
    */
    public Hot_Error XferDone(Hot_GroupContext gc) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	Hot_Error err = null;
	synchronized(WriteMutex) {
            synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_xfer_done: this member is already leaving");
		}
		gc.leaving = true;
            }
	    // write the downcall.
	    hioc.begin_write();
	    hioc.write_hdr(gc, hioc.DN_XFERDONE);
	    try {
	        hioc.end_write();
	    } 
	    catch (IOException e) {
		err = new Hot_Error(0, e.toString());
	    }	        
	}
	return err;
    }

    /**
    Change the protocol used by the group specified by the Hot_GroupContext 
    to the protocol specified by the String
    */
    public Hot_Error ChangeProtocol(Hot_GroupContext gc, String protocol) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	if (protocol == null) {
 	    Panic("ChangeProtocol: don't send me null garbage!!");
	}
	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_ChangeProtocol: member is leaving");
		}
	    }
            // write the downcall
	    hioc.begin_write();
            hioc.write_hdr(gc, hioc.DN_PROTOCOL);
            hioc.write_string(protocol);
	    try {
	        hioc.end_write();
            } 
            catch (IOException e) {
                err = new Hot_Error(0, e.toString());
            }	        
	}
	return err;
    }


    /**
    Change the properties of the group specified by the Hot_GroupContext 
    to the properties specified by the String
    */
    public Hot_Error ChangeProperties(Hot_GroupContext gc, String properties) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	if (properties == null) {
	    Panic("ChangeProperties: don't send me null garbage!!");
	}
	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_ChangeProperties: member is leaving");
		}
	    }
            // write the downcall
	    hioc.begin_write();
            hioc.write_hdr(gc, hioc.DN_PROPERTIES);
            hioc.write_string(properties);
	    try {
	        hioc.end_write();
            } 
            catch (IOException e) {
                err = new Hot_Error(0, e.toString());
            }	        
	}
	return err;
    }


    /**
    Request a new view in the group specified by the Hot_GroupContext
    */
    public Hot_Error RequestNewView(Hot_GroupContext gc) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_RequestNewView: member is leaving");
		}
	    }
            // write the downcall
	    hioc.begin_write();
            hioc.write_hdr(gc, hioc.DN_PROMPT);
	    try {
	        hioc.end_write();
            } 
            catch (IOException e) {
                err = new Hot_Error(0, e.toString());
            }	        
	}
	return err;
    }


    /**
    Request Ensmeble to rekey the group. 
    */
    public Hot_Error Rekey(Hot_GroupContext gc) {
	if (!outboardValid)
	    return new Hot_Error(55,"Outboard process is not valid!");
	Hot_Error err = null;
	synchronized(WriteMutex) {
	    synchronized(CriticalMutex) {
		if (gc.leaving) {
		    Panic("hot_ens_Rekey: member is leaving");
		}
	    }
            // write the downcall
	    hioc.begin_write();
            hioc.write_hdr(gc, hioc.DN_REKEY);
	    try {
	        hioc.end_write();
            } 
            catch (IOException e) {
                err = new Hot_Error(0, e.toString());
            }	        
	}
	return err;
    }


    /** 
    Receive new view callback and print out info
    */
    void cb_View(int groupID) {
	Hot_ViewState hvs = new Hot_ViewState();
	trace("Hot_Ensemble: VIEW");
	String[] pString = new String[1];

	hioc.read_string(pString);
	hvs.version = pString[0];
	trace("\t version: " + hvs.version);
	
	hioc.read_string(pString);
	hvs.group_name = pString[0];
	trace("\t group_name: " + hvs.group_name);

	int[] pInt = new int[1];
	hvs.members = hioc.read_endpList(pInt);

	for (int i = 0; i < hvs.members.length; i++)
		trace("\t members: " + hvs.members[i]);		

	hvs.nmembers = pInt[0];
	trace("\t nmembers: " + hvs.nmembers);

	hioc.read_int(pInt);
	hvs.rank = pInt[0];
	trace("\t rank: " + hvs.rank);

	hioc.read_string(pString);
	hvs.protocol = pString[0];
	trace("\t protocol: " + hvs.protocol);

	boolean[] pBool = new boolean[1];
	hioc.read_bool(pBool);
	hvs.groupd = pBool[0];
	trace("\t groupd: " + hvs.groupd);
	
	hvs.view_id = new Hot_ViewID();
	hioc.read_int(pInt);
	hvs.view_id.ltime = pInt[0];
	trace("\t view_id.ltime: " + hvs.view_id.ltime);
	
	hvs.view_id.coord = new Hot_Endpoint();
	hioc.read_endpID(hvs.view_id.coord);
	trace("\t view_id.coord: " + hvs.view_id.coord);
	
	hioc.read_string(pString);
	hvs.params = pString[0];
	trace("\t params: " + hvs.params);
	
	hioc.read_bool(pBool);
	hvs.xfer_view = pBool[0];
	trace("\t xfer_view: " + hvs.xfer_view);
	
	hioc.read_bool(pBool);
	hvs.primary = pBool[0];

	hvs.clients = hioc.read_boolList();

	Hot_GroupContext gc = null;
	Object env = null;
	Hot_Callbacks hcb = null;
	
	synchronized(CriticalMutex) {
	    gc = Hot_GroupContext.Lookup(groupID);
	    env = gc.env;
	    hcb = gc.conf;
	    gc.group_blocked = false;
	}

	gc.view = hvs.members;

	hcb.AcceptedView(gc,env,hvs);
	synchronized(CriticalMutex) {
	    // HOT C does some memory cleanup here... we don't have to.
	    gc.joining = false;
	}
	trace("Hot_Ensemble: END VIEW");
    }


    /**
    Multicast msg receive callback
    */
    void cb_Cast(int groupID) {
	Hot_Endpoint hep = new Hot_Endpoint();

	int[] origin = new int[1];
	hioc.read_int(origin);

	Hot_Message hmsg = new Hot_Message();

	hioc.read_msg(hmsg);

	Hot_GroupContext gc = null;
	Object env = null;
	Hot_Callbacks hcb = null;
	synchronized(CriticalMutex) {
	    gc = Hot_GroupContext.Lookup(groupID);
	    env = gc.env;
	    hcb = gc.conf;
	    hep = gc.view[origin[0]];
	}
	if (use_byteStream == false)
	    // the default, uses Hot_ObjectMessages
	    hcb.ReceiveCast(gc,env,hep,hmsg);
	else
    	    // If the use_byteStream flag is set, the user wants
	    // to communicate using simple byte streams instead
	    // of serialized java Objects.  This is the case if
	    // you want to interface with HOT C/Maestro apps.
	    hcb.ReceiveCastByteStream(gc,env,hep,hmsg);
    }


    /**
    Point-to-point msg receive callback
    */
    void cb_Send(int groupID) {
	Hot_Endpoint hep = new Hot_Endpoint();
	int[] origin = new int[1];
	hioc.read_int(origin);

	Hot_Message hmsg = new Hot_Message();

	hioc.read_msg(hmsg);

	Hot_GroupContext gc = null;
	Object env = null;
	Hot_Callbacks hcb = null;

	synchronized(CriticalMutex) {
	    gc = Hot_GroupContext.Lookup(groupID);
	    env = gc.env;
	    hcb = gc.conf;
	    hep = gc.view[origin[0]];
	}
	hcb.ReceiveSend(gc,env,hep,hmsg);
    }


    /**
    Heartbeat receive callback
    */
    void cb_Heartbeat(int groupID) {
	int[] pInt = new int[1];
	pInt[0]=0;

	hioc.read_int(pInt);

	Hot_GroupContext gc = null;
	Object env = null;
	Hot_Callbacks hcb = null;

	synchronized(CriticalMutex) {
	    gc = Hot_GroupContext.Lookup(groupID);
            env = gc.env;
            hcb = gc.conf;
	}
	hcb.Heartbeat(gc,env,pInt[0]);
    }


    /** 
    Block msg receive callback
    */
    void cb_Block(int groupID) {

	Hot_GroupContext gc = null;
	Object env = null;
	Hot_Callbacks hcb = null;
	Hot_Error err = null;

	synchronized(CriticalMutex) {
	    gc = Hot_GroupContext.Lookup(groupID);
	    env = gc.env;
            hcb = gc.conf;
            gc.group_blocked = true;
	}
	hcb.Block(gc,env);

	// write the block_ok downcall
	synchronized(WriteMutex) {
	    hioc.begin_write();
            hioc.write_hdr(gc, hioc.DN_BLOCK_ON);
	    try {
	        hioc.end_write();
            } 
            catch (IOException e) {
                err = new Hot_Error(0, e.toString());
            }	        
	}
    }


    /**
    Exit callback 
    */
    void cb_Exit(int groupID) {
	Hot_GroupContext gc = null;
	Object env = null;
	Hot_Callbacks hcb = null;

	synchronized(CriticalMutex) {
	    gc = Hot_GroupContext.Lookup(groupID);
	    if (!gc.leaving) {
		Panic("hot_ens_Exit_cbd: mbr state is not leaving");
            }
	    env = gc.env;
	    hcb = gc.conf;
	}
	hcb.Exit(gc,env);
	synchronized(CriticalMutex) {
	    Hot_GroupContext.Release(gc);
	}
    }

    /** Mainloop of the process
    */
    public void run() {
	trace("Hot_Ensemble::run() started");
		
	int[] groupID = new int[1];
	int[] cbType = new int[1];
	for(;;) {
            trace("Hot_Ensemble::run() before first read...");
	    if (hioc.begin_read() < 0)
		return;
            hioc.read_groupID(groupID);
            trace("CALLBACK: group ID: " + groupID[0]);
			
            hioc.read_cbType(cbType);
            trace("CALLBACK: cb type: " + cbType[0]);

            if (cbType[0] > 5 || cbType[0] < 0) {
		Panic("HOT: bad callback type: " + cbType[0]);
	    }
            switch (cbType[0]) {
		case 0:    // cb_View
		    cb_View(groupID[0]);
		    break;
		case 1:    // cb_Cast
		    cb_Cast(groupID[0]);
		    break;
		case 2:    // cb_Send
		    cb_Send(groupID[0]);
		    break;
		case 3:    // cb_Heartbeat
		    cb_Heartbeat(groupID[0]);
		    break;
		case 4:    // cb_Block
		    cb_Block(groupID[0]);
		    break;
		case 5:    // cb_Exit
		    cb_Exit(groupID[0]);
		    break;
		default:
		    Panic("HOT: really shouldn't be here...");
	    }
	    hioc.end_read();
	}
    }
 

    /**
    Halts the application with the error specified by the String
    */
    public static void Panic(String s) {
	System.out.println("HOT Panic!: " + s);
	System.exit(45);
    }

	
    /**
    Initializes the critical section mutex
    */
    private void initCritical() {
	CriticalMutex = new Hot_Mutex();
    }
	
	
    /**
    Initializes the write mutex
    */
    private void initWriteCritical() {
	WriteMutex = new Hot_Mutex();
    }


    /**
    Prints (or does not print) the specified string to standard error 
    based upon the debug flag
    */
    public static void trace(String s) {
	if (debug) {
	    System.err.println(s);
	}
    }

// End class Hot_Ensemble
}
