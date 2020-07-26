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

public class Hot_Error {
    private int val;
    private String msg;

    public Hot_Error(int value, String message) {
	val = value;
	msg = message;
    }

    public String toString() {
	return new String("Hot_Error: " + val + ": " + msg);
    }

}
