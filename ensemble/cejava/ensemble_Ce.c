/**************************************************************/
/* ensemble_CE.C: JNI lower part */
/* Author: Ohad Rodeh 6/2002 */
/* based on code by Mattias Ernst */
/**************************************************************/

#include "ce.h"
#include "ensemble_Group.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <stdarg.h>

/**************************************************************/

static JNIEnv *ens_env = NULL; /* always coming from the same thread */
static jclass glbl_Group, glbl_View, glbl_JoinOps, String;

//jmethodID init_View;

// ViewState
static jfieldID view_version, view_proto, view_coord, view_ltime, view_primary, view_groupd, view_xfer_view, view_params, view_uptime, view_view, view_address;

// ViewLocal 
static jfieldID view_endpt, view_addr, view_rank, view_name, view_nmembers, view_am_coord;

// Join Options
static jfieldID jops_hrtbt_rate, jops_transports, jops_protocol, jops_group_name, jops_properties, jops_use_properties, jops_groupd, jops_params, jops_client, jops_debug, jops_endpt, jops_princ, jops_secure;

jmethodID install_cb, exit_cb, recv_cast_cb, recv_send_cb, flow_block_cb, block_cb, heartbeat_cb;

typedef struct {
    ce_appl_intf_t *c_appl;
    jobject j_group;
//    ce_local_state_t *ls;
//    ce_view_state_t *vs;
} cej_env_t;

static int initialized_nat = 0;

/**************************************************************/
/* Utitlities
 */
static void
cej_panic(const char *s)
{
    printf("CEj, panic: %s\n", s);
    fflush(stdout);
    exit(1);
}

static void
cej_panic2(const char *s, const char *s2)
{
    printf("CEj, panic: %s %s\n", s, s2);
    fflush(stdout);
    exit(1);
}

static void
trace(const char *s, ...)
{
  //#if 0
  va_list args;
  static int debugging = -1 ;

  va_start(args, s);

  if (debugging == -1) {
      debugging = (getenv("CEJAVA_TRACE") != NULL) ;
  }
  
  if (!debugging) return ;

  fprintf(stderr, "Cej: ");
  vfprintf(stderr, s, args);
  fprintf(stderr, "\n");
  va_end(args);
  fflush(stderr);
}

static void *
ce_malloc(int size)
{
    void *ptr;

    if (size==0) return NULL;
    ptr = malloc(size);
    if (ptr == NULL) {
	printf("Out of memory, exiting\n");
	exit(1);
    }
    return ptr;
}

static char*
cString_of_jString(JNIEnv *env, jstring jstr)
{
    char *buf;
    int len;
    const char *cstr;

//    trace ("cString_of_jString(");
    if (jstr == NULL) return NULL;
    len = (*env) -> GetStringUTFLength(env, jstr);
    if (len == 0) return NULL;
//    trace("len=%d\n", len);
    cstr = (*env)->GetStringUTFChars(env, jstr, NULL); 
//    trace (".");
    buf = ce_malloc(len+1);
    strcpy(buf, cstr);
//    trace (".");
    (*env)->ReleaseStringUTFChars(env, jstr, cstr);
    (*env)-> DeleteLocalRef(env, jstr);
//    trace (")");
    return buf;
}

/* Convert a C-iovector into a Java array.
 * JavaByteArray_of_iovec
 */
jbyteArray jba_of_iovec(JNIEnv *env, int len, char *data)
{
    jbyteArray ba;
    char *buf;
    
//    trace("jba_of_iovec[  (len=%d)", len);
    if ((*env)->EnsureLocalCapacity(env, 2) < 0) {
	cej_panic("JVM: out of memory error");
    }
    ba = (*env)->NewByteArray(env, len);	
//    trace(".");
    if (ba == NULL)
	cej_panic("jba_of_iovec, JVM return NULL array");
    buf = (*env)->GetByteArrayElements(env, ba, NULL);
//    trace(".");
    memcpy(buf, data, len);
    (*env)->ReleaseByteArrayElements(env, ba, buf, 0);
//    trace("]");
    return ba;
}

