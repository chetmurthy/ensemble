/**************************************************************/

#include "skt.h"

/**************************************************************/
#ifndef _WIN32
value win_version(){ invalid_argument("Calling win_version on a Unix system");}
#else

value
win_version(){
  DWORD dwVersion, MajorVersion, MinorVersion;
  char *rep;
  int len;
  value rep_v;
  
  dwVersion = GetVersion();
  
  // Get the Windows version.
  MajorVersion =  (DWORD)(LOBYTE(LOWORD(dwVersion)));
  MinorVersion =  (DWORD)(HIBYTE(LOWORD(dwVersion)));

  switch (MinorVersion){
  case 0:
    switch (MajorVersion) {
    case 3:
      rep = "NT3.5";
      break;
    case 4:
      rep = "NT4.0";
      break;
    case 5:
      rep = "2000";
      break;
    default:
      printf("major=%d\n", MajorVersion); fflush(stdout);
      invalid_argument ("Bad major version in WIN32 system");
      break;
    }
    break;

  case 1:
    switch (MajorVersion){
    case 4:
      rep = "95/98";
      break;
    case 3:
      rep = "3.11";
      break;
    default:
      printf("major=%d\n", MajorVersion); fflush(stdout);
      invalid_argument ("Bad major version in WIN32 system");
      break;
    }
    break;

  default:
    printf("minor=%d\n", MajorVersion); fflush(stdout);
    invalid_argument ("Bad minor version in WIN32 system");
    break;
  }

  len = strlen(rep);
  rep_v = alloc_string(len);
  memcpy(String_val(rep_v), rep, len);
  return rep_v;
}

#endif

/**************************************************************/

value skt_substring_eq(
        value s1_v,
	value ofs1_v,
	value s2_v,
	value ofs2_v,
	value len_v
) {
  long len ;
  long ret ;
  char *s1 ;
  char *s2 ;
  
  len = Long_val(len_v) ;
  s1 = ((char*)String_val(s1_v)) + Long_val(ofs1_v) ;
  s2 = ((char*)String_val(s2_v)) + Long_val(ofs2_v) ;
  ret = !memcmp(s1,s2,len) ;
  return Val_bool(ret) ;
}

/**************************************************************/
/* A set of errors to ignore on receiving a UDP packet.
 */
void skt_udp_recv_error(void) {
  switch (h_errno) {
#ifdef EPIPE
  case EPIPE:
#endif

/* Unix and WIN32 (in errno.h)
 */
#ifdef EINTR
  case EINTR:
#endif
#ifdef EAGAIN
  case EAGAIN:
#endif

#ifdef ECONNREFUSED
  case ECONNREFUSED:
#endif
    /* WIN32 */
#ifdef WSAECONNREFUSED
  case WSAECONNREFUSED:
#endif

#ifdef ECONNRESET
  case ECONNRESET:
#endif
    /* WIN32 */
#ifdef WSAECONNRESET
  case WSAECONNRESET:
#endif

#ifdef ENETUNREACH
  case ENETUNREACH:
#endif
    /* WIN32 */
#ifdef WSAEHOSTUNREACH
  case WSAEHOSTUNREACH:
#endif

#ifdef EHOSTDOWN
  case EHOSTDOWN:
#endif
    /* WIN32 */
#ifdef WSAEHOSTDOWN
  case WSAEHOSTDOWN:
#endif

    /* WIN32 */
#ifdef WSAEMSGSIZE
  case WSAEMSGSIZE:
#endif
  
    /* Do nothing */
    break ;
  default:
    printf ("Udp recv, uncaught error (%d)\n", h_errno);
    serror("udp_recv");
    break ;
  }
}

#ifndef _WIN32
void serror(const char *cmdname)
{
  /* unix_error is from unixsupport.c */
  extern void unix_error(int errcode, const char * cmdname, value arg);
  unix_error(h_errno, cmdname, Nothing);
}

#else

