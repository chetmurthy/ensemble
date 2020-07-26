/**************************************************************/
/*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* ENS_CONNECTION.C */
/* Author: Ohad Rodeh 10/2003 */
/**************************************************************/
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

/**************************************************************/
/** A wrapper for the actual communication with the Ensemble server.
 * The Connection class hides the message formats for those messages
 * passed between itself and the server.  
 */

#include "ens.h"
#include "ens_comm.h"
#include "ens_hashtbl.h"
#include "ens_threads.h"
#include "ens_utils.h"
#include <assert.h>
#include <stdio.h>
#include <malloc.h>
/**************************************************************/
#define NAME "CONNECTION"
/**************************************************************/

// Downcalls into Ensemble.  Must match the ML side.
typedef enum ens_dn_msg_t {
    DN_JOIN = 1,
    DN_CAST = 2,
    DN_SEND = 3,
    DN_SEND1 = 4,
    DN_SUSPECT = 5,
    DN_LEAVE = 6,
    DN_BLOCK_OK = 7
} ens_dn_msg_t;
    
#define INT_SIZE  (sizeof(int))

// A variable size array of chars
typedef struct ens_varray_t {
    char *buf;
    int len;
} ens_varray_t;

struct ens_conn_t {
    ens_sock_t socket;
    int port;

    // A counter for the member-ids. 
    int mid;

    // A hash-table for group members
    ens_hashtbl_t memb_tbl ;

    // receive state
    // A lock to make the library thread-safe.
    ens_lock_t *recv_mutex;
    
    // The precursor to the actual received header, [ml_len, data_len]
    // both in network-byte-order
    char read_hdr_hdr[8];
    
    // A dynamically-sized byte-array that holds received headers
    ens_varray_t read_hdr;
    
    // A byte-array that holds received user-data. Allocated by
    // the Ensemble-library and handed over to the user.
    ens_varray_t read_data; 
    
    // current position in the array being received. 
    int read_pos;
    
    // The size of the header
    int read_hdr_len;
    
    // The size of data
    int read_data_len;
    
    // send state
    // A lock to make the library thread-safe.
    ens_lock_t *send_mutex;

    // The precursor to the actual sent header, [ml_len, data_len]
    // both in network-byte-order
    char write_hdr_hdr[8];
    
    // A dynamically-sized byte-array that holds send headers
    ens_varray_t write_hdr;
    
    // A pointer to the user-data to be sent.
    ens_varray_t write_data;
    
    // current position in the cached send-header array
    int write_pos;
    
    // The size of the header
    int write_hdr_len;
};

/**************************************************************/
static void InitConn(ens_conn_t *conn, ens_sock_t sock, int port )
{
    memset((char*)conn, 0, sizeof(ens_conn_t));

    conn->socket = sock;
    conn->port = port;
    conn->mid = 1;
    conn->recv_mutex= EnsLockCreate();
    conn->send_mutex= EnsLockCreate();

    conn->read_hdr.len = 512;
    conn->read_hdr.buf = EnsMalloc(conn->read_hdr.len);
    conn->write_hdr.len = 512;
    conn->write_hdr.buf = EnsMalloc(conn->write_hdr.len);
}

/**************************************************************/

// resize a char array
static void Resize(ens_varray_t *va, int new_size)
{
    char *newA;

//    EnsTrace(NAME,"Resize");
    newA = malloc(new_size);
    if (NULL == newA) 
        EnsPanic("out of memory, exiting.");
    memcpy(newA, va->buf, va->len);
    free(va->buf);
    va->buf = newA;
    va->len= new_size;
}

// Clean-up a variable length array
static void Reset(ens_varray_t *va)
{
    va->buf = NULL;
    va->len = 0;
}

/* Marshal an integer into network byte order onto a buffer at a
 * certain location
 */
static void Htonl(int i, char *buf,int ofs)
{
    buf[ofs  ] = (char) ((i >> 24) & 0xFF);
    buf[ofs+1] = (char) ((i >> 16) & 0xFF);
    buf[ofs+2] = (char) ((i >> 8 ) & 0xFF);
    buf[ofs+3] = (char) ((i      ) & 0xFF);
}

static int Ntohl(char *buf, int ofs)
{
    int i0 = (buf[ofs  ] & 0xFF);
    int i1 = (buf[ofs+1] & 0xFF);
    int i2 = (buf[ofs+2] & 0xFF);
    int i3 = (buf[ofs+3] & 0xFF);
    
    return ((i0 << 24) | (i1 << 16) | (i2 << 8) | (i3));
}

