/**************************************************************/
/* EnsDemoOutboard.java */
/* Author: Jason Dale */
/**************************************************************/

import java.awt.*;
import java.awt.event.*;
import java.lang.*;
import ensemble.hot.*;

// HT2_TEST comments define code which will allow this
// EJava application to interface with the HOT "C" test
// program, hot_test2.  This code is all commented out
// by default.

public class EnsDemoOutboard implements MouseListener, WindowListener , Hot_Callbacks {
    private static EnsDemoOutboard selfRef;
    private static boolean use_BS;  // use ByteStream flag (instead of
				    // HotObjectMessage default).

    public EnsDemoOutboard(int f) {
        portNumber = f;
    }

    public EnsDemoOutboard() {}

    public static void main(String[] args) {
	selfRef = new EnsDemoOutboard();
	selfRef.go();
    }

    Frame mainFrame;
    TextArea ta;
    TextField tf;
    Label csLabel;
    Button ltjButton;
    Button castButton;
    Button sendButton;
    Button rnvButton;
    int hot_test2;   // Flag to test interop ONLY with hot_test2 app!!
	
    public void go() {
	// HT2_TEST code:
	// Set to 1 to test interop with hot_test2 app
	hot_test2 = 0;   

	mainFrame = new Frame();
	mainFrame.setLayout(null);
	mainFrame.setSize(432,507);
	mainFrame.addWindowListener(this);

	ta = new TextArea();
	ta.setBounds(12,36,408,348);
	ta.setEditable(false);
	mainFrame.add(ta);

	tf = new TextField();
	tf.setBounds(108,392,240,24);
	mainFrame.add(tf);

	csLabel = new Label("Cast/Send:");
	csLabel.setBounds(12,392,85,18);
	mainFrame.add(csLabel);

	ltjButton = new Button("LeaveThenJoin");
	ltjButton.setBounds(24,428,108,25);
	ltjButton.addMouseListener(this);
	mainFrame.add(ltjButton);

	castButton = new Button("Cast");
	castButton.setBounds(144,428,86,25);
	castButton.addMouseListener(this);
	mainFrame.add(castButton);

	sendButton = new Button("Send");
	sendButton.setBounds(240,428,86,25);
	sendButton.addMouseListener(this);
	sendButton.setEnabled(false);
	mainFrame.add(sendButton);
		
	mainFrame.show();

	// Multiple processes can connect to the same outboard
	// by specifying a port number in the following call,
	// However the outboard process has to be already started
	// properly, e.g.:
	// outboard -tcp_channel -tcp_port 7636
	
	// HT2_TEST code:
	// new constructor takes use_ByteStream flag:
	// set use_BS to true to use ByteStream instead of HotObjectMessage
	// for interop with hot_test2.  This will result in use of the
	// ReceiveCastByteStream callback and handleCastByteStream send
	// function instead of the defaults.
	use_BS = false;
	he = new Hot_Ensemble(use_BS);

	he.setDebug(false);

	mainThread = new Thread(he);
	mainThread.start();

	jops = new Hot_JoinOps();
	jops.heartbeat_rate = 10000;

	// Can use IP Multicast here if desired
	// jops.transports = "DEERING:UDP";
	jops.transports = "UDP";

	jops.group_name = "EnsDemoOutboardGroup";
	// HT2_TEST code:
	// (Comment out previous group_name setting)
	// Set for interop test with hot_test2 ONLY!
	// jops.group_name = "HOT_test2";

	// Configure stack using properties
	jops.properties="Gmp:Sync:Heal:Switch:Frag:Suspect:Flow:Primary";
	jops.params = "primary_quorum=4:int;suspect_max_idle=3:int;suspect_sweep=1.000:time";
	jops.conf = this;
	jops.use_properties = true;

	Hot_GroupContext[] hgc = new Hot_GroupContext[1];

	// Join the group
	Hot_Error hotError = he.Join(jops,hgc);
	gctx = hgc[0];		
	if (hotError != null) {
	    ta.append("Couldn't join group!!: " + hotError + "\n");
	    Hot_Ensemble.Panic("BYE!");
	}

    }
	
    Thread mainThread;
    int portNumber;
    Hot_Ensemble he;
    Hot_JoinOps jops;
    Hot_ViewState vs;
    Hot_GroupContext gctx;
	
    public void ReceiveCast(Hot_GroupContext gctx, Object env, 
				Hot_Endpoint origin, Hot_Message msg) {
	Hot_ObjectMessage hom = new Hot_ObjectMessage(msg);
	Object o = hom.getObject();
	if (o instanceof String) {
	    String s = (String)o;

	    ta.append("mcast: " + s + "' from " + origin.name + "\n");
	} else {
	    ta.append("mcast: DIDN'T GET A STRING OBJECT!!!!");
	}
    }

