// terminal 1>  maestro_test2.exe -c
// terminal 2>  maestro_test2.exe -j 10 -d 500
#include <iostream.h>
#include "Maestro.h"
#include <sys/types.h>

class Mbr: public Maestro_ClSv {
 public:
    Mbr (int id, Maestro_ClSv_Options &ops)
	: Maestro_ClSv (ops),
	id_ (id) {
	cout << id_ << ":joining\n";
	join();
	cout << id_ << ":joined\n";
    }
    int id_;
    
 protected:
    void clSv_AcceptedView_Callback(Maestro_ClSv_ViewData &viewData,
				   Maestro_Message &msg) {
	cout << id_ << ": ACCEPTED VIEW: " << viewData.viewID <<
	    "(" << viewData.nmembers << " memb, "
	     << viewData.servers.size() << " serv, "
	     << viewData.xferServers.size() << " xf-serv, "
	     << viewData.clients.size() << " clts)" << endl;
    }
};

int main (int argc, char** argv)
{
    Maestro_ClSv_Options ops ; //= Maestro_ClSv_Options();
    ops.heartbeatRate = 10;
    ops.groupName = "maestro_thread";
    ops.transports = "DEERING";
    // TBD: set this to null for now, in the future we can forward any
    // args we don't use to maestro
    ops.argv = NULL;
    ops.properties = // "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow";
	"Gmp:Sync:Heal:Switch:Frag:Suspect:Slander:Flow:Total";
    ops.params = "suspect_max_idle=3:int;suspect_sweep=1.000:time";
    ops.groupdFlag = 0 ;
    ops.debug = 0 ;
    
    /* Need to test Roy's new state xfer code */
    ops.mbrshipType = MAESTRO_SERVER;
    ops.xferType = MAESTRO_ATOMIC_XFER;
    
    // command flags 
    int modeFlag=0;
    int numJumps=10;
    int delay=1000;
    for(int c=1;c<argc;c++) {
	cout<<"argv[c]="<<argv[c]<<endl;
	if (argv[c][0]=='-') {
	    switch(argv[c][1]) {
	    case 'c':  // continuous group member
		modeFlag=0;
		cout<<"Mode == Continuous"<<endl;
		break;
	    case 'j':  //repeatedly join and leave the group
		modeFlag=1;
		if (c+1<argc && argv[c+1][0]!='-') {
		    c++;
		    numJumps=atoi(argv[c]);
		}
		cout<<"Mode == Jumper: "<<numJumps<<endl;
		break;
	    case 'd':  //delay between joins
		modeFlag=1;
		if (c+1<argc && argv[c+1][0]!='-') {
		    c++;
		    delay=atoi(argv[c]);
		}
		cout<<"Delay="<<delay<<endl;
		break;
	    }
	}
    }
    if (modeFlag==0) {
	new Mbr(0,ops);
    }
    else {
	Mbr **a=new Mbr*[numJumps];
	a[0]=new Mbr(0,ops);    
	for (int i=1; i<=numJumps; i++){
	    cout<<"**JOIN**"<<endl;
	    a[i]=new Mbr(i,ops);
	    Maestro_Thread::usleep(delay);
	    cout<<"**LEAVE "<<i<<"**"<<endl;
	    a[i-1]->leave();
	}
    }
    Maestro_Semaphore sema;
    sema.dec();

    return 0;
}