/* Convert a Java-byte array into an iovec.
 */
void iovec_of_jba(JNIEnv *env, jbyteArray msg, int *len, char **data)
{
    jbyte *elements = (*env)->GetByteArrayElements(env, msg, NULL);
    int length = (*env)->GetArrayLength(env, msg);
    char *buf = ce_malloc(length);
    
    memcpy(buf, elements, length);
    *data = buf;
    *len = length;
    (*env)->ReleaseByteArrayElements(env, msg, elements, JNI_ABORT);
    (*env)->DeleteLocalRef(env, msg);
}

/* Convert a Java int-array into a C-array
 */
static void
ia_of_jia(JNIEnv *env, jintArray jia, int *len, int **data)
{
    jint *elements = (*env)->GetIntArrayElements(env, jia, NULL);
    int length = (*env)->GetArrayLength(env, jia);
    int *a = ce_malloc(sizeof(int) * length);
    int i;
    
    for(i=0; i<length; i++) {
	a[i] = elements[i];
    }
    *data = a;
    *len = length;
    (*env)->ReleaseIntArrayElements(env, jia, elements, JNI_ABORT);
}

static jstring
jString_of_cString(JNIEnv *env, char *s)
{
    jstring name;
//    trace("jstring_of_c_string, s=%s", s);
    name = (*env)->NewStringUTF(env, s);
//    if (name == NULL)
//	trace("==NULL");
    return name;
}

/* Convert a C stringArray into a Java stringArray.
 */
static jobject
jStringArray_of_cStringArray(JNIEnv *env, int n, char **a)
{
    jobject array, name;
    int i;
    
    array = (*env)->NewObjectArray(env, n, String, NULL);
    for(i = 0; i < n; i++) {
	name = (*env)->NewStringUTF(env, a[i]);
	(*env)->SetObjectArrayElement(env, array, i, name);
    }
    return array;
}

/* Convert a C stringArray into a Java stringArray.
 */
void
cArgs_of_jArgs(JNIEnv *env, jobject jsa,
	       int *len, char ***a)
{
    jobject jstr;
    int i, n;
    
    trace("cArgs_of_jArgs(");
    n = (*env) -> GetArrayLength(env, jsa);
    n++;
    *a  = (char**) ce_malloc(sizeof(char*) * n);
    *len = n;
    (*a)[0] = "ensemble_Ce";
    
    for(i = 0; i < n-1; i++) {
	//	trace(".");
	jstr = (*env)->GetObjectArrayElement(env, jsa, i);
	//	trace(".");
	(*a)[i+1] = cString_of_jString(env, jstr);
    }
    trace(")");
}


ce_jops_t * 
jops_of_j(JNIEnv *env, jobject j_jops)
{
    ce_jops_t *jops;
    jops = record_create(ce_jops_t*, jops);
    record_clear(jops);

    /*
    jops->hrtbt_rate=10.0;
    jops->transports = ce_copy_string("UDP");
    jops->group_name = ce_copy_string("ce_mtalk");
    jops->properties = ce_copy_string(CE_DEFAULT_PROPERTIES);
    jops->use_properties = 1;
    */
    
//    trace("jops_of_j(");
//    trace("hrtbt_rate");
    jops -> hrtbt_rate = (float)
	(*env)->GetDoubleField(env, j_jops, jops_hrtbt_rate);
//    trace("transports[");
    jops -> transports = cString_of_jString(
	 env, (*env)->GetObjectField(env, j_jops, jops_transports));
//    trace("]");
//    trace("protocol[");
    jops -> protocol = cString_of_jString(env, (*env) -> GetObjectField(env, j_jops, jops_protocol));
//    trace("]");
//    trace("group_name");
    jops -> group_name = cString_of_jString(env, (*env) -> GetObjectField(env, j_jops, jops_group_name));
//    trace("properties");
    jops -> properties = cString_of_jString(
	env, (*env) -> GetObjectField(env, j_jops, jops_properties));
//    trace("use_properties");
    jops -> use_properties =
	(*env) -> GetIntField(env, j_jops, jops_use_properties);
//    trace("groupd");
    jops -> groupd = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_groupd) ;