enum {
  X_E2BIG, X_EACCES, X_EAGAIN, X_EBADF, X_EBUSY, X_ECHILD, X_EDEADLK, X_EDOM,
  X_EEXIST, X_EFAULT, X_EFBIG, X_EINTR, X_EINVAL, X_EIO, X_EISDIR, X_EMFILE,
  X_EMLINK, X_ENAMETOOLONG, X_ENFILE, X_ENODEV, X_ENOENT, X_ENOEXEC, X_ENOLCK,
  X_ENOMEM, X_ENOSPC, X_ENOSYS, X_ENOTDIR, X_ENOTEMPTY, X_ENOTTY, X_ENXIO,
  X_EPERM, X_EPIPE, X_ERANGE, X_EROFS, X_ESPIPE, X_ESRCH, X_EXDEV,
  X_EWOULDBLOCK, X_EINPROGRESS, X_EALREADY,
  X_ENOTSOCK, X_EDESTADDRREQ, X_EMSGSIZE, X_EPROTOTYPE, X_ENOPROTOOPT,
  X_EPROTONOSUPPORT, X_ESOCKTNOSUPPORT, X_EOPNOTSUPP, X_EPFNOSUPPORT,
  X_EAFNOSUPPORT, X_EADDRINUSE, X_EADDRNOTAVAIL, X_ENETDOWN, X_ENETUNREACH,
  X_ENETRESET, X_ECONNABORTED, X_ECONNRESET, X_ENOBUFS, X_EISCONN, X_ENOTCONN,
  X_ESHUTDOWN, X_ETOOMANYREFS, X_ETIMEDOUT, X_ECONNREFUSED, X_EHOSTDOWN,
  X_EHOSTUNREACH, X_ELOOP /*, EUNKNOWNERR */
};

/* This table HAS to be in the same order as the CAML table from
 * unixsupport.c
 */
int convert_error_table[] = {
  X_E2BIG, X_EACCES, X_EAGAIN, X_EBADF, X_EBUSY, X_ECHILD, X_EDEADLK, X_EDOM,
  X_EEXIST, X_EFAULT, X_EFBIG, X_EINTR, X_EINVAL, X_EIO, X_EISDIR, X_EMFILE,
  X_EMLINK, X_ENAMETOOLONG, X_ENFILE, X_ENODEV, X_ENOENT, X_ENOEXEC,
  X_ENOLCK, X_ENOMEM, X_ENOSPC, X_ENOSYS, X_ENOTDIR, X_ENOTEMPTY, X_ENOTTY,
  X_ENXIO, X_EPERM, X_EPIPE, X_ERANGE, X_EROFS, X_ESPIPE, X_ESRCH, X_EXDEV,
  X_EWOULDBLOCK, X_EINPROGRESS, X_EALREADY, X_ENOTSOCK, X_EDESTADDRREQ,
  X_EMSGSIZE, X_EPROTOTYPE, X_ENOPROTOOPT,
  X_EPROTONOSUPPORT, X_ESOCKTNOSUPPORT, X_EOPNOTSUPP, X_EPFNOSUPPORT,
  X_EAFNOSUPPORT, X_EADDRINUSE, X_EADDRNOTAVAIL, X_ENETDOWN, X_ENETUNREACH,
  X_ENETRESET, X_ECONNABORTED, X_ECONNRESET, X_ENOBUFS, X_EISCONN, X_ENOTCONN,
  X_ESHUTDOWN, X_ETOOMANYREFS, X_ETIMEDOUT, X_ECONNREFUSED, X_EHOSTDOWN,
  X_EHOSTUNREACH, X_ELOOP /*, EUNKNOWNERR */
};


