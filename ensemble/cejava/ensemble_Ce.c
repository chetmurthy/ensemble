/**************************************************************/
/*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
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
cString_of_jString_full(JNIEnv *env, jstring jstr)
{
    char *buf;
    int len;
    const char *cstr;

    if (jstr == NULL) return NULL;
    len = (*env) -> GetStringUTFLength(env, jstr);
    if (len == 0) return NULL;
    cstr = (*env)->GetStringUTFChars(env, jstr, NULL);
    buf = ce_malloc(len+1);
    strcpy(buf, cstr);
    buf[len] = 0;
    printf("buf=%s\n", buf); fflush(stdout);
    (*env)->ReleaseStringUTFChars(env, jstr, cstr);
    (*env)-> DeleteLocalRef(env, jstr);
    return buf;
}

static void
cString_of_jString(JNIEnv *env, jstring jstr, char *buf, int max_len, const char *error_string)
{
    int len;
    const char *cstr;

    memset(buf, 0, sizeof(max_len));
    if (jstr == NULL) return;
    len = (*env) -> GetStringUTFLength(env, jstr);
    if (len == 0) return;
    cstr = (*env)->GetStringUTFChars(env, jstr, NULL);
    if (strlen(cstr) > max_len -1)
	cej_panic(error_string);
    memcpy(buf, cstr, strlen(cstr));
    (*env)->ReleaseStringUTFChars(env, jstr, cstr);
    (*env)-> DeleteLocalRef(env, jstr);
}

/* Convert a C-iovector into a Java array.
 * JavaByteArray_of_iovec
 */
jbyteArray jba_of_iovec(JNIEnv *env, int len, char *data)
{
    jbyteArray ba;
    char *buf;
    
    if ((*env)->EnsureLocalCapacity(env, 2) < 0) {
	cej_panic("JVM: out of memory error");
    }
    ba = (*env)->NewByteArray(env, len);	
    if (ba == NULL)
	cej_panic("jba_of_iovec, JVM return NULL array");
    buf = (*env)->GetByteArrayElements(env, ba, NULL);
    memcpy(buf, data, len);
    (*env)->ReleaseByteArrayElements(env, ba, buf, 0);
    return ba;
}

/* Convert a Java-byte array into an iovec.
 */
void iovec_of_jba(JNIEnv *env, jbyteArray msg, int *len, char **data)
{
    jbyte *elements = (*env)->GetByteArrayElements(env, msg, NULL);
    int length = (*env)->GetArrayLength(env, msg);
    char *buf = (char*)malloc(length);
    
    memcpy(buf, elements, length);
    *data = buf;
    *len = length;
    (*env)->ReleaseByteArrayElements(env, msg, elements, JNI_ABORT);
    (*env)->DeleteLocalRef(env, msg);
}

/* Convert a Java int-array into a C-array
 */
static void
ia_of_jia(JNIEnv *env, jintArray jia, int *len, int *data, int max_num, const char *error_string)
{
    jint *elements = (*env)->GetIntArrayElements(env, jia, NULL);
    int length = (*env)->GetArrayLength(env, jia);
    int i;
    
    if (length > max_num) 
	cej_panic(error_string);
    for(i=0; i<length; i++)
	data[i] = elements[i];
    *len = length;
    (*env)->ReleaseIntArrayElements(env, jia, elements, JNI_ABORT);
}

static jstring
jString_of_cString(JNIEnv *env, char *s)
{
    return (*env)->NewStringUTF(env, s);
}

/* Convert a C endpoint array into a Java stringArray.
 */
static jobject
jStringArray_of_cEndptArray(JNIEnv *env, int n, ce_endpt_t *ea)
{
    jobject array, name;
    int i;
    
    array = (*env)->NewObjectArray(env, n, String, NULL);
    for(i = 0; i < n; i++) {
	name = (*env)->NewStringUTF(env, ea[i].name);
	(*env)->SetObjectArrayElement(env, array, i, name);
	(*env)->DeleteLocalRef(env,name);
    }
    return array;
}