/**************************************************************/
// Allocate a member id. The id must be unique during this connection
static int AllocMid(ens_conn_t *conn)
{
    return conn->mid++;
}

/**************************************************************/

/* Allocate a new context.
 * The global data record must be locked at this point.
 */
static void MemberAdd(ens_member_t *m)
{
    EnsHashtblInsert(&m->conn->memb_tbl, (ens_hitem_t*)m);
}

/* Release a context descriptor.
 */
static void MemberRemove(ens_member_t *m)
{
    EnsHashtblRemove(&m->conn->memb_tbl, m->id);
}

/* Lookup a context descriptor.
 */
static ens_member_t *MemberLookup(ens_conn_t *conn, int id)
{
    return (ens_member_t*) EnsHashtblLookup(&conn->memb_tbl, id);
}
/**************************************************************/

static void WriteBegin(ens_conn_t *conn)
{
//    EnsTrace(NAME,"WriteBegin");
    conn->write_hdr_len = 0 ;
}
    
static void WriteDo(ens_conn_t *conn, char *buf,int len)
{
    if (conn->write_pos+len > conn->write_hdr.len) 
    {
        int new_size = conn->write_hdr.len;
        while (conn->write_pos+len > new_size)
            new_size *= 2 ;
        Resize(&conn->write_hdr, new_size);
    }
    
    // copy into the preallocated send-header array
    memcpy((char*) &conn->write_hdr.buf[conn->write_pos], buf, len);
    conn->write_pos += len ;
}

/* Take note to first write the ML length, and then
 * the data length. 
 */
static ens_rc_t WriteEnd(ens_conn_t *conn) 
{
    /* Compute header length. The ML header length is equal to our
     * current position in the write buffer.
     */
    conn->write_hdr_len = conn->write_pos;

    EnsTrace(NAME,"WriteEnd (ml_len=%d, iov_len=%d)",
             conn->write_hdr_len, conn->write_data.len);
    
    // Marshal header length
    Htonl(conn->write_hdr_len, conn->write_hdr_hdr, 0) ;
    // Marshal data length
    if (NULL == conn->write_data.buf) 
        Htonl(0,conn->write_hdr_hdr, 4 ) ;
    else 
        Htonl(conn->write_data.len, conn->write_hdr_hdr, 4 ) ;
    
    EnsTcpSendIovecl(
        conn->socket,
        8, conn->write_hdr_hdr,                       // Send the precursor
        conn->write_hdr_len, conn->write_hdr.buf,     // Send the header
        conn->write_data.len, conn->write_data.buf ); // Send the data buffer
    
    // reset 
    conn->write_pos = 0 ;
    
    // Sanitation: erase any references to the data
    Reset(&conn->write_data);
    
    // Shrink the buffer if it is >64K.
    if (conn->write_hdr.len > 1<<16) 
    {
        Resize(&conn->write_hdr, 1<<12);
    }

    return ENS_OK;
}
    
/* Read from the network a complete message.
 * This call is blocking. 
 */
static ens_rc_t ReadBegin(ens_conn_t *conn) 
{
    /* Read precursor. This will give the size of the header and the 
     * size of the user-data. A total of 8 bytes should be read. 
     */
    if (EnsTcpRecv(conn->socket, 8, conn->read_hdr_hdr) == ENS_ERROR)
        return ENS_ERROR;
    
    conn->read_hdr_len = Ntohl(conn->read_hdr_hdr,0);
    conn->read_data_len = Ntohl(conn->read_hdr_hdr,4);
    
    /* Ensure there is enough room in the read buffer.
     */
    if (conn->read_hdr_len > conn->read_hdr.len) 
    {
        int new_size = conn->read_hdr.len;
        while (conn->read_hdr_len > new_size)
            new_size *= 2 ;
        Resize(&conn->read_hdr, new_size);
    }
    
    // Reset the read position. 
    conn->read_pos = 0 ;
    
    // Read the ML header
    if (EnsTcpRecv(conn->socket, conn->read_hdr_len, conn->read_hdr.buf) == ENS_ERROR)
        return ENS_ERROR;

    return ENS_OK;
}

