/* There is a shared resource that is the Ensemble socket connection.
 * Multiplextion of access to the shared resource is required. A shared mutex is
 * used to make Ensemble-actions atomic. 
 *
 * The Ensemble-socket: 
 * - works on a per-command basis.
 * - does blocking receive, blocking send. Blocking-sends allow
 *   simply blocking the client trying to perform an action without an
 *   internal queue.
 * - some internal state is required to prepare headers for sending,
 *   and to receive headers from the server.
 *
 * A hashtable of group-contexts.
 * - each group has state associated with it:
 *   (a) user-defined callbacks
 *   (b) state: leaving/joining/ready
 *   (c) group-id : integer
 * - when receiving a new message from the server the Ensemble-thread
 *   looks up the group in the hashtable and calls the appropriate callback. 
 */
/*
 * state for send:
 * - space for send-header, this needs to be a dynamically sized byte-array. 
 *
 * state for receive:
 * - space for receive-header, this needs to be a dynamically sized byte-array.
 * - a byte-array allocated per received command to hold user-data.
 */

/** 
* This namespace contains a client-library allowing an
* application to connect to an Ensemble server. By connecting and
* receiving messages from the Ensemble server the application can
* join/leave reliable multicast groups. It can also reliably send
* point-to-point and multicast message to other group members and learn
* the group membership. Groups behave according to the well known 
* virtual-synchrony model.
*/

/**************************************************************/
/** A wrapper for the actual communication with the Ensemble server.
 * The Connection class hides the message formats for those messages
 * passed between itself and the server.  
 */

package ensemble;

import java.net.*;
import java.io.*;
import java.util.*;

// A dummy class, used to provide a mutex
class Mutex
{
}

public class Connection 
{
    /**
     * The type of a server-to-client message. 
     */
    // Messages from Ensemble.  Must match the ML side.

    /** A new view has arrived from the server. */
    static public final int VIEW = 1;
    /** A multicast message */
    static public final int CAST = 2;
    /** A point-to-point message */
    static public final int SEND = 3;
    /** A block requeset, prior to the installation of a new view */
    static public final int BLOCK = 4;
    /** A final notification that the member is no longer valid */
    static public final int EXIT = 5;
    
    // Downcalls into Ensemble.  Must match the ML side.
    public final int DN_JOIN = 1;
    public final int DN_CAST = 2;
    public final int DN_SEND = 3;
    public final int DN_SEND1 = 4;
    public final int DN_SUSPECT = 5;
    public final int DN_LEAVE = 6;
    public final int DN_BLOCK_OK = 7;
    
    private Socket socket = null;
    private InputStream socketInput = null;
    private OutputStream socketOutput = null;
    private String address = null;
    private int port = 5002;

    // A counter for the member-ids. 
    private int mid = 1;
    
    // receive state
    
    // The precursor to the actual received header, [ml_len, data_len]
    // both in network-byte-order
    private byte[] read_hdr_hdr = new byte[8]; 
    
    // A dynamically-sized byte-array that holds received headers
    private byte[] read_hdr = new byte[1024];  
    
    // A byte-array that holds received user-data. Allocated by
    // the Ensemble-thread and handed over to the user inside the
    // the callback.
    private byte[] read_data = null;
    
    // current position in the array being received. 
    private int read_pos = 0;
    
    // The size of the header
    private int read_hdr_len = 0;
    
    // The size of data
    private int read_data_len = 0;
    
    // send state
    // The precursor to the actual sent header, [ml_len, data_len]
    // both in network-byte-order
    private byte[] write_hdr_hdr = new byte[8];
    
    // A dynamically-sized byte-array that holds send headers
    private byte[] write_hdr = new byte[1024];
    
    // A pointer to the user-data to be sent.
    private byte[] write_data = null;
    
    // current position in the cached send-header array
    private int write_pos = 0;
    
    // The size of the header
    private int write_hdr_len = 0 ;
    
    // scratch space for htonl
    private final int INT_SIZE = 4; //(sizeof(int))
    private byte[] scratch_htonl = new byte[INT_SIZE];
    
    // scratch space for ntohl
    private byte[] scratch_ntohl= new byte[INT_SIZE];
    