/* Convert a C address array into a Java stringArray.
 */
static jobject
jStringArray_of_cAddrArray(JNIEnv *env, int n, ce_addr_t *aa)
{
    jobject array, name;
    int i;
    
    array = (*env)->NewObjectArray(env, n, String, NULL);
    for(i = 0; i < n; i++) {
	name = (*env)->NewStringUTF(env, aa[i].addr);
	(*env)->SetObjectArrayElement(env, array, i, name);
	(*env)->DeleteLocalRef(env,name);
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
	jstr = (*env)->GetObjectArrayElement(env, jsa, i);
	(*a)[i+1] = cString_of_jString_full(env, jstr);
    }
    trace(")");
}


void
jops_of_j(JNIEnv *env, jobject j_jops, /*OUT*/ ce_jops_t *jops)
{
    memset(jops, 0, sizeof(ce_jops_t));

    jops -> hrtbt_rate = (float)
	(*env)->GetDoubleField(env, j_jops, jops_hrtbt_rate);
    cString_of_jString(
	 env,
	 (*env)->GetObjectField(env, j_jops, jops_transports),
	 jops->transports,
	 CE_TRANSPORT_MAX_SIZE,
	 "Jops transport: field too long"
	);
    cString_of_jString(
	env,
	(*env) -> GetObjectField(env, j_jops, jops_protocol),
	jops->protocol,
	CE_PROTOCOL_MAX_SIZE,
	 "Jops protocol: field too long"
	);
    cString_of_jString(
	env,
	(*env) -> GetObjectField(env, j_jops, jops_group_name),
	jops->group_name,
	CE_GROUP_NAME_MAX_SIZE,
	 "Jops group_name: field too long"
	);
    cString_of_jString(
	env,
	(*env) -> GetObjectField(env, j_jops, jops_properties),
	jops->properties,
	CE_PROPERTIES_MAX_SIZE,
	"Jops properties: field too long"
	);
    jops->use_properties =
	(*env) -> GetIntField(env, j_jops, jops_use_properties);
    jops->groupd = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_groupd) ;
    cString_of_jString(
	env,
	(*env) -> GetObjectField(env, j_jops, jops_params),
	jops->params,
	CE_PARAMS_MAX_SIZE,
	"Jops parameters: field too long"
	);
    jops->client = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_client);
    jops->debug = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_debug);
    cString_of_jString(
	env,
	(*env) -> GetObjectField(env, j_jops, jops_endpt),
	jops->endpt.name,
	CE_ENDPT_MAX_SIZE,
	"Jops endpoint: field too long"
	);
    cString_of_jString(
	env,
	(*env) -> GetObjectField(env, j_jops, jops_princ),
	jops->princ,
	CE_PRINCIPAL_MAX_SIZE,
	"Jops principal: field too long"
	);
    jops->secure = (int)
	(*env) -> GetBooleanField(env, j_jops, jops_secure);
}

/**************************************************************/
cej_env_t*
create_env(JNIEnv *env, jobject j_group) 
{
    cej_env_t* cej_env;
    
//  trace("create_env");
    cej_env =  (cej_env_t*) ce_malloc(sizeof(cej_env_t));
    cej_env->j_group = (*env) -> NewGlobalRef(env, j_group);
    
    return cej_env;
}

