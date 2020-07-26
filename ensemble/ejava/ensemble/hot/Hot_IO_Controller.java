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

    public Hot_IO_Controller(InputStream is, OutputStream os) {
	HOT_MAGIC *= 10; // see the definition of the variable below...
	HOT_MAGIC += 9;
	this.is = is;
	this.os = os;
	this.bos = null;
	this.bis = null;
	this.dos = null;
	this.dis = null;
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
	    // Bela is not sure this works properly
	    bos.reset();
        }
    }

    public void end_write() throws IOException {
	DataOutputStream do2 = new DataOutputStream(os);

	// get size of byte array out of ByteArrayOutputStream
	int size = bos.size();

	// write size to wire
        Hot_Ensemble.trace("end_write: size to wire=" + size);
	try {
	    do2.writeInt(size);
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
        Hot_Ensemble.trace("end_write: body=" + bos.toString());

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
            do2.flush();
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

    public void write_buffer(byte[] pBytes) { 
	byte[] padBytes=new byte[INT_SIZE];
	int l = pBytes.length;
       
	// writing:
	// number of bytes in the buffer (4 byte int)
	// the buffer
	// padding (INT_SIZE - (buffer_size % INT_SIZE bytes))

	write_int(l);

	try {
            dos.write(pBytes, 0, l);
        }
        catch(Exception e) {
            System.err.println("write_buffer: exception " + e);
        }

	int padSize = l % INT_SIZE;

        if (padSize != 0) {
	    try {
	        dos.write(padBytes, 0, (INT_SIZE - padSize));
            }
            catch(Exception e) {
	        System.err.println("write_buffer: exception 2 " + e);
            }
        }
        Hot_Ensemble.trace("write_buffer: size = " + l + " bytes");
        Hot_Ensemble.trace("write_buffer: buffer = " + new String(pBytes));
        Hot_Ensemble.trace("write_buffer: pad = " + padSize + " bytes");
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
	// we are sending:
	// 4 bytes representing the size of the msg + 4 bytes + rounded up,
	// 4 bytes representing the actual size of the msg
	// the body of the msg, and
	// 0-3 bytes padding to a 4-byte boundary, if necessary

	byte[] pBytes = msg.getBytes();
	int l = pBytes.length;
	byte padBytes[]=new byte[INT_SIZE];

	// Add 4, round up and write that size 
	// Removed this, due to changes done by Mark to the interface
	// This is actually done elsewhere now.
	//write_int((l + 7)&~3);

	// Write actual size of msg
	write_int(l);
	
	// Write body
	try {
	    dos.write(pBytes, 0, l);
        }
        catch(Exception e) {
	    System.err.println("write_msg: exception " + e);
        }

        // Write padding if necessary
	if (l % INT_SIZE != 0) {
	    try {
                dos.write(padBytes, 0, INT_SIZE - (l % INT_SIZE));
	    }
            catch(Exception e) {
	        System.err.println("write_msg: exception 2 " + e);
            }
	}
        Hot_Ensemble.trace("write_msg: size = " + l + " pad = " + (INT_SIZE - (l%INT_SIZE)));
        Hot_Ensemble.trace("write_msg: body = "  + new String(pBytes));
	
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
	try {
            read_size = di2.readInt();
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
	byte[] padBytes=new byte[INT_SIZE];

	// read in size of string
	read_int(size);

	byte[] pBytes = new byte[size[0]];
	try {
	    // read in string of size bytes
	    dis.read(pBytes, 0, size[0]);
	    Hot_Ensemble.trace("read_buffer: read in bytes: " + pBytes.length);

	    b.setBytes(pBytes);
	    int padSize = (size[0] % INT_SIZE);

	    if(padSize != 0) {
	        // read in pad bytes
		dis.read(padBytes, 0, INT_SIZE - padSize);
		Hot_Ensemble.trace("read_buffer: read in pad bytes: " + padSize);
	    }
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
	// we are reading:
	// 4 bytes representing the size of the msg + 4 bytes + rounded up,
	// 4 bytes representing the actual size of the msg
	// the body of the msg, and
	// 0-3 bytes padding to a 4-byte boundary, if necessary

	byte padBytes[]=new byte[INT_SIZE];
	int[] size = new int[1];
	int[] actualSize = new int[1];

	// Read padded rounded size
	read_int(size);

	// Read actual size of msg
	read_int(actualSize);

	// Only read in actualSize of msg
	byte[] pBytes = new byte[actualSize[0]];
	
	// Read body
	try {
	    dis.read(pBytes, 0, actualSize[0]);
	}
        catch(Exception e) {
	    System.err.println("read_msg: read " + e.toString());
        }

	msg.setBytes(pBytes);	

        // Read (and discard) padding if necessary
	if (actualSize[0] % INT_SIZE != 0) {
	    try {
                dis.read(padBytes, 0, INT_SIZE - (actualSize[0] % INT_SIZE));
	    } catch (Exception e) {
                System.err.println("read_msg: read2 " + e.toString());
            }
	}
        Hot_Ensemble.trace("read_msg: size = " + actualSize[0] + " pad = " +
(INT_SIZE - (actualSize[0]%INT_SIZE)) + " tot = " + size[0]);
        Hot_Ensemble.trace("read_msg: body = "  + new String(pBytes));
	
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