    private final int ENS_DESTS_MAX_SIZE=      10;
    private final int ENS_GROUP_NAME_MAX_SIZE= 64;
    private final int ENS_PROPERTIES_MAX_SIZE= 128;
    private final int ENS_PROTOCOL_MAX_SIZE=   256;
    private final int ENS_PARAMS_MAX_SIZE=     256;
    private final int ENS_ENDPT_MAX_SIZE=      48;
    private final int ENS_ADDR_MAX_SIZE=       48;
    private final int ENS_PRINCIPAL_MAX_SIZE=  32;
    private final int ENS_NAME_MAX_SIZE=       ENS_ENDPT_MAX_SIZE+24;
    private final int ENS_VERSION_MAX_SIZE=    8;
    private final int ENS_MSG_MAX_SIZE=        32 *1024;
    
    private Mutex send_mutex = new Mutex ();
    private Mutex recv_mutex = new Mutex ();
    /**************************************************************/
    // Utility functions.
    
    // resize a byte array
    static byte[] resize(byte[] oldA, int newSize)
    {
	byte[] newA;
	
	newA = new byte[newSize];
	System.arraycopy(oldA,0,newA,0,oldA.length);		
	// The old array will be released by the garbage collector
	return newA;
    }
    
    /* Marshal an integer into network byte order onto a buffer at a
     * certain location
     */
    static void htonl(int i, byte[] buf,int ofs)
    {
	buf[ofs  ] = (byte) ((i >> 24) & 0xFF);
	buf[ofs+1] = (byte) ((i >> 16) & 0xFF);
	buf[ofs+2] = (byte) ((i >> 8 ) & 0xFF);
	buf[ofs+3] = (byte) ((i      ) & 0xFF);
    }
    
    static int ntohl(byte[] buf, int ofs)
    {
	int i0 = (buf[ofs  ] & 0xFF);
	int i1 = (buf[ofs+1] & 0xFF);
	int i2 = (buf[ofs+2] & 0xFF);
	int i3 = (buf[ofs+3] & 0xFF);
	
	return ((i0 << 24) | (i1 << 16) | (i2 << 8) | (i3));
    }
    
    /**************************************************************/
    // Allocate a member id. The id must be unique during this connection
    int AllocMid()
    {
	return mid++;
    }
    
    /**************************************************************/
    /* A Hashtable of group contexts
     * 
     * Note: This version of C# does not support generics, so we need to
     * use casting.
     */
    private Hashtable memb_ctx_tbl = new Hashtable() ;
    
    /* Allocate a new context.
     * The global data record must be locked at this point.
     */
    void ContextAdd(Member m)
    {
	Object old = memb_ctx_tbl.put(new Integer(m.id), (Object) m);
	if (old != null) {
	    System.out.println("Such a context already exists");
	    System.exit(1);
	}
    }
    
    /* Release a context descriptor.
     */
    private void ContextRemove(Member m)
    {
	memb_ctx_tbl.remove(new Integer(m.id));
    }
    
    /* Lookup a context descriptor.
     */
    private Member ContextLookup(int id)
    {
	return (Member) this.memb_ctx_tbl.get(new Integer(id));
    }
    /**************************************************************/
    
    private void WriteBegin()
    {
	write_hdr_len = 0 ;
    }
    
    private void WriteDo(byte[] buf,int len)
    {
	if (write_pos+len > write_hdr.length) 
	    {
		int new_size = write_hdr.length;
		while (write_pos+len > new_size)
		    new_size *= 2 ;
		write_hdr = resize(write_hdr, new_size);
	    }
	
	// copy into the preallocated send-header array
	System.arraycopy(buf,0,write_hdr,write_pos,len);
	write_pos += len ;
    }
    
    /* Take note to first write the ML length, and then
     * the data length. 
     */
    private void WriteEnd() throws EnsembleException
    {
	try {
	    /* Compute header length. The ML header length is equal to our
	     * current position in the write buffer.
	     */
	    write_hdr_len = write_pos;
	    
	    // Marshal header length
	    htonl(write_hdr_len, write_hdr_hdr, 0) ;
	    // Marshal data length
	    if (null == write_data) 
		htonl(0,write_hdr_hdr, 4 ) ;
	    else 
		htonl(write_data.length,write_hdr_hdr, 4 ) ;
	    
	    // Send the precursor
	    socketOutput.write(write_hdr_hdr,0,8);
	    
	    // Send the header
	    socketOutput.write(write_hdr,0,write_hdr_len);
	    
	    // Send the data buffer, the GC will collect it later. 
	    if (write_data != null 
		&& write_data.length > 0)
		socketOutput.write(write_data, 0, write_data.length);
	    
	    // reset 
	    write_pos = 0 ;
	    
	    // Erase any references to the data, otherwise, we'll have a memory leak
	    write_data = null;
	    
	    // Shrink the buffer if it is >64K.
	    if (write_hdr.length > 1<<16) 
		{
		    // The GC will collect the old buffer later.
		    write_hdr = new byte[1<<12];
		}
	}
	catch (IOException e)
	    {
		throw new EnsembleException("Socket error:" + e);
	    }
    }
    