//    trace("params");
    jops -> params = cString_of_jString(
	env, (*env) -> GetObjectField(env, j_jops, jops_params));
//    trace("client");
    jops -> client = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_client);
//    trace("debug");
    jops -> debug = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_debug);
//    trace("endpt");
    jops -> endpt = cString_of_jString(
	env, (*env) -> GetObjectField(env, j_jops, jops_endpt));
//    trace("princ");
    jops -> princ = cString_of_jString(
	env, (*env) -> GetObjectField(env, j_jops, jops_princ));
//    trace("secure");
    jops -> secure = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_secure);
//    trace(")");
    
    return jops;
}

jobject
jView_of_cView(JNIEnv *env, cej_env_t *cej_env, ce_local_state_t *ls, ce_view_state_t *vs)
{
  jobject jView;
  jstring jstr;
  
//  trace("jView_of_cView(");
  jView = (*env) -> AllocObject(env, glbl_View);

//  trace(".");
  jstr = jString_of_cString(env, vs->version);
  (*env) -> SetObjectField(env, jView, view_version, jstr);
//  trace(".");
  (*env) -> SetObjectField(env, jView, view_groupd,
			   jString_of_cString(env, vs->group));
//  trace(".");
  (*env) -> SetObjectField(env, jView, view_proto,
			   jString_of_cString(env, vs->proto));
//  trace(".");
  (*env) -> SetBooleanField(env, jView, view_coord,
			    (jboolean) vs->coord);
//  trace(".");
  (*env) -> SetIntField(env, jView, view_ltime,
			(jint) vs->ltime);
//  trace(".");
  (*env) -> SetBooleanField(env, jView, view_primary,
			    (jboolean) vs->primary);
//  trace(".");
  (*env) -> SetBooleanField(env, jView, view_groupd,
			    (jboolean) vs->groupd);
//  trace(".");
  (*env) -> SetBooleanField(env, jView, view_xfer_view,
			    (jboolean) vs->xfer_view);
//  trace(".");
  (*env) -> SetObjectField(env, jView, view_params,
			   jString_of_cString(env, vs->params));
//  trace(".");
  (*env) -> SetDoubleField(env, jView, view_uptime,
			   (jdouble)vs->uptime);
//  trace(".");
  (*env) -> SetObjectField(env, jView, view_view,
			   jStringArray_of_cStringArray(env, ls->nmembers, vs->view));
  (*env) -> SetObjectField(env, jView, view_address,
			   jStringArray_of_cStringArray(env, ls->nmembers, vs->address));
  (*env) -> SetObjectField(env, jView, view_endpt,
			   jString_of_cString(env, ls->endpt));
  (*env) -> SetObjectField(env, jView, view_addr,
			   jString_of_cString(env, ls->addr));
  (*env) -> SetIntField(env, jView, view_rank, (jint) ls->rank);
  (*env) -> SetObjectField(env, jView, view_name, jString_of_cString(env, ls->name));
  (*env) -> SetIntField(env, jView, view_nmembers, (jint) ls->nmembers);
  (*env) -> SetBooleanField(env, jView, view_am_coord, (jboolean) ls->am_coord);
  trace(")");

  return jView;
}

/**************************************************************/
cej_env_t*
create_env(JNIEnv *env, jobject j_group) 
{
  cej_env_t* cej_env;

//  trace("create_env");
  cej_env =  record_create(cej_env_t*, cej_env);
  cej_env->j_group = (*env) -> NewGlobalRef(env, j_group);
  
  return cej_env;
}

void
delete_env(JNIEnv *env, cej_env_t *cej_env)
{
    (*env) -> DeleteGlobalRef(env, cej_env->j_group);
    free(cej_env);
}

static void
init_cb(void)
{
    if (ens_env == NULL) {
	JavaVM *vm;
	jsize n;
	
	JNI_GetCreatedJavaVMs(&vm, 1, &n);
	(*vm)->AttachCurrentThread(vm, (void **)&ens_env, NULL);
    }
}

/**************************************************************/

