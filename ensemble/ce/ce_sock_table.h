/**************************************************************/
/* SOCK_LIST.H */
/* Author: Ohad Rodeh 3/2002 */
/**************************************************************/
/* Implements a list of sockets.
 */
/**************************************************************/

#ifndef __CE_SOCK_TBL_H__
#define __CE_SOCK_TBL_H__

#include "ce_internal.h"

#ifndef _WIN32
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#endif

/*  The hash table itself
 */
typedef struct ce_sock_tbl_inner_t ce_sock_tbl_t;


/* Constructor/Destructor
 */
ce_sock_tbl_t *ce_sock_tbl_t_create(void);
void ce_sock_tbl_t_free(ce_sock_tbl_t*);

/** lookup in the table. Return the context matching the id.
 * Return NULL if no such context exists.
 *
 * @h - hash table
 * @id - the context id we are looking for.
 */
ce_reply_t ce_sock_tbl_lookup(ce_sock_tbl_t *h, CE_SOCKET id,
		       /* OUT */ ce_handler_t *handler, ce_env_t *env);

/*
 *  insert: Insert an item into the hash table.
 *
 * Consumes its arguments.
 * 
 * @h - hash table
 * @id - the context id 
 * @c - the context to insert
 */
ce_reply_t
ce_sock_tbl_insert(ce_sock_tbl_t *h, CE_SOCKET sock, 
		   ce_handler_t handler, ce_env_t env);

/*
 *  remove: Remove an item from the hash table
 * Does not consume its argument.
 */
void
ce_sock_tbl_remove(ce_sock_tbl_t *h, CE_SOCKET sock);

/*
 *  size: return the number of items in the hash-table. 
 */
int ce_sock_tbl_size(ce_sock_tbl_t *h);

/* Set the bit for every open socket in the [fds] structure.
 */
void ce_sock_tbl_fdset(ce_sock_tbl_t *h, fd_set *fds);

/* For each socket whose bit is ON in [fds], invoke the registered
 * function.
 */
void ce_sock_tbl_invoke(ce_sock_tbl_t *h, fd_set *fds);

#endif /* __CE_SOCK_TBL_H__ */