    /* Read from the input socket into buffer[buf] at offset [ofs]
     * [len] bytes
     */
    private void conn_read(byte[] buf, int begin_ofs, int total_len)
        throws java.io.IOException
    {
        int pos = 0;
	
        while (pos < total_len) {
            pos += socketInput.read(buf, begin_ofs+pos, total_len-pos);
        }
    }
    
    /* Read from the network a complete message.
     * This call is blocking. 
     */
    private void ReadBegin() throws EnsembleException
    {
	try {
	    /* Read precursor. This will give the size of the header and the 
	     * size of the user-data. A total of 8 bytes should be read. 
	     */
	    
	    conn_read(read_hdr_hdr,0,8);
	    read_hdr_len = ntohl(read_hdr_hdr,0);
	    read_data_len = ntohl(read_hdr_hdr,4);
	    
            if (0 == read_hdr_len) {
                System.out.println("read_data_len=" + read_data_len);
		throw new EnsembleException("sanity: header_len == 0");
            }
	    
            /* Ensure there is enough room in the read buffer.
	     */
	    if (read_hdr_len > read_hdr.length) 
		{
		    int new_size = read_hdr.length;
		    while (read_hdr_len > new_size)
			new_size *= 2 ;
		    read_hdr = resize(read_hdr,new_size);
		}
	    
	    // Keep reading until we have the entire message.
	    read_pos = 0 ;
	    
	    // Read the ML header
	    conn_read(read_hdr, 0, read_hdr_len);
	    
	    // Read the bulk data
	    if (read_data_len > 0) 
		{
		    read_data = new byte[read_data_len];
		    conn_read(read_data, 0, read_data_len);
		}
	}
	catch (IOException e)
	    {
		throw new EnsembleException("Socket error:" + e);
	    }
    }
    
    private void ReadDo(byte[] buf,int len) throws EnsembleException
    {
	//    assert(len <= g.read_size - g.read_pos) ;
	System.arraycopy(read_hdr,read_pos,buf,0,len);
	read_pos += len ;
    }
    
    // Cleanup at the end of reading a message  
    private void ReadEnd() throws EnsembleException
    {
	// make sure we read -all- the message.
	if (read_pos != read_hdr_len) 
	    {
		System.out.println("ReadEnd error read_pos=" + read_pos + " read_hdr_len=" + read_hdr_len);
		throw new EnsembleException("sanity: haven't read a full message");
	    }
	read_pos = 0 ;
	read_data = null;
    }
    
    // Send an integer
    private void WriteInt(int i)
    {
	htonl(i,scratch_htonl,0);
	WriteDo(scratch_htonl,INT_SIZE);
	//    ce_trace(NAME, "write_int: %d", i);
    }
    
    // Send a boolean
    private void WriteBool(boolean b)
    {
	if (b) WriteInt(1);
	else WriteInt(0);
    }
    
    // Write a byte-array into the header. For example, the security key. 
    private void WriteByteArray(byte[] buf)
    {
	if (null == buf) 
	    {
		WriteInt(0);
	    } 
	else 
	    {
		WriteInt(buf.length);
		WriteDo(buf,buf.length);
	    }
    }
    
    /* Write a String into the header, for example: protocol, protoperies.
     * Be careful to convert unicode to ASCII.
     */
    private void WriteString(String s)
    {
	if (null == s) 
	    {
		WriteInt(0);
	    } 
	else 
	    {
		byte[] buf = s.getBytes(); // lossy!!! Ensemble wants ASCII, we have UNICODE
		WriteByteArray(buf);
	    }
    }
    
    
    private void WriteHdr(Member m, int /*DnType*/ type)
    {
	//    ce_trace(NAME, "write_hdr:id=%d, type=%d(%s)",s->intf->id, type, type.ToString() ) ;
	WriteInt(m.id);
	WriteInt((int)type);
    }
    