static void ReadDo(ens_conn_t *conn, char *buf, int len)
{
    //    assert(len <= g.read_size - g.read_pos) ;
    memcpy(buf, &conn->read_hdr.buf[conn->read_pos], len);
    conn->read_pos += len ;
}
    
// Cleanup at the end of reading a message  
static void ReadEnd(ens_conn_t *conn) 
{
    // make sure we read -all- the message.
    if (conn->read_pos != conn->read_hdr_len)
        EnsPanic("Internal error: (ReadEnd) read_pos=%d  read_hdr_len=%d",
                 conn->read_pos, conn->read_hdr_len);
    conn->read_pos = 0 ;
    Reset(&conn->read_data);
}

// Send an integer
static void WriteInt(ens_conn_t *conn, int i)
{
    char scratch[INT_SIZE];

//    EnsTrace(NAME,"write_int: (%d) ", i);
    Htonl(i,scratch,0);
    WriteDo(conn, scratch,INT_SIZE);
}
   
// Send a boolean
static void WriteBool(ens_conn_t *conn, int b)
{
    if (b) WriteInt(conn, 1);
    else WriteInt(conn, 0);
}

// Write a byte-array into the header. For example, the security key. 
static void WriteByteArray(ens_conn_t *conn, char *buf, int len)
{
    if (NULL == buf || 0 == len) 
    {
        WriteInt(conn, 0);
    } 
    else 
    {
        WriteInt(conn, len);
        WriteDo(conn, buf, len);
    }
}

/* Write a C-string into the header. This means a sequence of bytes that ends with a
 * null ('\0') character. 
 */
static void WriteString(ens_conn_t *conn, char *s)
{
    if (NULL == s) 
    {
        WriteInt(conn, 0);
    } 
    else 
    {
        int len = strlen(s);
        WriteByteArray(conn, s, len);
    }
}


static void WriteHdr(ens_member_t *m, ens_dn_msg_t type)
{
    EnsTrace(NAME,"write_hdr:id=%d, type=%d", m->id, type) ;
    WriteInt(m->conn, m->id);
    WriteInt(m->conn, type);
}

/* WriteData is the last call before a message is packaged and
 * sent. Record byte-array so that WriteEnd will
 * write the data on the outgoing packet.
 */
static void WriteData(ens_conn_t *conn, int len, char *data)
{
    conn->write_data.buf = data;
    conn->write_data.len = len;
}

/**************************************************************/

// read an integer value from a message
static int ReadInt(ens_conn_t *conn) 
{
    int tmp;
    char scratch[INT_SIZE];
    
    ReadDo(conn, scratch, INT_SIZE);
    tmp = Ntohl(scratch,0);
    EnsTrace(NAME, "ReadInt: %d", tmp);
    return tmp;
}

// read a boolean value from a message
static int ReadBool(ens_conn_t *conn) 
{
    int tmp;
    tmp = ReadInt(conn);
    return (tmp != 0) ;
}


// Copy into a preallocated buffer.
static void ReadString(ens_conn_t *conn, int max_size, char *prealloc_buf) 
{
    int size;
    
    size = ReadInt(conn);
    if (0 == size) return;
    if (size > max_size)
        EnsPanic("internal error, string (%d) larger than requested <%d> bytes", size, max_size);
    ReadDo(conn, prealloc_buf, size);

    {
        prealloc_buf[size] = 0;
//        EnsTrace(NAME,"ReadString: <%d> %s", size, prealloc_buf);
    }
}

// read the endpoint name
static void ReadEndpt(ens_conn_t *conn, ens_endpt_t *endpt ) 
{
    ReadString(conn, ENS_ENDPT_MAX_SIZE, endpt->name);
}


// read an address
static void ReadAddr(ens_conn_t *conn, ens_addr_t *addr ) 
{
    ReadString(conn, ENS_ADDR_MAX_SIZE, addr->name);
}


// read the member id
static int ReadContextID(ens_conn_t *conn) 
{
    return ReadInt(conn);
}

//Read an array of endpoint names
static void ReadEndptArray(ens_conn_t *conn, int n, ens_endpt_t *endpt_a)
{
    int i, size;

    EnsTrace(NAME,"ReadEndptArray(n=%d)", n);
    size = ReadInt(conn);
    if (n != size)
        EnsPanic("Bad number of elements in endpoint array");

    for (i = 0; i < n; i++)
        ReadEndpt(conn, &endpt_a[i]);
}

