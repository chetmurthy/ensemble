package ensemble.hot;

import java.io.*;

/**
Defines how Hot_Ensemble talks to the outboard process
Is used by Hot_Ensemble for actual IO
*/

class Hot_IO_Controller {
    private InputStream is;
    private OutputStream os;
    private ByteArrayOutputStream bos;
    private ByteArrayInputStream bis;
    private DataOutputStream dos;
    private DataInputStream dis;
    // can I do this ?
    private byte[] read_buf;
    private boolean print=false;
    private int ml_len;
    private int iov_len;
    private int ml_read_len;
    private int iov_read_len;
    
    public Hot_IO_Controller(InputStream is, OutputStream os) {
	HOT_MAGIC *= 10; // see the definition of the variable below...
	HOT_MAGIC += 9;
	this.is = is;
	this.os = os;
	bos = null;
	bis = null;
	dos = null;
	dis = null;
    }

    public final int DN_JOIN = 0;
    public final int DN_CAST = 1;
    public final int DN_SEND_BLOCKED = 2;
    public final int DN_SUSPECT = 3;
    public final int DN_XFERDONE = 4;
    public final int DN_PROTOCOL = 5;
    public final int DN_PROPERTIES = 6;
    public final int DN_LEAVE = 7;
    public final int DN_PROMPT = 8;
    public final int DN_REKEY = 9;
    public final int DN_BLOCK_ON = 10;
    public final int DN_SEND = 11;

    public final int CB_VIEW = 0;
    public final int CB_CAST = 1;
    public final int CB_SEND = 2;
    public final int CB_HEARTBEAT = 3;
    public final int CB_BLOCK = 4;
    public final int CB_EXIT = 5;

    private int HOT_MAGIC = 365718590/*9*/;  // must be same as in ML
    // In Java the primitive int is 32 bits.
    public final int INT_SIZE = 4;	     // a 32 bit integer

    public void begin_write() {
	if (bos == null) {
	    bos = new ByteArrayOutputStream();
	    dos = new DataOutputStream(bos);
        }
	else {
	    /* I'm not sure exactly why we HAVE to close, and
	     * then reopen this. */
	    try {
	      bos.close();
	      dos.close();
            } catch(Exception e) {}
	    bos = new ByteArrayOutputStream();
	    dos = new DataOutputStream(bos);
        }
	ml_len = 0;
	iov_len = 0;
    }

    /* Write everthing out to network. Open a temporary
     * Output stream, do2, write the ML length, and Iovec length
     * to it. Then, flush everthing to the net.
     */
    public void end_write() throws IOException {
	DataOutputStream do2 = new DataOutputStream(os);

	/* We didn't call write_msg before hand.
	 */
	if (ml_len == 0 && iov_len ==0) {
	    ml_len = bos.size();
	    iov_len = 0;
	}

	// write sizes to wire
        Hot_Ensemble.trace("end_write: size =(" + ml_len + "," + iov_len + ")");
	try {
	    do2.writeInt(ml_len);
	    do2.writeInt(iov_len);
        }
        catch(Exception e) {
	    if (e.equals("java.io.IOException: Broken pipe"))
	    {
                System.err.println("end_write: outboard - broken pipe");
		throw new IOException();
	    }
	    else
	    {
                System.err.println("end_write: exception " + e);
		throw new IOException();
	    }
        }

	// write the rest of the msg to wire
        Hot_Ensemble.trace("end_write: body= " + bos.toString());

	// I think this way it doesn't do a copy
	// May not write entire buffer to socket??
	try {
	    bos.writeTo(do2);
        }
        catch(Exception e) {
            System.err.println("end_write: exception 2 " + e);
	    throw new IOException();
        }

	try {
	    System.out.println("Flusing do2, size=" + do2.size ());
            //do2.flush();
            os.flush();
        }
        catch(Exception e) {
            System.err.println("end_write: exception 3 " + e);
	    throw new IOException();
        }
    }

    public void write_int(int u) {
	try {
	    dos.writeInt(u) ;
        }
        catch(Exception e) {
            System.err.println("write_int: exception " + e);
        }
        Hot_Ensemble.trace("write_int: " + u);
	return; 
    }

    public void write_bool(boolean b) { 
	write_int(b ? 1 : 0);
        Hot_Ensemble.trace("write_bool: " + b);
	return; 
    }

    /* Write the buffer length, and then the buffer itself.
     */
    public void write_buffer(byte[] Bytes) { 
	int l = Bytes.length;
       
	write_int(l);

	try {
            dos.write(Bytes);
        }
        catch(Exception e) {
            System.err.println("write_buffer: exception " + e);
        }

        Hot_Ensemble.trace("write_buffer: size = " + l + " bytes");
        Hot_Ensemble.trace("write_buffer: buffer = " + new String(Bytes));
	return; 
    }

    public void write_string(String s) { 
	byte[] pBytes;
	pBytes = s.getBytes();	// lossy!!! Ensemble wants ASCII, we have UNICODE
	write_buffer(pBytes);
    }

    public void write_endpID(Hot_Endpoint epid) { 
	write_string(epid.name);
	return; 
    }

    public void write_groupID(int gid) { 
	write_int(gid);
	return; 
    }

    public void write_hdr(Hot_GroupContext gc, int dnType) { 
	write_int(gc.id);
	write_int(gc.ltime);
	write_int(dnType);
        Hot_Ensemble.trace("write_hdr:id= " + gc.id + " ltime= " + gc.ltime + "	type= " + dnType);
	return; 
    }