    /* WriteData is the last call before a message is packaged and
     * sent. Record byte-array so that WriteEnd will
     * write the data on the outgoing packet.
     */
    private void WriteData(byte[] data) throws EnsembleException
    {
        if (data.length > ENS_MSG_MAX_SIZE)
	    throw new EnsembleException("User asked to send a message larger than" +
                                        ENS_MSG_MAX_SIZE);
	write_data = data;
    }
    
    /**************************************************************/
    
    // read an integer value from a message
    private int ReadInt() throws EnsembleException
    {
	int tmp;
	ReadDo(scratch_ntohl, INT_SIZE);
	tmp = ntohl(scratch_ntohl,0);
	//    ce_trace(NAME, "ReadInt: %d", tmp);
	return tmp;
    }
    
    // read a boolean value from a message
    private boolean ReadBool() throws EnsembleException
    {
	int tmp;
	tmp = ReadInt();
	return (tmp != 0) ;
    }
    
    
    // Allocate and copy into a buffer.
    private String ReadString(int max_size) throws EnsembleException
    {
	int size;
	byte[] buf;
	String str;
	
	size = ReadInt();
	if (0 == size) return null;
	if (size > max_size)
	    throw new EnsembleException("internal error, string larger than requested" + max_size + "bytes>");
	buf = new byte[size];
	ReadDo(buf, size);
	
	//    ce_trace(NAME, "read_string: <%d> %s", size, buf);
	return new String(buf);
    }
    
    // read the endpoint name
    private String ReadEndpt() throws EnsembleException
    {
	return ReadString(ENS_ENDPT_MAX_SIZE);
    }
    
    // read the member id
    private int ReadContextID() throws EnsembleException
    {
	return ReadInt();
    }
    
    // Read the data portion from a message
    private byte[] ReadData() throws EnsembleException
    {
	return read_data;
    }
    
    // Read an array of strings
    private String[] ReadStringArray(int max_size) throws EnsembleException
    {
	int i, size;
	String[] sa;
	
	size = ReadInt ();
	sa = new String[size];
	
	for (i = 0; i < size; i++)
	    sa[i] = ReadString(max_size);
	
	return sa;
    }
    
    //Read an array of endpoint names
    private String[] ReadEndptArray() throws EnsembleException
    {
	return ReadStringArray(ENS_ENDPT_MAX_SIZE);
    }
    
    //Read an array of addresses
    private String[] ReadAddrArray() throws EnsembleException
    {
	return ReadStringArray(ENS_ADDR_MAX_SIZE);
    }
    
    // read the callback type
    private int /*UpType*/ ReadUpType() throws EnsembleException
    {
	return ReadInt();
    }
    
    // read a view-id
    private ViewId ReadViewId() throws EnsembleException
    {
	ViewId vid = new ViewId();
	
	vid.ltime = ReadInt();
	vid.endpt = ReadEndpt();
	return vid;
    }
    
    // Read an array of view-ids
    private ViewId[] ReadViewIdArray() throws EnsembleException
    {
	ViewId[] vida;
	int i, size;
	
	size = ReadInt ();
	if (0 == size) return null;
	vida = new ViewId[size];
	for (i=0; i<size; i++)
	    vida[i] = ReadViewId();
	return vida;
    }
    
    /**************************************************************/
    
    private Message RecvView(Member m) throws EnsembleException
    {
	View view = new View();
	Message msg = new Message();
	
	view.nmembers = ReadInt ();
	view.version = ReadString (ENS_VERSION_MAX_SIZE);
	view.group = ReadString(ENS_GROUP_NAME_MAX_SIZE);
	view.proto = ReadString(ENS_PROTOCOL_MAX_SIZE);
	view.ltime = ReadInt ();
	view.primary = ReadBool ();
	view.parameters=ReadString (ENS_PARAMS_MAX_SIZE);
	view.address = ReadAddrArray ();
	view.endpts = ReadEndptArray ();
	view.endpt = ReadEndpt ();
	view.addr= ReadString(ENS_ADDR_MAX_SIZE);
	view.rank = ReadInt ();
	view.name = ReadString(ENS_NAME_MAX_SIZE);
	view.view_id = ReadViewId();
	
	// The group is unblocked now.
	m.current_status=Member.Normal;
	m.current_view = view;
	
	msg.mtype = VIEW;
	msg.view = view;
	return msg;
    }
    
