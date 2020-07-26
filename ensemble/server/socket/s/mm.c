/**************************************************************/
/* MM.C */
/* Author: Ohad Rodeh, 9/2001 */
/* The basic memory management functions. Used to manage user data */
/* in a C layout. */
/**************************************************************/
#include "skt.h"
/**************************************************************/

static value mm_Val_cbuf (char *buf)
{
    CAMLparam0();
    CAMLlocal1(cbuf_v);
    
    cbuf_v = alloc_small(1,Abstract_tag);
    Field(cbuf_v,0) = (value) buf;
    
    CAMLreturn(cbuf_v);
}

value mm_cbuf_free(value cbuf_v)
{
    char *buf = mm_Cbuf_val(cbuf_v);
    if (buf != NULL) free(buf);

    // For extra sanitation
    mm_Cbuf_val(cbuf_v) = NULL;
    return Val_unit;
}

value mm_cbuf_alloc(value len_v)
{
    int len;
    char *buf;
    value cbuf_v;
    
    len = Int_val(len_v);
    SKTTRACE(("mm_alloc(%d) {", len));

    if (len == 0) {
	buf = NULL;
    } else {
	buf = (char*) malloc(len);
    }
    
    if (len>0 && buf == NULL)
	raise_out_of_memory ();    
    
    cbuf_v = mm_Val_cbuf(buf);
    SKTTRACE(("}\n"));
    return cbuf_v;
}


/**************************************************************/
/* An empty iovec.
 * Register it so that the Caml GC will be aware of it. 
 */
static value empty_iovec = (value) NULL;

/* Initialize the empty iovec. The initialization function is called
 * by ssocket.
 */
value mm_empty ()
{
    CAMLparam0();
    if (empty_iovec == (value) NULL) {
	SKTTRACE(("mm_empty: setting mm_empty(\n"));
	empty_iovec =  mm_Val_cbuf(NULL);
	SKTTRACE((".\n"));
	register_global_root(&empty_iovec);
	SKTTRACE((")\n"));
    }
    CAMLreturn(empty_iovec);
}

value mm_copy_cbuf_ext_to_string(value src_cbuf_v, value src_ofs_v, 
                                 value dst_v, value dst_ofs_v, value len_v)
{
    int len;
    int src_ofs, dst_ofs;
    char *src_cbuf, *dst;
    
    SKTTRACE2(("mm_copy_cbuf_ext_to_string("));
    src_cbuf = mm_Cbuf_val(src_cbuf_v);
    src_ofs= Int_val(src_ofs_v);
    dst = String_val(dst_v);
    dst_ofs = Int_val(dst_ofs_v);
    len = Int_val(len_v);
        
    memcpy( dst + dst_ofs, src_cbuf + src_ofs, len);
    SKTTRACE2((")\n"));
    
    return Val_unit;
}

value mm_copy_string_to_cbuf_ext(value src_v, value src_ofs_v, 
                                 value dst_cbuf_v, value dst_ofs_v, value len_v)
{
    int len, src_ofs, dst_ofs;
    char *dst_cbuf, *src;
    
    SKTTRACE(("mm_copy_string_to_cbuf_ext("));
    src = String_val(src_v);
    src_ofs = Int_val(src_ofs_v);
    dst_cbuf = mm_Cbuf_val(dst_cbuf_v);
    dst_ofs = Int_val(dst_ofs_v);
    len = Int_val(len_v);
    
    memcpy(dst_cbuf+ dst_ofs, src + src_ofs, len);
    SKTTRACE((")\n"));
    
    return Val_unit;
}

value mm_copy_cbuf_ext_to_cbuf_ext(value src_cbuf_v, value src_ofs_v, 
                                     value dst_cbuf_v, value dst_ofs_v, value len_v)
{
    int len, src_ofs, dst_ofs;
    char *src_cbuf, *dst_cbuf;
    
    SKTTRACE(("mm_copy_cbuf_ext_to_cbuf_ext("));
    src_cbuf = mm_Cbuf_val(src_cbuf_v);
    src_ofs = Int_val(src_ofs_v);
    dst_cbuf = mm_Cbuf_val(dst_cbuf_v);
    dst_ofs = Int_val(dst_ofs_v);
    len = Int_val(len_v);

    memcpy(dst_cbuf+dst_ofs, src_cbuf+src_ofs, len);
    SKTTRACE((")\n"));
    
    return Val_unit;
}

/* Flatten an array of iovectors. 
 * A iovec of the correct size is preallocated, and given by the
 * ML side. 
 */
value mm_flatten(value iova_v, value iov_v)
{
    int len, i, n, dst_ofs;
    char *dst, *src;
    value iov_i_v;
    
    SKTTRACE(("mm_flatten:("));
    n = Wosize_val(iova_v);
    dst= mm_Cbuf_of_iovec(iov_v);
    
    for (i=0, dst_ofs=0; i<n; i++){
        iov_i_v = Field(iova_v,i);
	src = mm_Cptr_of_iovec(iov_i_v);
	len = mm_Len_of_iovec(iov_i_v);
	memcpy((char*)dst + dst_ofs, src, len);
	dst_ofs += len;
    }
    SKTTRACE((")\n"));
    
    return Val_unit;
}

/**************************************************************/
value mm_output_val(value obj_v, value cbuf_v, value ofs_v, value len_v, value flags_v)
{
    CAMLparam5(obj_v, cbuf_v, ofs_v, len_v, flags_v);

    int len = Int_val(len_v);
    int ofs = Int_val(ofs_v);
    char *cbuf = mm_Cbuf_val(cbuf_v);
    int ret;
    
    SKTTRACE(("output_value_to_block( cbuf=%x ofs=%d len=%d", (int)cbuf, ofs, len));
    ret = output_value_to_block(obj_v, flags_v, cbuf+ofs, len);
    SKTTRACE((")\n"));
    CAMLreturn(Val_int(ret));
}

value mm_input_val(value cbuf_v, value ofs_v, value len_v)
{
    CAMLparam3(cbuf_v, ofs_v, len_v);
    CAMLlocal1(ret_v);
    int len = Int_val(len_v);
    int ofs = Int_val(ofs_v);
    char *cbuf = mm_Cbuf_val(cbuf_v);
    
    SKTTRACE(("input_value_from_block (cbuf=%x ofs=%d len=%d",(int)cbuf, ofs, len));
    ret_v = input_value_from_block(cbuf+ofs, len);
    SKTTRACE((")\n"));
    CAMLreturn(ret_v);
}

/**************************************************************/