int convert(int err){
  switch (err) {
  case WSAEINTR: return X_EINTR;
  case WSAEBADF:  return X_EBADF;
  case WSAEACCES: return X_EACCES;
  case WSAEFAULT: return X_EFAULT;
  case WSAEINVAL: return X_EINVAL;
  case WSAEMFILE: return X_EMFILE;
  case WSAEWOULDBLOCK: return X_EWOULDBLOCK;
  case WSAEINPROGRESS: return X_EINPROGRESS;
  case WSAEALREADY: return X_EALREADY;
  case WSAENOTSOCK: return X_ENOTSOCK;
  case WSAEDESTADDRREQ: return X_EDESTADDRREQ;
  case WSAEMSGSIZE: return X_EMSGSIZE;
  case WSAEPROTOTYPE: return X_EPROTOTYPE;
  case WSAENOPROTOOPT: return X_ENOPROTOOPT;
  case WSAEPROTONOSUPPORT: return X_EPROTONOSUPPORT;
  case WSAESOCKTNOSUPPORT: return X_ESOCKTNOSUPPORT;
  case WSAEOPNOTSUPP: return X_EOPNOTSUPP;
  case WSAEPFNOSUPPORT: return X_EPFNOSUPPORT;
  case WSAEAFNOSUPPORT: return X_EAFNOSUPPORT;
  case WSAEADDRINUSE: return X_EADDRINUSE;
  case WSAEADDRNOTAVAIL: return X_EADDRNOTAVAIL;
  case WSAENETDOWN: return X_ENETDOWN;
  case WSAENETUNREACH: return X_ENETUNREACH;
  case WSAENETRESET: return X_ENETRESET;
  case WSAECONNABORTED: return X_ECONNABORTED;
  case WSAECONNRESET: return X_ECONNRESET;
  case WSAENOBUFS: return X_ENOBUFS;
  case WSAEISCONN: return X_EISCONN;
  case WSAENOTCONN: return X_ENOTCONN;
  case WSAESHUTDOWN: return X_ESHUTDOWN;
  case WSAETOOMANYREFS: return X_ETOOMANYREFS;
  case WSAETIMEDOUT: return X_ETIMEDOUT;
  case WSAECONNREFUSED: return X_ECONNREFUSED;
  case WSAELOOP: return X_ELOOP;
  case WSAENAMETOOLONG: return X_ENAMETOOLONG;
  case WSAEHOSTDOWN: return X_EHOSTDOWN;
  case WSAEHOSTUNREACH: return X_EHOSTUNREACH;
  case WSAENOTEMPTY: return X_ENOTEMPTY;

  case WSAEREFUSED:
  case WSATYPE_NOT_FOUND:
  case WSAEINVALIDPROVIDER: 
  case WSASYSCALLFAILURE: 
  case WSAEPROVIDERFAILEDINIT: 
  case WSAEINVALIDPROCTABLE: 
  case WSAEPROCLIM: 
  case WSAEUSERS: 
  case WSA_E_NO_MORE: 
  case WSA_E_CANCELLED: 
  case WSAEDQUOT: 
  case WSAESTALE: 
  case WSAEREMOTE: 
  case WSASYSNOTREADY: 
  case WSAVERNOTSUPPORTED: 
  case WSANOTINITIALISED: 
  case WSAEDISCON:
  case WSAENOMORE: 
  case WSAECANCELLED: 
  default:
    SKTTRACE(("Unknown WINSOCK2 error %d, cannot convert into Unix error\n", err));
    return err;
  }
}

extern value cst_to_constr(int n, int *tbl, int size, int deflt);
static value * unix_error_exn = NULL;

/* Copied from the unix library.
 */
void skt_error(int errcode, const char *cmdname, value cmdarg)
{
  value res;
  value name = Val_unit, err = Val_unit, arg = Val_unit;
  int errconstr;

  Begin_roots3 (name, err, arg);
    arg = cmdarg == Nothing ? copy_string("") : cmdarg;
    name = copy_string(cmdname);
    errconstr =
      cst_to_constr(errcode, convert_error_table, sizeof(convert_error_table)/sizeof(int), -1);
    if (errconstr == Val_int(-1)) {
      err = alloc_small(1, 0);
      Field(err, 0) = Val_int(errcode);
    } else {
      err = errconstr;
    }
    if (unix_error_exn == NULL) {
      unix_error_exn = caml_named_value("Unix.Unix_error");
      if (unix_error_exn == NULL)
        invalid_argument("Exception Unix.Unix_error not initialized, please link unix.cma");
    }
    res = alloc_small(4, 0);
    Field(res, 0) = *unix_error_exn;
    Field(res, 1) = err;
    Field(res, 2) = name;
    Field(res, 3) = arg;
  End_roots();
  mlraise(res);
}

void serror(const char *cmdname)
{
  int errcode;

  errcode = convert(h_errno);
  SKTTRACE(("errno=%d\n", h_errno));
  skt_error(errcode, cmdname, Nothing);
}
#endif

/**************************************************************/