static jfieldID
cej_GetFieldID(JNIEnv *env, jclass clazz, 
	       const char *name, const char *sig)
{
    jfieldID id;

    //    trace("GetFieldID <%s>", name);
    id = (*env) -> GetFieldID(env, clazz, name, sig);
    if (id == NULL)
	cej_panic2("could not get fieldID", name);
    return id;
}

static jobject
cej_NewGlobalRef(JNIEnv *env, jobject obj)
{
    jobject job = (*env) -> NewGlobalRef(env, obj);
    if (job == NULL)
	cej_panic("Could not get object reference");
    return job;
}

static jmethodID
cej_GetMethodID(JNIEnv *env, jclass clazz, 
	    const char *name, const char *sig)
{
    jmethodID mth = (*env) -> GetMethodID(env, clazz, name, sig);
    if (mth == NULL)
	cej_panic2("could not GetMethodID", name);
    return mth;
}

static void
check_java_exception(JNIEnv *env)
{
    jthrowable exn_obj = (*env) -> ExceptionOccurred(env);
    if (exn_obj) {
	(*env) -> ExceptionDescribe(env);
	(*env) -> ExceptionClear(env);
	exit(1);
    }
}
/**************************************************************/

void cej_install(void *e, ce_local_state_t *ls, ce_view_state_t *vs)
{
    jobject jView;
    cej_env_t *cej_env = (cej_env_t*)e;
    init_cb();
    
    trace("cej_install(");
    jView = jView_of_cView(ens_env, cej_env, ls, vs);
    
    ce_view_full_free(ls, vs);
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, install_cb , jView);
    check_java_exception(ens_env);
    trace(")");
}

void cej_exit(void *e) {
    cej_env_t *cej_env = (cej_env_t*)e;
    trace("cej_exit(");
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, exit_cb);
    check_java_exception(ens_env);
    delete_env(ens_env, cej_env);
    trace(")");
}

void cej_recv_cast(void *e, int origin, int len, char *msg)
{
    cej_env_t *cej_env = (cej_env_t*)e;
    trace("cej_recv_cast(");
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, recv_cast_cb,
	origin, jba_of_iovec(ens_env,len,msg));
    check_java_exception(ens_env);
    trace(")");
}

void cej_recv_send(void *e, int origin, int len, char *msg)
{
    cej_env_t *cej_env = (cej_env_t*)e;
    trace("cej_recv_send(");
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, recv_send_cb,
	origin, jba_of_iovec(ens_env,len,msg));
    check_java_exception(ens_env);
    trace(")");
}

void cej_flow_block(void *e, int rank, int onoff) {
    cej_env_t *cej_env = (cej_env_t*)e;
    trace("cej_flow_block(");
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, flow_block_cb, 
	(jint)rank, (jboolean) onoff);
    check_java_exception(ens_env);
    trace(")");
}

void cej_block(void *e) {
    cej_env_t *cej_env = (cej_env_t*)e;
    trace("cej_block(");
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, block_cb);
    check_java_exception(ens_env);
    trace(")");
}

void cej_heartbeat(void *e, double time) {
    cej_env_t *cej_env = (cej_env_t*)e;
    trace("cej_heartbeat(");
    (*ens_env)->CallVoidMethod(
	ens_env, cej_env->j_group, heartbeat_cb, 
	(jdouble) time);
    check_java_exception(ens_env);
    trace(")");
}  

/**************************************************************/
/* Exported functions
 */