//Read an array of addresses
static void ReadAddrArray(ens_conn_t *conn, int n, ens_addr_t *addr_a)
{
    int i, size;
    
    EnsTrace(NAME,"ReadAddrArray(n=%d)", n);
    size = ReadInt(conn);
    if (n != size)
        EnsPanic("Bad number of elements in endpoint array");
    for (i = 0; i < n; i++)
        ReadAddr(conn, &addr_a[i]);
}
    
// read the callback type
static ens_up_msg_t ReadUpType(ens_conn_t *conn) 
{
    return (ens_up_msg_t) ReadInt(conn);
}
    
// read a view-id
static void ReadViewId(ens_conn_t *conn, ens_view_id_t *vid) 
{
    vid->ltime = ReadInt(conn);
    ReadEndpt(conn, &vid->endpt);
}

/**************************************************************/

ens_rc_t ens_RecvMetaData(ens_conn_t *conn, ens_msg_t *msg)
{
    ens_up_msg_t cb;
    int id;
    ens_member_t *memb;
    int nmembers;
    ens_rc_t rc;

    EnsTrace(NAME, "ens_RecvMetaData");
    EnsLockTake(conn->recv_mutex);
    {
        rc = ReadBegin(conn) ;

        // If there is an error escape gracefully
        if (ENS_ERROR == rc)
            goto done;
        
        id = ReadContextID(conn);
        EnsTrace(NAME, "member ID: %d", id);
        
        cb = ReadUpType(conn);
        EnsTrace(NAME, "up_type=%s", StringOfUpType(cb));
        if (cb < 1 || cb > 5)
            EnsPanic("cb=%d", cb);
        memb = MemberLookup(conn, id);
        
        EnsTrace(NAME, "memb= %p", memb);
        if (NULL == memb)
            EnsPanic("Internal Error, no such member");
        
        /* Check which message type this is and dispatch accordingly.
         */
        msg->memb = memb;
        msg->mtype = cb;
        switch(cb) {
        case VIEW:
            memb->current_status= Normal;
            nmembers = ReadInt(conn);
            msg->u.view.nmembers = nmembers;
            memb->nmembers = nmembers;
            break;
        case CAST:
            msg->u.cast.msg_size = conn->read_data_len;
            break;
        case SEND:
            msg->u.cast.msg_size = conn->read_data_len;
            break;
        case BLOCK:
            break;
        case EXIT:
            if (!(Leaving == memb->current_status))
                EnsPanic("Got Exit, but member state is not <Leaving>");
            
            /* Remove the context from the hashtable, we shall no longer deliver
             * messages to it
             */
            MemberRemove(memb);
            
            // This member is no longer valid
            memb->current_status = Left;
            
            /* BUG: who needs to free the data structure for the member?
             */
            break;
        default:
            EnsPanic("Internal Error: bad message type received from server.");
        }
    }
 done:
    EnsLockRelease(conn->recv_mutex);

    return rc;
}

    

ens_rc_t ens_RecvView(ens_conn_t *conn, ens_member_t *memb, ens_view_t *view)
{
    int nmembers;

    EnsTrace(NAME,"ens_RecvView");
    EnsLockTake(conn->recv_mutex);
    {
        // Extract the number of group-members from the member state.
        nmembers= memb->nmembers;
        if (0 >= nmembers) {
            printf ("nmembers=%d\n", memb->nmembers); fflush(stdout);
        }
        assert(0 < nmembers);
        assert(nmembers< 1000);

        view->nmembers = nmembers;
            
        EnsTrace(NAME,"nmembers:%d", memb->nmembers);
        ReadString(conn, ENS_VERSION_MAX_SIZE, view->version);
        ReadString(conn, ENS_GROUP_NAME_MAX_SIZE, view->group);
        ReadString(conn, ENS_PROTOCOL_MAX_SIZE, view->proto);
        view->ltime = ReadInt (conn);
        view->primary = ReadBool (conn);

        ReadString(conn, ENS_PARAMS_MAX_SIZE, view->params);
        ReadAddrArray (conn, nmembers, view->address);
        ReadEndptArray (conn, nmembers, view->endpts);
        
        ReadEndpt (conn, &view->endpt);
        ReadAddr(conn, &view->addr);
        view->rank = ReadInt (conn);
        ReadString(conn, ENS_NAME_MAX_SIZE, view->name);
        ReadViewId(conn, &view->view_id);
        
        // Update the member state
        memb->rank = view->rank;
        
        ReadEnd(conn);
    }
    EnsLockRelease(conn->recv_mutex);

    EnsTrace(NAME,"Done ens_RecvView");
    
    /* This call will always succeed because we aren't reading from the socket,
     * just from our internal read-header buffer. 
     */
    return ENS_OK;
}