    private Message RecvCast(Member m) throws EnsembleException
    {
	int origin ;
	byte[] data;
	Message msg = new Message ();
	
	//    ce_trace(NAME, "cb_Cast");
	origin = ReadInt();
	data = ReadData();
	
	//    assert(origin < s->nmembers) ;
	msg.mtype = CAST;
	msg.origin = origin;
	msg.data = data;
	return msg;
    }
    
    private Message RecvSend(Member m) throws EnsembleException
    {
	int origin ;
	byte[] data;
	Message msg = new Message ();
	
	//    ce_trace(NAME, "cb_Send");
	origin = ReadInt();
	data = ReadData();
	
	//    assert(origin < s->nmembers) ;
	msg.mtype= SEND;
	msg.origin = origin;
	msg.data = data;
	return msg;
    }
    
    private Message RecvBlock(Member m)
    {
	Message msg = new Message ();
	msg.mtype = BLOCK;
	return msg;
    }
    
    private Message RecvExit(Member m) throws EnsembleException
    {
	Message msg = new Message ();
	
	if (!(Member.Leaving == m.current_status))
	    throw new EnsembleException("CbExit: mbr state is not leaving");
	
	msg.mtype = EXIT;
	
	/* Remove the context from the hashtable, we shall no longer deliver
	 * messages to it
	 */
	ContextRemove(m);
	
	// Tell members that this member is no longer valid
	m.current_status = Member.Left;
	
	return msg;
    }
    
    /************************ User Downcalls ****************************/
    
    // Check that the member is in a Normal status 
    private void CheckValid(Member m) throws EnsembleException
    {
	switch (m.current_status) 
	    {
	    case Member.Normal:
		break;
	    default:
		throw new EnsembleException("Operation while group is " + 
					    Member.StatusToString(m.current_status) + 
					    "gid=" + m.id);
	    }
    }
    
    /* Join a group.  The group context is returned in *contextp.  
     */
    void Join(Member m, JoinOps ops) throws EnsembleException
    {
	synchronized(send_mutex) 
	    {
		
		/* Check that this is a fresh Member, e.g., we haven't already
		 * joined a group with it.
		 */
		if (m.current_status != Member.Pre) 
		    throw new EnsembleException("Trying to Join more than once");
		
		// Update the state of the member to Joining
		m.current_status = Member.Joining;
		
		// We must provide the member with an ID prior to any other operation
		m.id = AllocMid();
		
		WriteBegin(); 
		// Write the downcall.
		WriteHdr(m,DN_JOIN);
		WriteString(ops.group_name);
		WriteString(ops.properties);
		WriteString(ops.parameters);
		WriteString(ops.princ);
		WriteBool(ops.secure);
		WriteEnd();
		
		// Add the member to the hashtable. This will allow
		// finding it when messages arrive on the socket.
		ContextAdd(m);
	    }
    }
    
    /* Leave a group. This should be the last call made to the member
     * It is possible for messages to be delivered to this member after the call
     * returns. However, it is illegal to initiate new actions on this member.
     */
    void Leave(Member m) throws EnsembleException
    {
	synchronized(send_mutex) 
	    {
		CheckValid(m);
		m.current_status=Member.Leaving;
		
		WriteBegin(); 
		// Write the downcall.
		WriteHdr(m,DN_LEAVE);
		WriteEnd();
	    }
    }
    
    // Send a multicast message to the group.
    void Cast(Member m,  byte[] data) throws EnsembleException
    {
	synchronized(send_mutex) 
	    {
		CheckValid(m);
		WriteBegin();
		WriteHdr(m,DN_CAST);
		WriteData(data);
		WriteEnd();
	    }
    }
    
    // Send a point-to-point message to a list of members.
    void Send(Member m, int[] dests, byte[] data) throws EnsembleException
    {
	int i;
	
        if (dests.length > ENS_DESTS_MAX_SIZE)
            throw new EnsembleException ("Send to more than" + ENS_DESTS_MAX_SIZE +
                                         "destinations");
	synchronized(send_mutex) 
	    {
		CheckValid(m);
		WriteBegin();
		WriteHdr(m,DN_SEND);
		WriteInt(dests.length);
		for (i=0; i<dests.length; i++) 
		    {
			if (dests[i] < 0
			    || dests[i] > m.current_view.nmembers)
		    throw new EnsembleException("destination out of bounds, nmembers=" +
						m.current_view.nmembers +
						" destination=" + dests[i]);
			WriteInt(dests[i]);
		    }
		WriteData(data);
		WriteEnd();
	    }
    }
    