    public void write_msg(Hot_Message msg) { 
	byte[] Bytes = msg.getBytes();

	ml_len = bos.size(); // log the current size as the ml header.
	iov_len = Bytes.length; // the Iovec size is the message length.

        Hot_Ensemble.trace("ml_len=" + ml_len + ", iov_len" + iov_len);
	// Write body
	try {
	    dos.write(Bytes);
        }
        catch(Exception e) {
	    System.err.println("write_msg: exception " + e);
        }
        Hot_Ensemble.trace("write_msg: body = "  + new String(Bytes));
	
	return;
    }

    public void write_endpList(Hot_Endpoint[] epids) { 
	int l = epids.length;
	write_int(l);
	for(int i = 0;i<l;i++)
	    write_endpID(epids[i]);
	return; 
    }

    public void write_dnType(int type) { 
	write_int(type);
	return; 
    }

    public int begin_read() {
	int tmp=0;
	int numbytes=0;
	int read_size=0;

	DataInputStream di2 = new DataInputStream(is);

	// Get msg size
	// This is the sum of the ML length, and Iovec length.
	try {
            ml_read_len = di2.readInt();
	    iov_read_len = di2.readInt();
	    read_size = ml_read_len + iov_read_len;
        }
        catch(EOFException e) {
	    return(-1);
	}
        catch(Exception e) {
	    System.err.println("begin_read: readInt: " + e.toString());
	    return(-2);
        }

	// Allocate read_buf to read_size
	read_buf = new byte[read_size];

	// read in a loop
        while(true) {
            try {
		Hot_Ensemble.trace("begin_read: size=" + read_size);
	        tmp=di2.read(read_buf, numbytes, read_size - numbytes);
		if(tmp == -1)
		    break;
                numbytes+=tmp;
		
		if(numbytes < read_size)
		    continue;
		else
		    break;		    
	    }
            catch(Exception e) {
                System.err.println("begin_read: read loop: " + e.toString());
		break;
	    }
        }
	// Set buffer into bis, then dis, so we can read sequentially by type
	bis = new ByteArrayInputStream(read_buf);

        dis=new DataInputStream(bis);

	return(0);
    }	    
	    
    public void end_read() {
	// delete alloc'd memory
	// delete read_buf[];
    }

    public void read_int(int[] u) { 
	try {
            u[0] = dis.readInt();
        }
        catch(Exception e) {
	    System.err.println("read_int: readInt: " + e.toString());
        }

        Hot_Ensemble.trace("read_int: " + u[0]);
	return; 
    }

    public void read_bool(boolean[] b) {
	int[] anInt = new int[1];
	read_int(anInt);
	b[0] = (anInt[0] == 1) ? true : false;
        Hot_Ensemble.trace("read_bool: " + b[0]);
	return; 
    }

    public void read_buffer(Hot_Buffer b) { 
	int[] size = new int[1];
	
	
	// read in size of string
	read_int(size);

	byte[] Bytes = new byte[size[0]];
	try {
	    // read in string of size bytes
	    dis.read(Bytes, 0, size[0]);
	    Hot_Ensemble.trace("read_buffer: read in bytes: " + Bytes.length);
	    b.setBytes(Bytes);
	} catch (Exception e) {
	    System.err.println("Hot_IO_Controller::read_buffer: error: " + e.toString());
	    e.printStackTrace();
	}

	return; 
    }

    public void read_string(String[] sb) { 
	Hot_Buffer b = new Hot_Buffer();
	read_buffer(b);
	b.toAsciiString(sb);
	return; 
    }

    public void read_endpID(Hot_Endpoint epid) { 
	String[] pString = new String[1];
	read_string(pString);
	epid.name = pString[0];
	return; 
    }

    public void read_groupID(int[] gid) { 
	read_int(gid);
	return; 
    }

    public void read_msg(Hot_Message msg) { 
	// Allocate memory
	byte[] Bytes = new byte[iov_read_len];
	
	// Read body
	try {
	    dis.read(Bytes, 0, iov_read_len);
	}
        catch(Exception e) {
	    System.err.println("read_msg: read " + e.toString());
        }

	msg.setBytes(Bytes);	

        Hot_Ensemble.trace("read_msg: size = " + iov_read_len );
        Hot_Ensemble.trace("read_msg: body = "  + new String(Bytes));
	
	return;
    }

    public Hot_Endpoint[] read_endpList(int[] size) { 
	Hot_Endpoint[] rtnVal = null;

	read_int(size);

	rtnVal = new Hot_Endpoint[size[0]];
	for (int i = 0; i < size[0]; i++) {
	    rtnVal[i] = new Hot_Endpoint();
	    read_endpID(rtnVal[i]);
	}
	return rtnVal; 
    }

    public boolean[] read_boolList() {
	int[] numBools = new int[1];
	read_int(numBools);
	boolean[] rtnVal = new boolean[numBools[0]];
	boolean[] b = new boolean[1];
	for (int i = 0;i < numBools[0];i++) {
	    read_bool(b);
	    rtnVal[i] = b[0];
	}
	return rtnVal;
    }

    public void read_cbType(int[] type) {
	type[0]=0;
	read_int(type);
	Hot_Ensemble.trace("Hot_IO_Controller::read_cbType=" + type);
	return; 
    }

// End class Hot_IO_Controller 
}
