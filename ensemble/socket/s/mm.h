/**************************************************************/
/* MM.H */
/* Author: Ohad Rodeh 9/2001 */
/**************************************************************/

/* The type of user-space allocation and de-allocation functions. 
 */
typedef void* (*mm_alloc_t)(int);
typedef void  (*mm_free_t)(char*);

/* These functions can be set and reset.
 * They are static variables defined in mm.c
 */
mm_alloc_t mm_alloc_fun;
mm_free_t mm_free_fun;

void set_alloc_fun(mm_alloc_t f);
void set_free_fun(mm_free_t f);

value mm_Raw_of_len_buf(int, char*);
char *mm_Cbuf_val(value);

/* An empty iovec.
 */
value mm_empty();