void
delete_env(JNIEnv *env, cej_env_t *cej_env)
{
    trace("delete_env(");
    (*env) -> DeleteGlobalRef(env, cej_env->j_group);
    trace(".");
    free(cej_env);
    trace(")");
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
    jobject j_version, j_group, j_proto, j_params, j_view, j_address, j_endpt, j_addr, j_name;
    cej_env_t *cej_env = (cej_env_t*)e;
    init_cb();
    
    trace("cej_install(");
    
    j_version = /*NULL*/ jString_of_cString(ens_env, vs->version);
    j_group = /*NULL*/ jString_of_cString(ens_env, vs->group);
    j_proto = /*NULL*/ jString_of_cString(ens_env, vs->proto);
    j_params = /*NULL*/ jString_of_cString(ens_env, vs->params);
    j_view = /*NULL*/ jStringArray_of_cEndptArray(ens_env, ls->nmembers, vs->view);
    j_address = /*NULL*/ jStringArray_of_cAddrArray(ens_env, ls->nmembers, vs->address);
    j_endpt = /*NULL*/ jString_of_cString(ens_env, ls->endpt.name);
    j_addr = /*NULL*/ jString_of_cString(ens_env, ls->addr.addr);
    j_name = /*NULL*/ jString_of_cString(ens_env, ls->name);
    trace("/");
    
    (*ens_env)->CallVoidMethod(
			       ens_env, cej_env->j_group, install_cb,
			       j_version ,
			       j_group ,
			       j_proto,
			       (jboolean)vs->coord,
			       (jint) vs->ltime, 
			       (jboolean) vs->primary, 
			       (jboolean) vs->groupd, 
			       (jboolean) vs->xfer_view, 
			       j_params ,
			       (jdouble)vs->uptime, 
			       j_view ,
			       j_address ,
			       j_endpt,
			       j_addr,
			       (jint) ls->rank,
			       j_name ,
			       (jint) ls->nmembers, 
			       (jboolean) ls->am_coord
			       );

    (*ens_env)->DeleteLocalRef(ens_env, j_version);
    (*ens_env)->DeleteLocalRef(ens_env, j_group);
    (*ens_env)->DeleteLocalRef(ens_env, j_proto);
    (*ens_env)->DeleteLocalRef(ens_env, j_params);
    (*ens_env)->DeleteLocalRef(ens_env, j_view);
    (*ens_env)->DeleteLocalRef(ens_env, j_address);
    (*ens_env)->DeleteLocalRef(ens_env, j_endpt);
    (*ens_env)->DeleteLocalRef(ens_env, j_addr);
    (*ens_env)->DeleteLocalRef(ens_env, j_name);

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
					   "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;IIZZZLjava/lang/String;D[Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;IZ)V");
	
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
	    
	    ce_set_alloc_fun((mm_alloc_t)malloc);
	    ce_set_free_fun((mm_free_t)free);
	    cArgs_of_jArgs(env, args, &argc, &argv);
	    ce_Init(argc, argv);
	}
    }
}


JNIEXPORT jlong JNICALL Java_ensemble_Group_natJoin
(JNIEnv *env, jobject j_group, jobject j_jops)
{
    ce_jops_t jops;
    cej_env_t *cej_env;
    ce_appl_intf_t *c_appl;

    trace("natJoin(");
    jops_of_j(env, j_jops, &jops);
    cej_env = create_env(env, j_group);
    
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
    ce_Join(&jops, c_appl);
    cej_env->c_appl = c_appl ;
    trace(")");
    return (jlong)(int)cej_env;
}

JNIEXPORT void JNICALL Java_ensemble_Group_natLeave
(JNIEnv *env, jclass Group, jlong group)
{
    trace("natLeave(");
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
    int dests[CE_DESTS_MAX_SIZE];

    trace("natSend(");
    ia_of_jia(env, j_dests, &num_dests, dests, CE_DESTS_MAX_SIZE,
	      "natSend: too many destinations");
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
    int suspects[CE_DESTS_MAX_SIZE];

    trace("natSuspect(");
    ia_of_jia(env, j_suspects, &num, suspects, CE_DESTS_MAX_SIZE,
	      "natSuspect: too many suspicions");
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
(JNIEnv *env, jclass Group, jlong group, jstring j_protocol)
{
    char* proto = (char*) (*env)->GetStringUTFChars(env, j_protocol, NULL);
    ce_ChangeProtocol(((cej_env_t*)(int)group)->c_appl, proto);
}

JNIEXPORT void JNICALL Java_ensemble_Group_natChangeProperties
(JNIEnv *env, jclass Group, jlong group, jstring j_properties)
{
    char* props = (char*) (*env)->GetStringUTFChars(env, j_properties, NULL);
    ce_ChangeProperties(((cej_env_t*)(int)group)->c_appl, props);
}