ens_rc_t ens_RecvMsg(ens_conn_t *conn, /*OUT*/ int *origin, char *buf)
{
    ens_rc_t rc = ENS_OK;
    
    EnsLockTake(conn->recv_mutex);
    {
        
        *origin = ReadInt(conn);
        
	EnsTrace(NAME, "RecvMsg origin=%d len=%d", (*origin), conn->read_data_len);

        // setup the bulk_data buffer to point to user-buffer
        conn->read_data.buf = buf;
        
        // Read the bulk data
        if (conn->read_data_len > 0) {
            rc = EnsTcpRecv(conn->socket, conn->read_data_len, conn->read_data.buf);
	}
            
        // Completed reading a server message. Reset the read state.
        ReadEnd(conn);
    }
    EnsLockRelease(conn->recv_mutex);
    
    return rc;
}

/************************ User Downcalls ****************************/

// Check that the member is in a Normal status 
static void CheckValid(ens_member_t *m, const char *s) 
{
    switch (m->current_status) {
    case Normal:
        break;
    default:
        EnsPanic("Operation <%s> while group is <%s> member_id <%d>",
                 s, StringOfStatus(m->current_status), m->id);
    }
}

/* Join a group. 
 */
ens_rc_t ens_Join(ens_conn_t *conn, ens_member_t *m, ens_jops_t *jops, void *ctx)
{
    ens_rc_t rc;
    
    EnsTrace(NAME,"ens_Join");

    // Cleanup the member.
    memset(m, 0, sizeof(ens_member_t));
    m->user_ctx = ctx;
        
    EnsLockTake(conn->send_mutex);
    {
        // Update the state of the member to Joining
        m->current_status = Joining;
        m->conn = conn;
        
        // We must provide the member with an ID prior to any other operation
        m->id = AllocMid(conn);
        
        WriteBegin(conn); 
        // Write the downcall.
        WriteHdr(m, DN_JOIN);
        EnsTrace(NAME,"joining %s", jops->group_name);
        WriteString(conn, jops->group_name);
        WriteString(conn, jops->properties);
        WriteString(conn, jops->params);
        WriteString(conn, jops->princ);
        WriteBool(conn, jops->secure);
        rc = WriteEnd(conn);
        
        // Add the member to the hashtable. This will allow
        // finding it when messages arrive on the socket.
        MemberAdd(m);
    }
    EnsLockRelease(conn->send_mutex);

    return rc;
}

    
/* Leave a group. This should be the last call made to the member
 * It is possible for messages to be delivered to this member after the call
 * returns. However, it is illegal to initiate new actions on this member.
 */
ens_rc_t ens_Leave(ens_member_t *m)
{
    ens_rc_t rc;
    ens_conn_t *conn = m->conn;
    
    EnsLockTake(conn->send_mutex);
    {
        CheckValid(m, "ens_Leave");
        m->current_status = Leaving;
        
        WriteBegin(conn); 
        // Write the downcall.
        WriteHdr(m, DN_LEAVE);
        rc = WriteEnd(conn);
    }
    EnsLockRelease(conn->send_mutex);
    
    return rc;
}

// Send a multicast message to the group.
ens_rc_t ens_Cast(ens_member_t *m, int len, char *buf)
{
    ens_rc_t rc;
    ens_conn_t *conn = m->conn;

    EnsTrace(NAME,"ens_Cast");
    EnsLockTake(conn->send_mutex);
    {
        CheckValid(m, "ens_Cast");
        WriteBegin(conn);
        WriteHdr(m,DN_CAST);
        WriteData(conn, len, buf);
        rc = WriteEnd(conn);
    }
    EnsLockRelease(conn->send_mutex);

    return rc;
}

