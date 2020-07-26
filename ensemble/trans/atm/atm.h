/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/

void atm_init(void) ;
void atm_send(int vci, char *buf, int len) ;
int  atm_recv(int *vci, char *buf, int len) ;
void atm_activate(int vci) ;
