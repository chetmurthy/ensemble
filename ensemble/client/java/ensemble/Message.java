package ensemble;

public class Message {
    /** endpoint this message blongs to */
    public Member m;           
    
    /** message type */
    public int /*UpType*/ mtype ;
    
    /** view message */
    public View view;
    
    /** multicast/pt2pt message origin */
    public int origin;
    /** multicast/pt2pt message data */
    public byte[] data;
}