// Send a point-to-point message to a list of members.
ens_rc_t ens_Send(ens_member_t *m, int num_dests, int *dests, int len, char* data) 
{
    ens_rc_t rc;
    ens_conn_t *conn = m->conn;
    int i;
    
    //    TRACE("ce_st_Send");
    EnsLockTake(conn->send_mutex);
    {
        CheckValid(m, "ens_Send");
        WriteBegin(conn);
        WriteHdr(m,DN_SEND);
        WriteInt(conn,num_dests);
        for (i=0; i<num_dests; i++) 
        {
            if (dests[i] < 0 || dests[i] > m->nmembers)
                EnsPanic("destination out of bounds, nmembers= %d destination=%d",
                         m->nmembers, dests[i]);
            WriteInt(conn, dests[i]);
        }
        WriteData(conn,len,data);
        rc = WriteEnd(conn);
    }
    EnsLockRelease(conn->send_mutex);

    return rc;
}

// Send a point-to-point message to the specified group member.
ens_rc_t ens_Send1(ens_member_t *m, int dest, int len, char *data)
{
    ens_rc_t rc;
    ens_conn_t *conn = m->conn;

    EnsLockTake(conn->send_mutex);
    {
        CheckValid(m, "ens_Send1");
        if (dest < 0 || dest > m->nmembers)
                EnsPanic("destination out of bounds, nmembers= %d destination=%d",
                         m->nmembers, dest);
        WriteBegin(conn);
        WriteHdr(m,DN_SEND1);
        WriteInt(conn,dest);
        WriteData(conn,len,data);
        rc = WriteEnd(conn);
    }
    EnsLockRelease(conn->send_mutex);

    return rc;
}

// Report group members as failure-suspected.
ens_rc_t ens_Suspect(ens_member_t *m, int num, int *suspects)
{
    ens_rc_t rc;
    ens_conn_t *conn = m->conn;
    int i;
    
    EnsLockTake(conn->send_mutex);
    {
        CheckValid(m, "ens_Suspect");
        WriteBegin(conn);
        WriteHdr(m,DN_SUSPECT);
        WriteInt(conn,num);
        for (i=0; i<num; i++) 
        {
            if (suspects[i] < 0 || suspects[i] > m->nmembers) 
                EnsPanic("suspicion out of bounds, nmembers= %d suspect=%d",
                         m->nmembers, suspects[i]);
            WriteInt(conn, suspects[i]);
        }
        rc = WriteEnd(conn);
    }
    EnsLockRelease(conn->send_mutex);

    return rc;  
}

// Send a BlockOk
ens_rc_t ens_BlockOk(ens_member_t *m) 
{
    ens_rc_t rc;
    ens_conn_t *conn = m->conn;
    
    EnsLockTake(conn->send_mutex);
    {
        CheckValid(m, "ens_BlockOk");
        // Update the member state to Blocked. 
        m->current_status = Blocked;
	
        WriteBegin(conn);
        // Write the block_ok downcall.
        WriteHdr(m,DN_BLOCK_OK) ;
        rc = WriteEnd(conn);
    }
    EnsLockRelease(conn->send_mutex);
    
    return rc;
}

/* Check if there is a pending message. If it returns true then Recv will 
 * with a message. 
 */
ens_rc_t ens_Poll(ens_conn_t *conn, int milliseconds, /*OUT*/ int *data_available)
{
    ens_rc_t rc;

    EnsTrace(NAME,"ens_Poll");
//    EnsLockTake(conn->recv_mutex);
    {
	/* There can't be concurrent executions of Recv and Poll since they
	 * lock the object. 
	 */
	rc = EnsPoll(conn->socket, milliseconds);

	switch(rc) {
	case -1:
	    rc = ENS_ERROR;
	    break;
	case 0:
	    *data_available = 0;
	    rc = ENS_OK;
	    break;
	case 1:
	    *data_available = 1;
	    rc = ENS_OK;
	    break;
	default:
	    EnsPanic("Internal error, bad value returned by EnsTcpPoll");
	}
    }
//    EnsLockRelease(conn->recv_mutex);
    
    return rc;
}

/* Connect to the Ensemble server. Prior to this call any attempt to use
 * this connection will fail.
 */
ens_conn_t *ens_Init(int port)
{
    ens_sock_t sock;
    ens_conn_t *conn;
    
    if (-1 == EnsTcpInit(port, &sock))
        EnsPanic("could not connect to the server, it is probably down.");

    // Initialize the connection structure
    conn = EnsMalloc(sizeof(ens_conn_t));
    InitConn(conn, sock, port);

    return conn;
}