JNIEXPORT void JNICALL Java_ensemble_Group_natInit
(JNIEnv *env, jclass clazz, jobjectArray args)
{
    if (!initialized_nat){
	printf("natInit: Initializing the Cejava library(\n");
	initialized_nat = 1;
	glbl_Group = cej_NewGlobalRef(env, 
				   (*env)->FindClass(env, "ensemble/Group"));
	glbl_View = cej_NewGlobalRef(env, 
				   (*env)->FindClass(env, "ensemble/View"));
	glbl_JoinOps = cej_NewGlobalRef(env, 
					(*env)->FindClass(env, "ensemble/JoinOps"));
	String = cej_NewGlobalRef(env, 
				  (*env)->FindClass(env, "java/lang/String"));
	
	// View
	view_version = cej_GetFieldID(env, glbl_View, "version",
				      "Ljava/lang/String;");
	view_proto = cej_GetFieldID(env, glbl_View, "proto", "Ljava/lang/String;"); 	
	view_coord = cej_GetFieldID(env, glbl_View, "coord", "I"); 	
	view_ltime = cej_GetFieldID(env, glbl_View, "ltime", "I"); 	
	view_primary = cej_GetFieldID(env, glbl_View, "primary", "Z"); 	
	view_groupd = cej_GetFieldID(env, glbl_View, "groupd", "Z"); 	
	view_xfer_view = cej_GetFieldID(env, glbl_View, "xfer_view", "Z");
	view_params = cej_GetFieldID(env, glbl_View, "params",  "Ljava/lang/String;"); 	
	view_uptime = cej_GetFieldID(env, glbl_View, "uptime", "D"); 	
	view_view = cej_GetFieldID(env, glbl_View, "view", "[Ljava/lang/String;");
	view_address = cej_GetFieldID(env, glbl_View, "address", "[Ljava/lang/String;");
	view_endpt = cej_GetFieldID(env, glbl_View, "endpt", "Ljava/lang/String;"); 	
	view_addr = cej_GetFieldID(env, glbl_View, "addr", "Ljava/lang/String;"); 	
	view_ltime = cej_GetFieldID(env, glbl_View, "ltime", "I"); 	
	view_rank = cej_GetFieldID(env, glbl_View, "rank", "I");
	view_name = cej_GetFieldID(env, glbl_View, "name", "Ljava/lang/String;");
	view_nmembers = cej_GetFieldID(env, glbl_View, "nmembers", "I");
	view_am_coord = cej_GetFieldID(env, glbl_View, "am_coord", "Z"); 
	
	// Join Options
	jops_hrtbt_rate = cej_GetFieldID(env, glbl_JoinOps, "hrtbt_rate", "D");
	jops_transports = cej_GetFieldID(env, glbl_JoinOps, "transports", "Ljava/lang/String;"); 	
	jops_protocol = cej_GetFieldID(env, glbl_JoinOps, "protocol", "Ljava/lang/String;"); 	
	jops_group_name = cej_GetFieldID(env, glbl_JoinOps, "group_name", "Ljava/lang/String;"); 	
	jops_properties = cej_GetFieldID(env, glbl_JoinOps, "properties",
					 "Ljava/lang/String;"); 	
	jops_use_properties = cej_GetFieldID(env, glbl_JoinOps, "use_properties","Z"); 	
	jops_groupd = cej_GetFieldID(env, glbl_JoinOps, "groupd", "Z");
	jops_params = cej_GetFieldID(env, glbl_JoinOps, "params", "Ljava/lang/String;"); 	
	jops_client = cej_GetFieldID(env, glbl_JoinOps, "client", "Z");	
	jops_debug = cej_GetFieldID(env, glbl_JoinOps, "debug", "Z"); 	
	jops_endpt = cej_GetFieldID(env, glbl_JoinOps, "endpt", "Ljava/lang/String;"); 	
	jops_princ = cej_GetFieldID(env, glbl_JoinOps, "princ",
				    "Ljava/lang/String;"); 	
	jops_secure = cej_GetFieldID(env, glbl_JoinOps, "secure", "Z");


	install_cb = cej_GetMethodID(env, glbl_Group, "install",
				     "(Lensemble/View;)V" /*"()V"*/);
	exit_cb = cej_GetMethodID(env, glbl_Group, "exit", "()V");
	recv_cast_cb = cej_GetMethodID(env, glbl_Group, "recv_cast", "(I[B)V");
	recv_send_cb = cej_GetMethodID(env, glbl_Group, "recv_send", "(I[B)V");
	flow_block_cb = cej_GetMethodID(env, glbl_Group, "flow_block", "(IZ)V");
	heartbeat_cb = cej_GetMethodID(env, glbl_Group, "heartbeat", "(D)V");
	block_cb = cej_GetMethodID(env, glbl_Group, "block", "()V");
	
	/* Initialize Ensemble
	 */
	{
	    char **argv;
	    int argc ;
	    cArgs_of_jArgs(env, args, &argc, &argv);
	    ce_Init(argc, argv);
	}
    }
}