    public void ReceiveCastByteStream(Hot_GroupContext gctx, Object env, 
				Hot_Endpoint origin, Hot_Message msg) {

	String sr = null;
	sr = msg.toAsciiString();
	ta.append("Rcvd mcast:" + sr + " from " + origin.name + "\n");

	// HT2_TEST code:
	// hot_test2 interop test code only!!!	
	if (hot_test2 != 0)
	{
	    Hot_Message hm = new Hot_Message();
	    // Arbitrary string
	    String s = new String("Phone HOME!");
	    byte [] bt = s.getBytes();
	    hm.setBytes(bt);
	    int[] foo = new int[1];
	    he.Cast(gctx,hm,foo);
	    ta.append("Replied to Cast\n");
	}
    }

    public void ReceiveSend(Hot_GroupContext gctx, Object env, 
				Hot_Endpoint origin, Hot_Message msg) {
	Hot_ObjectMessage hom = new Hot_ObjectMessage(msg);
	Object o = hom.getObject();
	if (o instanceof String) {
	    String s = (String)o;
            ta.append("p2p: " + s + "' from " + origin.name + "\n");
	} else {
	    ta.append("p2p: DIDN'T GET A STRING OBJECT!!!!");
	}
    }


    public void AcceptedView(Hot_GroupContext gctx, Object env, 
				Hot_ViewState viewState) {
	vs = viewState;
	if (vs.rank == 0)
	    ta.append("EnsDemoOutboard:view (nmembers=" + vs.nmembers + ", rank=" 
			+ vs.rank + ")\n");
	ta.append("\tview_id = ("+vs.view_id.ltime+","+vs.view_id.coord.name+")\n");
	ta.append("\tversion = \""+vs.version + "\n");
	ta.append("\tgroup_name = \""+vs.group_name+ "\n");
	ta.append("\tprotocol = \""+vs.protocol+ "\n");
	ta.append("\tmy_rank = "+vs.rank+ "\n");
	ta.append("\tgroup daemon is %s"+ (vs.groupd ? "in use" : "not in use")+ "\n");
	ta.append("\tparameters = \""+vs.params+ "\n");
	ta.append("\txfer_view = "+vs.xfer_view+ "\n");
	ta.append("\tprimary = " + vs.primary+ "\n");

	if (vs.nmembers > 1)
	    sendButton.setEnabled(true);
	else
	    sendButton.setEnabled(false);

	//for (i = 0; i < view_state->nmembers; i++)
	//printf("%s\n", view_state->members[i].name);
	
    }

    public void Heartbeat(Hot_GroupContext gctx, Object env, int rate) {
	// ta.append("Heartbeat..."+ "\n");
    }

    public void Block(Hot_GroupContext gctx, Object env) {
	ta.append("Blocking..."+ "\n");
    }

    public void Exit(Hot_GroupContext gctx, Object env) {
	ta.append("Exit..."+ "\n");
    }

    
    private void handleLTJ() {
	he.Leave(gctx);
	
	Hot_GroupContext[] hgc = new Hot_GroupContext[1];
	he.Join(jops,hgc);
	gctx = hgc[0];
		
	ta.append("successfully rejoined the group"+ "\n");
	
    }

    private void handleCast() {
	Hot_ObjectMessage msg = new Hot_ObjectMessage();
	msg.setObject(tf.getText());
	int[] foo = new int[1];
	he.Cast(gctx,msg,foo);
	ta.append("Casted: " + tf.getText() + "\n");
    }

    private void handleCastByteStream() {
	Hot_Message msg = new Hot_Message();
	String s = tf.getText();
	byte [] bt = s.getBytes();
	msg.setBytes(bt);
	int[] foo = new int[1];
	he.Cast(gctx,msg,foo);
	ta.append("Casted: " + tf.getText() + "\n");
    }

    private void handleSend() {
	Hot_ObjectMessage msg = new Hot_ObjectMessage();
	Hot_Endpoint dest = new Hot_Endpoint();

	msg.setObject(tf.getText());
	int[] foo = new int[1];

	// WARNING!!  This is a hack just to test the
	// functionality of Send!
	// NOTE: Send button is currently disabled (see above)
	// has to be re-enabled to run this hack.
 	if (vs.rank == 0 && vs.nmembers > 1)
	    dest = vs.members[1];
	else
	    dest = vs.members[0];		
	he.Send(gctx,dest,msg,foo);
	ta.append("Sent: " + tf.getText() + " to " + dest + "\n");
    }

    public void mouseClicked(MouseEvent e) {
	Object obj = e.getSource();
		
	if (obj == ltjButton) {
	    handleLTJ();
	} else if (obj == castButton) {
	    if (use_BS)
	        handleCastByteStream();
	    else
	        handleCast();
	} else if (obj == sendButton) {
	    handleSend();
	}
    }

    public void mouseEntered(MouseEvent e) {}
    public void mouseExited(MouseEvent e) {}
    public void mousePressed(MouseEvent e) {}
    public void mouseReleased(MouseEvent e) {}

    public void windowActivated(WindowEvent e) {}
    public void windowClosed(WindowEvent e) {}
    public void windowClosing(WindowEvent e) {
	he.destroyOutboard();
	System.exit(0);
    }
    public void windowDeactivated(WindowEvent e) {}
    public void windowDeiconified(WindowEvent e) {}
    public void windowIconified(WindowEvent e) {}
    public void windowOpened(WindowEvent e) {}

// End class EnsDemoOutboard
}