    // Send a point-to-point message to the specified group member.
    void Send1(Member m, int dest, byte[] data) throws EnsembleException
    {
	synchronized(send_mutex) 
	    {
		CheckValid(m);
		if (dest < 0
		    || dest > m.current_view.nmembers)
		    throw new EnsembleException("destination out of bounds, nmembers=" +
						m.current_view.nmembers +
						" destination=" + dest);
		WriteBegin();
		WriteHdr(m,DN_SEND1);
		WriteInt(dest);
		WriteData(data);
		WriteEnd();
	    }
    }
    
    // Report group members as failure-suspected.
    void Suspect(Member m, int[] suspects) throws EnsembleException
    {
	int i;
	
        if (suspects.length > ENS_DESTS_MAX_SIZE)
            throw new EnsembleException ("Suspecting more than" + ENS_DESTS_MAX_SIZE +
                                         "endpoints");
	synchronized(send_mutex) 
	    {
		CheckValid(m);
		WriteBegin();
		WriteHdr(m,DN_SUSPECT);
		WriteInt(suspects.length);
		for (i=0; i<suspects.length; i++) 
		    {
			if (suspects[i] < 0
			    || suspects[i] > m.current_view.nmembers) 
			    throw new EnsembleException("Suspicion out of bounds, nmembers=" +
							m.current_view.nmembers +
							"destination=" + suspects[i]);
			WriteInt(suspects[i]);
		    }
		WriteEnd();
	    }
    }
    
    // Send a BlockOk
    void BlockOk(Member m) throws EnsembleException
    {
	// Write the block_ok downcall.
	synchronized(send_mutex) 
	    {
		CheckValid(m);
		WriteBegin();
		WriteHdr(m,DN_BLOCK_OK) ;
		WriteEnd();
		
		// Update the member state to Blocked. 
		m.current_status = Member.Blocked;
	    }
    }
    
    /// <summary> Check if there is a pending message. If it returns true then Recv will 
    /// return with a message. 
    /// </summary>
    public boolean Poll() throws EnsembleException
    {
	try {
	    if (socketInput.available() > 0) return true;
	    else return false;
	}
	catch (IOException e)
	    {
		throw new EnsembleException("Poll error:" + e);
	    }
    }
    
    /// <summary> Receive a single message. This is a blocking call, return only when 
    /// a complete message arrives.
    /// </summary>
    public Message Recv() throws EnsembleException
    {
	int /*UpType*/ cb;
	int id;
	Member m;
	Message msg = null;
	
	synchronized(recv_mutex) 
	    {
		ReadBegin() ;
		id = ReadContextID();
		//	    TRACE_D("CALLBACK: group ID: ", id);
		
		cb = ReadUpType();
		m = ContextLookup(id);
		
		/* Check which message type this is and dispatch accordingly.
		 */
		switch(cb) 
		    {
		    case VIEW:
			msg = RecvView(m);
			break;
		    case CAST:
			msg = RecvCast(m);
			break;
		    case SEND:
			msg = RecvSend(m);
			break;
		    case BLOCK:
			msg = RecvBlock(m);
			break;
		    case EXIT:
			msg = RecvExit(m);
			break;
		    default:
			throw new EnsembleException("Bad upcall type");
		    }
		ReadEnd();
	    }

	// Let the user know which member this message
	// blongs to.
	msg.m = m;
	return msg;
    }
    
    /// <summary> Connect to the Ensemble server. Prior to this call any attempt to use
    /// this connection will fail.
    /// </summary>
    public void Connect ()  throws EnsembleException
    {
	synchronized(this) 
	    {
		try 
		    {
			socket = new Socket("127.0.0.1", port);
			socketInput = socket.getInputStream();
			socketOutput = socket.getOutputStream();
		    }
		catch (IOException e) 
		    {
			throw new EnsembleException("Could not connect to the Ensemble server");
		    }
	    }
    }
}
