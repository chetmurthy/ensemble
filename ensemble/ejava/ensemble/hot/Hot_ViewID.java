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

public class Hot_ViewID {
    public int ltime;
    public Hot_Endpoint coord;

    public String toString() {
	return "ltime=" + ltime + ", coord=" + coord;
    }
}
