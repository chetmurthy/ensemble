/**************************************************************/
/* GROUP.CS */
/* Author: Ohad Rodeh 7/2003 */
/**************************************************************/
/* A C# based client for ce_outboard. 
 */
/**************************************************************/

using System;
using System.Collections;
using System.Net;
using System.Net.Sockets;
using System.Threading;

/* There is a shared resource that is the Ensemble socket connection.
 * Multiplextion of access to the shared resource is required. This is
 * done by spawning a thread to perform the socket communication, we
 * call this the "Ensemble-thread". A shared mutex is used to make
 * Ensemble-actions atomic. All callbacks are performed in the context
 * of the Ensemble-thread, this takes care of atomicity on the receive path. 
 *
 * The Ensemble-socket: 
 * - works on a per-command basis.
 * - does non-blocking receive, blocking send. Blocking-sends allow
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

/// <remarks>
/// This namespace contains a client-library allowing an
/// application to connect to an Ensemble server. By connecting and
/// receiving messages from the Ensemble server the application can
/// join/leave reliable multicast groups. It can also reliably send
/// point-to-point and multicast message to other group members and learn
/// the group membership. Groups behave according to the well known 
/// virtual-synchrony model.
/// </remarks>
namespace Ensemble 
{
	/// <summary>
	/// The type of a server-to-client message. 
	/// </summary>
	// Messages from Ensemble.  Must match the ML side.
	public enum UpType {
		/// <summary> A new view has arrived from the server.</summary>
		VIEW,
		/// <summary> A multicast message </summary>
		CAST,
		/// <summary> A point-to-point message </summary>
		SEND,
		/// <summary> A periodic heartbeat, is about to be deprecated </summary>
		HEARTBEAT,
		/// <summary> A block requeset, prior to the installation of a new view </summary>
		BLOCK,
		/// <summary> A final notification that the member is no longer valid </summary>
		EXIT
	};
	
	// Downcalls into Ensemble.  Must match the ML side.
	enum DnType {
		DN_JOIN,
		DN_CAST,
		DN_SEND,
		DN_SEND1,
		DN_SUSPECT,
		DN_XFERDONE,
		DN_PROTOCOL,
		DN_PROPERTIES,
		DN_LEAVE,
		DN_PROMPT,
		DN_REKEY,
		DN_BLOCK_OK,
	} ;
	
	/// <summary> A unique identifier for a view. </summary>
	public class ViewId {
		/// <summary> the logical time </summary>
		public int ltime;
		/// <summary> the leader endpoint </summary>
		public string endpt;
	}
	
	/// <summary>
	/// The set of information contained in a view. 
	/// </summary>
	public class View {
		// ViewState
		
		/// <summary> The Ensemble version </summary>
		public string version;
		
		/// <summary> protocol stack in use  </summary>
		public string proto;
		
		/// <summary> group name  </summary>
		public string group;
		
		/// <summary> coordinator's rank  </summary>
		public int coord;
		
		/// <summary> logical time  </summary>
		public int ltime;
		
		/// <summary> this a primary view?  </summary>
		public bool primary;
		
		/// <summary> we using the group-daemon  </summary>
		public bool groupd;
		
		/// <summary> this a state-transfer view?  </summary>
		public bool xfer_view;
		
		/// <summary> set of views that merged into this one. </summary>
		public ViewId[] prev_ids;
		
		/// <summary> parameters used for this group  </summary>
		public string parameters;
		
		/// <summary> time this group has been up and running  </summary>
		public double uptime;
		
		/// <summary> list of endpoints in this view  </summary>
		public string[] view;
		
		/// <summary> list of communication addresses  </summary>
		public string[] address;
		
		// local state
		/// <summary> local endpoint name  </summary>
		public string endpt;
		
		/// <summary> local address  </summary>
		public string addr;
		
		/// <summary> local rank  </summary>
		public int rank;
		
		/// <summary> group name. This does not change thoughout the lifetime of the group. </summary>
		public string name;
		
		/// <summary> number of members in the view  </summary>
		public int nmembers;
		
		/// <summary> view identifier </summary>
		public ViewId view_id;
		
		/// <summary> I the coordinator?  </summary>
		public bool am_coord;
		
		/// <summary> security key. </summary>
		public byte[] key;
	}
	
	public class Message {
		/// <summary> endpoint this message blongs to </summary>
		public Member m;           

		/// <summary> message type </summary>
		public UpType mtype ;
		
		/// <summary> view message </summary>
		public View view;
		
		/// <summary> multicast/pt2pt message origin </summary>
		public int origin;
		/// <summary> multicast/pt2pt message data </summary>
		public byte[] data;
		
		/// <summary> heartbeat message </summary>
		public double time;
	}

	public class EnsembleException : System.Exception {
		public EnsembleException(string text):base(text) {
		}
	}
	
	
	/**************************************************************/
	/** JoinOps binds together the list of properties requested from
	 * a Group when it is created. 
	 */
	public class JoinOps {
		/// <summary> The default set of properties </summary>
		public const string DEFAULT_PROPERTIES =
		"Gmp:Switch:Sync:Heal:Frag:Suspect:Flow:Slander";
		
		/// <summary> The rate of heartbeats provided. Every xxx time,
		/// a new HEARTBEAT message will be created
		/// </summary>
		public double hrtbt_rate = 10.0;
		
		/// <summary> What is the requested transport layer. At the time of
		/// writing the supported list was is [Multicast, UDP, TCP].
		/// </summary>
		public string transports = "DEERING";
		
		/// <summary> group-communication stack to be used.   </summary>
		public string protocol = null;
		
		/// <summary> group name.   </summary>
		public string group_name = null;
		
		/// <summary> requsted list of properties.  </summary>
		public string properties = DEFAULT_PROPERTIES;
		
		/// <summary> Both properties and protocol can be used to determine the stack.
		/// use_properties arbiterates between them.
		/// </summary>
		public bool use_properties = true;
		
		/// <summary> the group-daemon server?  </summary>
		public bool groupd = false;
		
		/// <summary> parameters to pass to Ensemble.  </summary>
		public string parameters = null;
		
		public bool client = false;
		
		/// <summary> a debugging stack?  </summary>
		public bool debug = false;
		
		/// <summary> the endpoint name  </summary>
		public string endpt = null;
		
		/// <summary> principal name  </summary>
		public string princ = null;
		
		/// <summary> key  </summary>
		public byte[] key = null;
		
		/// <summary> a secure stack?  </summary>
		public bool secure = false;
	}
	
	
	/**************************************************************/
	/** A wrapper for the actual communication with the Ensemble server.
	 * The Connection class hides the message formats for those messages
	 * passed between itself and the server.  
	 */
	public class Connection 
	{
		private TcpClient socket = null;
		private NetworkStream stream = null;
		private string address = null;
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
		private const int INT_SIZE = 4; //(sizeof(int))
		private byte[] scratch_htonl = new byte[INT_SIZE];
		
		// scratch space for ntohl
		private byte[] scratch_ntohl= new byte[INT_SIZE];
		
		private const int CE_TRANSPORT_MAX_SIZE=  32;
		private const int CE_PROTOCOL_MAX_SIZE=   256;
		private const int CE_GROUP_NAME_MAX_SIZE= 64;
		private const int CE_PROPERTIES_MAX_SIZE= 128;
		private const int CE_PARAMS_MAX_SIZE=     256;
		private const int CE_ENDPT_MAX_SIZE=      48;
		private const int CE_ADDR_MAX_SIZE=       48;
		private const int CE_PRINCIPAL_MAX_SIZE=  32;
		private const int CE_KEY_SIZE=            32;
		private const int CE_NAME_MAX_SIZE=       CE_ENDPT_MAX_SIZE+24;
		private const int CE_VERSION_MAX_SIZE=    8;
		
		/**************************************************************/
		// Allocate a member id. The id must be unique during this connection
		internal int AllocMid()
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
		internal void ContextAdd(Member m)
		{
			memb_ctx_tbl.Add(m.id, m);
		}
		
		/* Release a context descriptor.
		 */
		private void ContextRemove(Member m)
		{
			memb_ctx_tbl.Remove(m);
		}
		
		/* Lookup a context descriptor.
		 */
		private Member ContextLookup(int id)
		{
			return (Member) this.memb_ctx_tbl[id];
		}
		/**************************************************************/
		// Utility functions.
		
		// resize a byte array
		private static byte[] resize(byte[] oldA, int newSize)
		{
			byte[] newA;
			
			newA = new byte[newSize];
			Array.Copy(oldA,0,newA,0,oldA.Length);		
			// The old array will be released by the garbage collector
			return newA;
		}
		
		/* Marshal an integer into network byte order onto a buffer at a
		 * certain location
		 */
		private static void htonl(int i, byte[] buf,int ofs)
		{
			buf[ofs  ] = (byte) ((i >> 24) & 0xFF);
			buf[ofs+1] = (byte) ((i >> 16) & 0xFF);
			buf[ofs+2] = (byte) ((i >> 8 ) & 0xFF);
			buf[ofs+3] = (byte) ((i      ) & 0xFF);
		}
		
		private static int ntohl(byte[] buf, int ofs)
		{
			int i0 = (buf[ofs  ] & 0xFF);
			int i1 = (buf[ofs+1] & 0xFF);
			int i2 = (buf[ofs+2] & 0xFF);
			int i3 = (buf[ofs+3] & 0xFF);
			
			return ((i0 << 24) | (i1 << 16) | (i2 << 8) | (i3));
		}
		
		/**************************************************************/
		
		private void WriteBegin()
		{
			write_hdr_len = 0 ;
		}
		
		private void WriteDo(byte[] buf,int len)
		{
			if (write_pos+len > write_hdr.Length) 
			{
				int new_size = write_hdr.Length;
				while (write_pos+len > new_size)
					new_size *= 2 ;
				write_hdr = resize(write_hdr, new_size);
			}
			
			// copy into the preallocated send-header array
			Array.Copy(buf,0,write_hdr,write_pos,len);
			write_pos += len ;
		}
		
		/* Take note to first write the ML length, and then
		 * the data length. 
		 */
		private void WriteEnd()
		{
			
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
				htonl(write_data.Length,write_hdr_hdr, 4 ) ;
			
			// Send the precursor
			stream.Write(write_hdr_hdr,0,8);
			
			// Send the header
			stream.Write(write_hdr,0,write_hdr_len);
			
			// Send the data buffer, the GC will collect it later. 
			if (write_data != null 
				&& write_data.Length > 0)
				stream.Write(write_data, 0, write_data.Length);
			
			// reset 
			write_pos = 0 ;
			
			// Erase any references to the data, otherwise, we'll have a memory leak
			write_data = null;
			
			// Shrink the buffer if it is >64K.
			if (write_hdr.Length > 1<<16) 
			{
				// The GC will collect the old buffer later.
				write_hdr = new byte[1<<12];
			}
		}
		
		/* Read from the network a complete message.
		 * This call is blocking. 
		 */
		private void ReadBegin()
		{
			/* Read precursor. This will give the size of the header and the 
			 * size of the user-data. A total of 8 bytes should be read. 
			 */

			stream.Read(read_hdr_hdr,0,8);
			read_hdr_len = ntohl(read_hdr_hdr,0);
			read_data_len = ntohl(read_hdr_hdr,4);
			
			/* Ensure there is enough room in the read buffer.
			 */
			if (read_hdr_len > read_hdr.Length) 
			{
				int new_size = read_hdr.Length;
				while (read_hdr_len > new_size)
					new_size *= 2 ;
				read_hdr = resize(read_hdr,new_size);
			}
			
			// Keep reading until we have the entire message.
			read_pos = 0 ;
			
			// Read the ML header
			stream.Read(read_hdr, 0, read_hdr_len);
			
			// Read the bulk data
			if (read_data_len > 0) 
			{
				read_data = new byte[read_data_len];
				stream.Read(read_data, 0, read_data_len);
			}
		}
		
		private void ReadDo(byte[] buf,int len)
		{
			//    assert(len <= g.read_size - g.read_pos) ;
			Array.Copy(read_hdr,read_pos,buf,0,len);
			read_pos += len ;
		}
		
		// Cleanup at the end of reading a message  
		private void ReadEnd()
		{
			// make sure we read -all- the message.
			if (read_pos != read_hdr_len) 
			{
				Console.WriteLine("ReadEnd error read_pos=" + read_pos + " read_hdr_len=" + read_hdr_len);
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
		private void WriteBool(bool b)
		{
			if (b) WriteInt(1);
			else WriteInt(0);
		}
		
		/* Convert time in double, to the Ensemble format: 
		 * (1) sec10, an integer describing time in 10s of seconds.
		 * (2) usec, an integer describing time 10s of microseconds.
		 */
		private int MILLION=1000000;
		
		private void WriteTime(double time)
		{
			double tmp;
			int sec10;
			int usec10;
			
			tmp = time / 10.0;
			
			sec10 =  (int) tmp;
			usec10 = (int)((tmp - sec10) * MILLION) ;
			//printf("sec10=%d, usec10=%d\n", sec10, usec10);
			WriteInt(sec10);
			WriteInt(usec10);
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
				WriteInt(buf.Length);
				WriteDo(buf,buf.Length);
			}
		}

		/* Write a string into the header, for example: protocol, protoperies.
		 * Be careful to convert unicode to ASCII.
		 */
		private void WriteString(string s)
		{
			if (null == s) 
			{
				WriteInt(0);
			} 
			else 
			{
				byte[] buf = System.Text.Encoding.ASCII.GetBytes(s);
				WriteByteArray(buf);
			}
		}
		
		
		private void WriteHdr(Member m, DnType type)
		{
			//    ce_trace(NAME, "write_hdr:id=%d, type=%d(%s)",s->intf->id, type, type.ToString() ) ;
			WriteInt(m.id);
			WriteInt((int)type);
		}
		
		/* WriteData is the last call before a message is packaged and
		 * sent. Record byte-array so that WriteEnd will
		 * write the data on the outgoing packet.
		 */
		private void WriteData(byte[] data)
		{
			write_data = data;
		}
		
		/**************************************************************/
		
		// read an integer value from a message
		private int ReadInt()
		{
			int tmp;
			ReadDo(scratch_ntohl, INT_SIZE);
			tmp = ntohl(scratch_ntohl,0);
			//    ce_trace(NAME, "ReadInt: %d", tmp);
			return tmp;
		}
		
		// read a boolean value from a message
		private bool ReadBool()
		{
			int tmp;
			tmp = ReadInt();
			return (tmp != 0) ;
		}
		
		
		/* Here, we read a 64bit value, split into:
		 * sec10, an integer describing time in 10s of seconds.
		 * usec, an integer describing time 10s of microseconds.
		 */
		private double ReadTime()
		{
			double tmp;
			int sec10;
			int usec10;
			
			sec10 = ReadInt();
			usec10 = ReadInt();
			tmp = (sec10 * 10 * MILLION + usec10 * 10) / MILLION;
			
			return tmp;
		}
		
		
		// Allocate and copy into a buffer.
		private string ReadString(int max_size)
		{
			int size;
			byte[] buf;
			string str;
			
			size = ReadInt();
			if (0 == size) return null;
			if (size > max_size)
				throw new EnsembleException("CE-outboard, internal error, string larger than requested" + max_size + "bytes>");
			buf = new byte[size];
			ReadDo(buf, size);
			
			//    ce_trace(NAME, "read_string: <%d> %s", size, buf);
			str = System.Text.Encoding.ASCII.GetString(buf, 0, size);
			return str;
		}
		
		// Allocate and copy into a buffer.
		private byte[] ReadKey()
		{
			int size;
			byte[] buf;
			
			size = ReadInt();
			if (size == 0) return null;
			else if (size != CE_KEY_SIZE && size != 0) 
			{
				throw new EnsembleException("CE internal error, bad key size, (size=" + size + ")");
			}
			else 
			{
				buf = new byte[size];
				ReadDo(buf, size);
				//    ce_trace(NAME, "read_string: <%d> %s", size, buf);
				return buf;
			}
		}
		
		// read the endpoint name
		private string ReadEndpt()
		{
			return ReadString(CE_ENDPT_MAX_SIZE);
		}
		
		// read the member id
		private int ReadContextID()
		{
			return ReadInt();
		}
		
		// Read the data portion from a message
		private byte[] ReadData()
		{
			return read_data;
		}
		
		// Read an array of strings
		private string[] ReadStringArray(int max_size)
		{
			int i, size;
			string[] sa;
			
			size = ReadInt ();
			sa = new string[size];
			
			for (i = 0; i < size; i++)
				sa[i] = ReadString(max_size);
			
			return sa;
		}
		
		//Read an array of endpoint names
		private string[] ReadEndptArray()
		{
			return ReadStringArray(CE_ENDPT_MAX_SIZE);
		}
		
		//Read an array of addresses
		private string[] ReadAddrArray()
		{
			return ReadStringArray(CE_ADDR_MAX_SIZE);
		}
		
		// read the callback type
		private UpType ReadUpType()
		{
			return (UpType)ReadInt();
		}
		
		// read a view-id
		private ViewId ReadViewId()
		{
			ViewId vid = new ViewId();
			
			vid.ltime = ReadInt();
			vid.endpt = ReadEndpt();
			return vid;
		}
		
		// Read an array of view-ids
		private ViewId[] ReadViewIdArray()
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
		
		private Message RecvView(Member m)
		{
			View view = new View();
			Message msg = new Message();
			
			// Reading local state
			view.endpt = ReadEndpt ();
			view.addr= ReadString(CE_ADDR_MAX_SIZE);
			view.rank = ReadInt ();
			view.name = ReadString(CE_NAME_MAX_SIZE);
			view.nmembers = ReadInt ();
			view.view_id = ReadViewId();
			view.am_coord = ReadBool ();
			
			// Reading view state
			view.version = ReadString (CE_VERSION_MAX_SIZE);
			view.group = ReadString(CE_GROUP_NAME_MAX_SIZE);
			view.proto = ReadString(CE_PROTOCOL_MAX_SIZE);
			view.coord = ReadInt ();
			view.ltime = ReadInt ();
			view.primary = ReadBool ();
			view.groupd = ReadBool ();
			view.xfer_view = ReadBool ();
			view.key = ReadKey();
			view.prev_ids = ReadViewIdArray ();
			view.parameters=ReadString (CE_PARAMS_MAX_SIZE);
			view.uptime = ReadTime ();
			view.view = ReadEndptArray ();
			view.address = ReadAddrArray ();
			
			// The group is unblocked now.
			m.current_status=Member.Status.Normal;
			m.current_view = view;
			
			msg.mtype = UpType.VIEW;
			msg.view = view;
			return msg;
		}
		
		private Message RecvCast(Member m)
		{
			int origin ;
			byte[] data;
			Message msg = new Message ();
			
			//    ce_trace(NAME, "cb_Cast");
			origin = ReadInt();
			data = ReadData();
			
			//    assert(origin < s->nmembers) ;
			msg.mtype = UpType.CAST;
			msg.origin = origin;
			msg.data = data;
			return msg;
		}
		
		private Message RecvSend(Member m)
		{
			int origin ;
			byte[] data;
			Message msg = new Message ();
			
			//    ce_trace(NAME, "cb_Send");
			origin = ReadInt();
			data = ReadData();
			
			//    assert(origin < s->nmembers) ;
			msg.mtype= UpType.SEND;
			msg.origin = origin;
			msg.data = data;
			return msg;
		}
		
		private Message RecvHeartbeat(Member m)
		{
			double time;
			Message msg = new Message ();
			
			time = ReadTime();
			msg.mtype = UpType.HEARTBEAT;
			msg.time = time;
			return msg;
		}
		
		private Message RecvBlock(Member m)
		{
			Message msg = new Message ();
			msg.mtype = UpType.BLOCK;
			return msg;
		}
		
		private Message RecvExit(Member m)
		{
			Message msg = new Message ();
			
			if (!(Member.Status.Leaving == m.current_status))
				throw new EnsembleException("CbExit: mbr state is not leaving");
			
			msg.mtype = UpType.EXIT;
			
			/* Remove the context from the hashtable, we shall no longer deliver
			 * messages to it
			 */
			ContextRemove(m);

			// Tell members that this member is no longer valid
			m.current_status = Member.Status.Left;

			return msg;
		}
		
		/************************ User Downcalls ****************************/
		
		// Check that the member is in a Normal status 
		private void CheckValid(Member m)
		{
			switch (m.current_status) 
			{
				case Member.Status.Normal:
					break;
				default:
					throw new EnsembleException("Operation while group is " + 
						m.current_status.ToString() + 
						"gid=" + m.id);
			}
		}
		
		/* Join a group.  The group context is returned in *contextp.  
		 */
		internal void Join(Member m, JoinOps ops)
		{
			lock(this) 
			{
				
				/* Check that this is a fresh Member, e.g., we haven't already
				 * joined a group with it.
				 */
				if (m.current_status != Member.Status.Pre) 
					throw new EnsembleException("Trying to Join more than once");
				
				// Update the state of the member to Joining
				m.current_status = Member.Status.Joining;
				
				// We must provide the member with an ID prior to any other operation
				m.id = AllocMid();

				WriteBegin(); 
				// Write the downcall.
				WriteHdr(m,DnType.DN_JOIN);
				WriteTime(ops.hrtbt_rate);
				WriteString(ops.transports);
				//	ce_trace(NAME, ".");
				WriteString(ops.protocol);
				//	ce_trace(NAME, ".");
				WriteString(ops.group_name);
				//	ce_trace(NAME, "write ops.properties:");
				WriteString(ops.properties);
				//	ce_trace(NAME, "write ops.use_properties:");
				WriteBool(ops.use_properties);
				//	ce_trace(NAME, "write ops.groupd:");
				WriteBool(ops.groupd);
				//	ce_trace(NAME, "write ops.params:");
				WriteString(ops.parameters);
				//	ce_trace(NAME, "write ops.client:");
				WriteBool(ops.client);
				//	ce_trace(NAME, "write ops.debug:");
				WriteBool(ops.debug);
				
				if (ops.endpt != null) 
				{
					throw new EnsembleException("CE_OUTBOARD does not support 'endpt' in join ops");
				}
				WriteString(ops.princ);
				WriteByteArray(ops.key);
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
		internal void Leave(Member m)
		{
			lock(this) 
			{
				CheckValid(m);
				m.current_status=Member.Status.Leaving;
				
				WriteBegin(); 
				// Write the downcall.
				WriteHdr(m,DnType.DN_LEAVE);
				WriteEnd();
			}
		}
		
		// Send a multicast message to the group.
		internal void Cast(Member m,  byte[] data)
		{
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_CAST);
				WriteData(data);
				WriteEnd();
			}
		}
		
		// Send a point-to-point message to a list of members.
		internal void Send(Member m, int[] dests, byte[] data)
		{
			int i;
			
			//    TRACE("ce_st_Send");
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_SEND);
				WriteInt(dests.Length);
				for (i=0; i<dests.Length; i++) 
				{
					if (dests[i] < 0
						|| dests[i] > m.current_view.nmembers) 
						throw new EnsembleException("destination out of bounds");
					WriteInt(dests[i]);
				}
				WriteData(data);
				WriteEnd();
			}
		}
		
		// Send a point-to-point message to the specified group member.
		internal void Send1(Member m, int dest, byte[] data)
		{
			lock(this) 
			{
				CheckValid(m);
				if (dest < 0
					|| dest > m.current_view.nmembers) 
					throw new EnsembleException("destination out of bounds");
				WriteBegin();
				WriteHdr(m,DnType.DN_SEND1);
				WriteInt(dest);
				WriteData(data);
				WriteEnd();
			}
		}
		
		// Report group members as failure-suspected.
		internal void Suspect(Member m, int[] suspects)
		{
			int i;
			
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_SUSPECT);
				WriteInt(suspects.Length);
				for (i=0; i<suspects.Length; i++) 
				{
					if (suspects[i] < 0
						|| suspects[i] > m.current_view.nmembers) 
						throw new EnsembleException("Suspition out of bounds");
					WriteInt(suspects[i]);
				}
				WriteEnd();
			}
		}
		
		// Inform Ensemble that the state-transfer is complete. 
		internal void XferDone(Member m)
		{
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_XFERDONE);
				WriteEnd();
			}
		}
		
		
		// Request a protocol change.
		internal void ChangeProtocol(Member m, string protocol_name)
		{
			if (null == protocol_name)
				throw new EnsembleException("Protocol must be non-null");
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_PROTOCOL);
				WriteString(protocol_name); 
				WriteEnd();
			}
		}
		
		// Request a protocol change specifying properties.
		internal void ChangeProperties(Member m, string properties)
		{
			if (null == properties)
				throw new EnsembleException("Property must be non-null");
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_PROPERTIES);
				WriteString(properties);
				WriteEnd();
			}
		}
		
		// Request a new view to be installed.
		internal void Prompt(Member m)
		{
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_PROMPT);
				WriteEnd();
			}
		}
		
		
		// Request a Rekey operation.
		internal void Rekey(Member m)
		{
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_REKEY);
				WriteEnd();
			}
		}
		
		// Send a BlockOk
		internal void BlockOk(Member m)
		{
			// Write the block_ok downcall.
			lock(this) 
			{
				CheckValid(m);
				WriteBegin();
				WriteHdr(m,DnType.DN_BLOCK_OK) ;
				WriteEnd();
				
				// Update the member state to Blocked. 
				m.current_status = Member.Status.Blocked;
			}
		}
		
		/// <summary> Check if there is a pending message. If it returns true then Recv will 
		/// return with a message. 
		/// </summary>
		public bool Poll()
		{
			lock(this) 
			{
				/* There can't be concurrent executions of Recv and Poll since they
				 * lock the object. 
				 */
				return stream.DataAvailable;
			}
		}
		
		/// <summary> Receive a single message. This is a blocking call, return only when 
		/// a complete message arrives.
		/// </summary>
		public Message Recv() 
		{
			UpType cb;
			int id;
			Member m;
			Message msg = null;
			
			lock(this) 
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
					case UpType.VIEW:
						msg = RecvView(m);
						break;
					case UpType.CAST:
						msg = RecvCast(m);
						break;
					case UpType.SEND:
						msg = RecvSend(m);
						break;
					case UpType.HEARTBEAT:
						msg = RecvHeartbeat(m);
						break;
					case UpType.BLOCK:
						msg = RecvBlock(m);
						break;
					case UpType.EXIT:
						msg = RecvExit(m);
						break;
					default:
						throw new EnsembleException("Bad upcall type" + cb.ToString());
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
		public void Connect () 
		{
			lock(this) 
			{
				try 
				{
					address = IPAddress.Loopback.ToString();
					socket = new TcpClient(address, port);
					stream = socket.GetStream();
				} 
				catch (Exception e) 
				{
					throw new EnsembleException("Could not connect to the Ensemble server");
				}
			}
		}
	}

	/**************************************************************/
	/// <summary> A group member </summary>
	public class Member 
	{
		/// <summary> The current member status </summary>
		public enum Status 
		{
			/// <summary> the initial status </summary>
			Pre,        
			/// <summary> we joining the group </summary>
			Joining,   
			/// <summary> Normal operation state, can send/mcast messages </summary>
			Normal, 
			/// <summary> we are blocked </summary>
			Blocked, 
			/// <summary> we are leaving </summary>
			Leaving,
			/// <summary> We have left the group and are in an invalid state </summary>
			Left
		}

		/// <summary> The current view </summary>
		public View current_view ;		   
		/// <summary> Our current status </summary>
		public Status current_status = Status.Pre; 

		internal int id = -1;                // The group id
		private Connection conn =  null;

		public Member(Connection conn)
		{
			this.conn = conn;
		}

		
		/// <summary> Join a group </summary>
		/// <param name="ops">  The join options passed to Ensemble. </param>
		public void Join(JoinOps ops)
		{
			conn.Join(this, ops);
		}
		
		/// <summary> Leave a group.  This should be the last call made to a given context.
		/// No more events will be delivered to this context after the call returns.  
		/// </summary>
		public void Leave()
		{
			conn.Leave(this);
		}

		/// <summary> Send a multicast message to the group. </summary>
		/// <param name="data">  The data to send. </param>
		public void Cast(byte[] data)
		{
			conn.Cast(this, data);
		}

		/// <summary> Send a point-to-point message to a list of members. </summary>
		/// <param name="dests"> The set of destinations. </param>
		/// <param name="data">  The data to send. </param>
		public void Send(int[] dests, byte[] data)
		{
			conn.Send(this, dests, data);
		}

		/// <summary> Send a point-to-point message to the specified group member. </summary>
		/// <param name="dest"> The destination. </param>
		/// <param name="data">  The data to send. </param>
		public void Send1(int dest, byte[] data)
		{
			conn.Send1(this, dest, data);
		}

		/// <summary> Report group members as failure-suspected. </summary>
		/// <param name="suspects"> The set of suspects. </param>
		public void Suspect(int[] suspects)
		{
			conn.Suspect(this, suspects);
		}

		/// <summary> Inform Ensemble that the state-transfer is complete.  </summary>
		public void XferDone()
		{
			conn.XferDone(this);
		}

		/// <summary> Request a protocol change. </summary>
		/// <param name="protocol_name"> The new protocol. </param>
		public void ChangeProtocol(string protocol_name)
		{
			conn.ChangeProtocol(this, protocol_name);
		}

		/// <summary> Request a protocol change specifying properties. </summary>
		/// <param name="properties"> The new set of properties. </param>
		public void ChangeProperties(string properties)
		{
			conn.ChangeProperties(this,properties);
		}

		/// <summary> Request a new view to be installed. </summary>
		public void Prompt()
		{
			conn.Prompt(this);
		}

		/// <summary> Request a Rekey operation. </summary>
		public void Rekey()
		{
			conn.Rekey(this);
		}

		/// <summary>  Send a BlockOk </summary>
		public void BlockOk()
		{
			conn.BlockOk(this);
		}
	}
}


