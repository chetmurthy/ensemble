//**************************************************************
//*
//*  Ensemble, (Version 0.70p1)
//*  Copyright 2000 Cornell University
//*  All rights reserved.
//*
//*  See ensemble/doc/license.txt for further information.
//*
//**************************************************************
import java.awt.*;
import java.awt.event.*;
import ensemble.hot.*;


public class EnsDemo implements MouseListener, WindowListener , Hot_Callbacks {
    private static EnsDemo selfRef;

    public EnsDemo(int f) {
        portNumber = f;
    }

    public EnsDemo() {}

    public static void main(String[] args) {
	selfRef = new EnsDemo();
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
	
    public void go() {
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
		
	he = new Hot_Ensemble();
	he.setDebug(false);
	mainThread = new Thread(he);
	
	mainThread.start();

	jops = new Hot_JoinOps();
	jops.heartbeat_rate = 5000;
	jops.transports = "UDP";
	jops.protocol = "Top:Heal:Switch:Leave:Inter:Intra:Elect:Merge:Sync:Suspect:Top_appl:Pt2ptw:Pt2pt:Frag:Stable:Mnak:Bottom";
	jops.group_name = "EnsDemoGroup";
	jops.params = "primary_quorum=2:int;suspect_max_idle=3:int;suspect_sweep=3.000:time";
	jops.conf = this;
	jops.use_properties = true;

	Hot_GroupContext[] hgc = new Hot_GroupContext[1];
	Hot_Error hotError = he.Join(jops,hgc);
	gctx = hgc[0];		
	if (hotError != null) {
	    ta.append("Couldn't join group!!: " + hotError + "\n");
	    Hot_Ensemble.Panic("HOSED!!!");
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

    public void ReceiveSend(Hot_GroupContext gctx, Object env, 
				Hot_Endpoint origin, Hot_Message msg) {
	ta.append("p2p: '" + new String(msg.getBytes()) + "' from " + origin.name + "\n");
    }


    public void AcceptedView(Hot_GroupContext gctx, Object env, 
				Hot_ViewState viewState) {
	vs = viewState;
	if (vs.rank == 0)
	    ta.append("EnsDemo:view (nmembers=" + vs.nmembers + ", rank=" 
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
	
	//for (i = 0; i < view_state->nmembers; i++)
	//printf("%s\n", view_state->members[i].name);
	
    }

    public void Heartbeat(Hot_GroupContext gctx, Object env, int rate) {
	ta.append("Heartbeat..."+ "\n");
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

    private void handleSend() {
	Hot_Message msg = new Hot_Message();
    }

    public void mouseClicked(MouseEvent e) {
	Object obj = e.getSource();
		
	if (obj == ltjButton) {
	    handleLTJ();
	} else if (obj == castButton) {
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

// End class EnsDemo
}
