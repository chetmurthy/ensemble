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


public class Hot_Endpoint implements java.io.Serializable {
    public String name;

    public String toString() {return name;}

    public boolean equals(Object obj) {
	String       other_name;
	Hot_Endpoint other=(Hot_Endpoint)obj;
	if(other == null)
	    return false;
	if(other == this)
	    return true;
	other_name=other.name;
	if(name.equals(other_name))
	    return true;
	return false;
    }
}