JNIEXPORT jlong JNICALL Java_ensemble_Group_natJoin
(JNIEnv *env, jobject j_group, jobject j_jops)
{
    ce_jops_t *jops;
    cej_env_t *cej_env;
    ce_appl_intf_t *c_appl;

    trace("nat_Join[");
    jops = jops_of_j(env, j_jops);
    cej_env = create_env(env, j_group);
    
    trace("ce_create_flat_intf");
    c_appl = ce_create_flat_intf(
	cej_env,
	cej_exit,
	cej_install,
	cej_flow_block,
	cej_block,
	cej_recv_cast,
	cej_recv_send,
	cej_heartbeat
	);
    trace("ce_Join");
    ce_Join(jops, c_appl);
    cej_env->c_appl = c_appl ;
    trace("]");
    return (jlong)cej_env;
}

JNIEXPORT void JNICALL Java_ensemble_Group_natLeave
(JNIEnv *env, jclass Group, jlong group)
{
    trace("Leave(");
    ce_Leave(((cej_env_t*)(int)group)->c_appl);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natCast
(JNIEnv *env, jclass Group, jlong group, jbyteArray msg)
{
    int len;
    char *buf;
    trace("natCast(");
    iovec_of_jba(env, msg, &len, &buf);
    ce_flat_Cast(((cej_env_t*)(int)group)->c_appl, len, buf);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natSend
(JNIEnv *env, jclass Group, jlong group, jintArray j_dests, jbyteArray msg)
{
    int len;
    char *buf;
    int num_dests;
    int* dests;
    trace("natSend(");
    ia_of_jia(env, j_dests, &num_dests, &dests);
    iovec_of_jba(env, msg, &len, &buf);
    ce_flat_Send(((cej_env_t*)(int)group)->c_appl, num_dests, dests, len, buf);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natSend1
(JNIEnv *env, jclass Group, jlong group, jint dest, jbyteArray msg)
{
    int len;
    char *buf;
    cej_env_t *cej_env = (cej_env_t*)(int)group;
    trace("natSend1(");
    iovec_of_jba(env, msg, &len, &buf);
//    trace("natSend1: %d rank=%d", dest, cej_env->ls->rank);
    ce_flat_Send1(cej_env->c_appl, dest, len, buf);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natPrompt
(JNIEnv *env, jclass Group, jlong group)
{
    trace("natPrompt(");
    ce_Prompt(((cej_env_t*)(int)group)->c_appl);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natSuspect
(JNIEnv *env, jclass Group, jlong group, jintArray j_suspects)
{
    int num;
    int* suspects;
    trace("natSuspect(");
    ia_of_jia(env, j_suspects, &num, &suspects);
    ce_Suspect(((cej_env_t*)(int)group)->c_appl, num, suspects);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natXferDone
(JNIEnv *env, jclass Group, jlong group)
{
    ce_XferDone(((cej_env_t*)(int)group)->c_appl);
}

JNIEXPORT void JNICALL Java_ensemble_Group_natRekey
(JNIEnv *env, jclass Group, jlong group)
{
    trace("natXferDone(");
    ce_Rekey(((cej_env_t*)(int)group)->c_appl);
    trace(")");
}

JNIEXPORT void JNICALL Java_ensemble_Group_natChangeProtocol
(JNIEnv *env, jclass Group, jlong group, jstring j_protocol_name)
{
    char* proto = cString_of_jString (env, j_protocol_name);
    ce_ChangeProtocol(((cej_env_t*)(int)group)->c_appl, proto);
}

JNIEXPORT void JNICALL Java_ensemble_Group_natChangeProperties
(JNIEnv *env, jclass Group, jlong group, jstring j_properties)
{
    char* props = cString_of_jString(env, j_properties);
    ce_ChangeProperties(((cej_env_t*)(int)group)->c_appl, props);
}


