

#include "TSRM.h"
#include "php_main.h"
#include "ext/standard/info.h"
#include "zend_smart_str.h"

#undef TSRMLS_FETCH
#define TSRMLS_FETCH() void ***tsrm_ls = (void ***)ts_resource_ex(0, NULL)
typedef struct _php_interpreter_object interpreter_object;
ZEND_BEGIN_MODULE_GLOBALS(interpreter)
    interpreter_object *current_thread;
ZEND_END_MODULE_GLOBALS(interpreter)

struct _php_interpreter_object
{
    zend_object obj;

    void *context, *parent_context;

    char *disable_functions;
    char *disable_classes;
    zval *output_handler; /* points to function which lives in the parent_context */

    unsigned char bailed_out_in_eval; /* Patricide is an ugly thing.  Especially when it leaves bailout address mis-set */

    unsigned char active;         /* A bailout will set this to 0 */
    unsigned char parent_access;  /* May Sub_Interpreter_Parent be instantiated/used? */
    unsigned char parent_read;    /* May parent vars be read? */
    unsigned char parent_write;   /* May parent vars be written to? */
    unsigned char parent_eval;    /* May arbitrary code be run in the parent? */
    unsigned char parent_include; /* May arbitrary code be included in the parent? (includes require(), and *_once()) */
    unsigned char parent_echo;    /* May content be echoed from the parent scope? */
    unsigned char parent_call;    /* May functions in the parent scope be called? */
    unsigned char parent_die;     /* Are $PARENT->die() / $PARENT->exit() enabled? */
    unsigned long parent_scope;   /* 0 == Global, 1 == Active, 2 == Active->prior, 3 == Active->prior->prior, etc... */

    char *parent_scope_name; /* Combines with parent_scope to refer to a named array as a symbol table */
    int parent_scope_namelen;
};

#define INTERPRETER_G(v) TSRMG(interpreter_globals_id, zend_interpreter_globals *, v)
#define INTERPRETER_TSRMLS_C TSRMLS_C

/* TODO: It'd be nice if objects and resources could make it across... */
#define PHP_THREAD_CROSS_SCOPE_ZVAL_COPY_CTOR(pzv) \
{ \
	switch (Z_TYPE_P(pzv)) { \
		case IS_RESOURCE: \
		case IS_OBJECT: \
			php_error_docref(NULL TSRMLS_CC, E_WARNING, "Unable to translate resource, or object variable to current context."); \
			ZVAL_NULL(pzv); \
			break; \
		case IS_ARRAY: \
		{ \
			HashTable *original_hashtable = Z_ARRVAL_P(pzv); \
			array_init(pzv); \
			zend_hash_apply_with_arguments(INTERPRETER_53_TSRMLS_PARAM(original_hashtable), (apply_func_args_t)php_interpreter_array_deep_copy, 1, Z_ARRVAL_P(pzv) TSRMLS_CC); \
			break; \
		} \
		default: \
			zval_copy_ctor(pzv); \
	} \
	(pzv)->INTERPRETER_REFCOUNT = 1; \
	(pzv)->INTERPRETER_IS_REF = 0; \
}

#define PHP_INTERPRETER_FETCH(zval_p) (interpreter_object *)zend_objects_get_address(zval_p TSRMLS_CC)

ZEND_API zend_object *zend_objects_get_address(const zval *zobject TSRMLS_DC)
{
    return (zend_object *)zend_object_store_get_object(zobject TSRMLS_CC);
}

ZEND_API void *zend_object_store_get_object(const zval *zobject TSRMLS_DC)
{
    zend_object_handle handle = Z_OBJ_HANDLE_P(zobject);

    return EG(objects_store).object_buckets[handle].bucket.obj.object;
}

// #if PHP_VERSION_ID >= 80000
#define PHP_INTERPRETER_BEGIN(objval)                                     \
    {                                                                        \
        void *prior_context = tsrm_set_interpreter_context(objval->context); \
        TSRMLS_FETCH();

#define PHP_INTERPRETER_ABORT(objval)             \
    {                                                \
        tsrm_set_interpreter_context(prior_context); \
    }

#define PHP_INTERPRETER_END(objval)                                                             \
    PHP_INTERPRETER_ABORT(objval)                                                               \
    if (objval->bailed_out_in_eval)                                                                \
    {                                                                                              \
        /* We're actually in bailout mode, but the child's bailout address had to resolve first */ \
        zend_bailout();                                                                            \
    }                                                                                              \
    }
// #endif

/* {{{ php_interpreter_call_int */
inline static void php_interpreter_call_int(zval *func_name, char **pname, zval **pretval, zval *args, zval *return_value, void *prior_context TSRMLS_DC)
{
    HashPosition pos;
	int i;
	zval **tmpzval;
	int argc = zend_hash_num_elements(Z_ARRVAL_P(args));
	zval ***interpreter_args = safe_emalloc(sizeof(zval**), argc, 0);

	for(zend_hash_internal_pointer_reset_ex(Z_ARRVAL_P(args), &pos), i = 0;
		(zend_hash_get_current_data_ex(Z_ARRVAL_P(args), (void*)&tmpzval, &pos) == SUCCESS) && (i < argc);
		zend_hash_move_forward_ex(Z_ARRVAL_P(args), &pos), i++) {
		interpreter_args[i] = emalloc(sizeof(zval*));
		MAKE_STD_ZVAL(*interpreter_args[i]);
		**interpreter_args[i] = **tmpzval;
            PHP_INTERPRETER_SCOPE_ZVAL_COPY_CTOR(*interpreter_args[i]);
    }

	/* Shouldn't be necessary */
	argc = i;

	/* Note: If this function is disabled by disable_functions or disable_classes,
	 * The user will get a confusing error message about (null)() being disabled for security reasons on line 0
	 * This will be fixable with a properly set EG(function_state_ptr)....just not yet
	 */
	if (call_user_function_ex(EG(function_table), NULL, func_name, pretval, argc, interpreter_args, 0, NULL TSRMLS_CC) == SUCCESS) {
		if (*pretval) {
			*return_value = **pretval;
		} else {
			RETVAL_TRUE;
		}
	} else {
		php_error_docref1(NULL TSRMLS_CC, *pname, E_WARNING, "Unable to call function");
		RETVAL_FALSE;
	}
	if (*pname) {
		efree(*pname);
		*pname = NULL;
	}

	for(i = 0; i < argc; i++) {
		zval_ptr_dtor(interpreter_args[i]);
		efree(interpreter_args[i]);
	}
	efree(interpreter_args);
}

/* {{{ proto void Sub_Interpreter::__construct(array options)
 * Options: see php_interpreter_ini_override()
 */
PHP_METHOD(Sub_Interpreter, __construct)
{
    php_interpreter_object *objval = PHP_INTERPRETER_FETCH(this_ptr);
    zval *options = NULL;

    if (zend_parse_parameters(ZEND_NUM_ARGS() TSRMLS_CC, "|a", &options) == FAILURE)
    {
        RETURN_NULL();
    }

    objval->context = tsrm_new_interpreter_context();
    objval->disable_functions = NULL;
    objval->disable_classes = NULL;
    objval->output_handler = NULL;

    PHP_INTERPRETER_BEGIN(objval)
    objval->parent_context = prior_context;

    zend_alter_ini_entry("implicit_flush", sizeof("implicit_flush"), "1", 1, PHP_INI_SYSTEM, PHP_INI_STAGE_ACTIVATE);
    zend_alter_ini_entry("max_execution_time", sizeof("max_execution_time"), "0", 1, PHP_INI_SYSTEM, PHP_INI_STAGE_ACTIVATE);

    SG(headers_sent) = 1;
    SG(request_info).no_headers = 1;
    SG(options) = SAPI_OPTION_NO_CHDIR;
    INTERPRETER_G(current_thread) = objval; /* Needs to be set before RINIT */
    php_request_startup(TSRMLS_C);
    INTERPRETER_G(current_thread) = objval; /* But gets reset during RINIT -- Bad design on my part */
    PG(during_request_startup) = 0;
    PHP_INTERPRETER_END(objval)

    /* Prime the thread to be played in */
    objval->active = 1;

    RETURN_TRUE;
}
/* }}} */
/* {{{ proto Sub_Interpreter::__call(mixed function_name, array args)
    Call User Function */
PHP_METHOD(Sub_Interpreter, __call)
{
    zval *func_name, *args, *retval = NULL;
    php_interpreter_object *objval;
    int bailed_out = 0;

    if (zend_parse_parameters(ZEND_NUM_ARGS() TSRMLS_CC, "za", &func_name, &args) == FAILURE)
    {
        RETURN_NULL();
    }

    objval = PHP_INTERPRETER_FETCH(this_ptr);
    if (!objval->active)
    {
        php_error_docref(NULL TSRMLS_CC, E_WARNING, "Current thread is no longer active");
        RETURN_NULL();
    }

    PHP_INTERPRETER_BEGIN(objval)
    {
        char *name = NULL;

        zend_first_try
        {
            if (!INTERPRETER_IS_CALLABLE(func_name, IS_CALLABLE_CHECK_NO_ACCESS, &name))
            {
                php_error_docref1(NULL TSRMLS_CC, name, E_WARNING, "Function not defined");
                if (name)
                {
                    efree(name);
                }
                PHP_INTERPRETER_ABORT(objval)
                RETURN_FALSE;
            }

            php_interpreter_call_int(func_name, &name, &retval, args, return_value, prior_context TSRMLS_CC);
        }
        zend_catch
        {
            bailed_out = 1;
            objval->active = 0;
        }
        zend_end_try();
    }
    PHP_INTERPRETER_END(objval)

    if (bailed_out)
    {
        php_error_docref(NULL TSRMLS_CC, E_WARNING, "Failed calling thread function");
        RETURN_FALSE;
    }

    PHP_THREAD_CROSS_SCOPE_ZVAL_COPY_CTOR(return_value);

    if (retval)
    {
        PHP_INTERPRETER_BEGIN(objval)
        (void)(TSRMLS_C);
        zval_ptr_dtor(&retval);
        PHP_INTERPRETER_END(objval)
    }
}
/* }}} */

/* {{{ php_interpreter_include_or_eval
 */
static void php_interpreter_include_or_eval(INTERNAL_FUNCTION_PARAMETERS, int type, int once)
{
    php_interpreter_object *objval;
    zval *zcode;
    int bailed_out = 0;
    zval *retval = NULL;

    if (zend_parse_parameters(ZEND_NUM_ARGS() TSRMLS_CC, "z", &zcode) == FAILURE)
    {
        RETURN_FALSE;
    }

    convert_to_string(zcode);

    objval = PHP_INTERPRETER_FETCH(this_ptr);
    if (!objval->active)
    {
        php_error_docref(NULL TSRMLS_CC, E_WARNING, "Current thread is no longer active");
        RETURN_NULL();
    }

    RETVAL_NULL();

    PHP_INTERPRETER_BEGIN(objval)
    zend_first_try
    {
        zend_op_array *op_array = NULL;
        int already_included = 0;

        op_array = php_interpreter_include_or_eval_int(return_value, zcode, type, once, &already_included TSRMLS_CC);

        if (op_array)
        {
            EG(return_value_ptr_ptr) = &retval;
            EG(active_op_array) = op_array;

            zend_execute(op_array TSRMLS_CC);

            if (retval)
            {
                *return_value = *retval;
            }
            else
            {
                RETVAL_TRUE;
            }

            destroy_op_array(op_array TSRMLS_CC);
            efree(op_array);
        }
        else if ((type != ZEND_INCLUDE) && !already_included)
        {
            /* include can fail to parse peacefully,
             * require and eval should die on failure
             */
            objval->active = 0;
            bailed_out = 1;
        }
    }
    zend_catch
    {
        /* It's impossible to know what caused the failure, just deactive the thread now */
        objval->active = 0;
        bailed_out = 1;
    }
    zend_end_try();
    PHP_INTERPRETER_END(objval)

    if (bailed_out)
    {
        php_error_docref(NULL TSRMLS_CC, E_WARNING, "Error executing thread code");
        RETURN_FALSE;
    }

    PHP_THREAD_CROSS_SCOPE_ZVAL_COPY_CTOR(return_value);

    /* Don't confuse the memory manager */
    if (retval)
    {
        PHP_INTERPRETER_BEGIN(objval)
        (void)(TSRMLS_C);
        zval_ptr_dtor(&retval);
        PHP_INTERPRETER_END(objval)
    }
}
/* }}} */

/* {{{ proto void Sub_Interpreter::die(mixed message)
    MALIAS(exit)
    Terminate a thread instance */
PHP_METHOD(Sub_Interpreter, die)
{
    php_interpreter_object *objval;
    zval *message = NULL;

    if (zend_parse_parameters(ZEND_NUM_ARGS() TSRMLS_CC, "|z", &message) == FAILURE)
    {
        RETURN_FALSE;
    }

    RETVAL_NULL();

    if (message && Z_TYPE_P(message) != IS_LONG)
    {
        convert_to_string(message);
    }

    objval = PHP_INTERPRETER_FETCH(this_ptr);
    if (!objval->active)
    {
        php_error_docref(NULL TSRMLS_CC, E_WARNING, "Current thread is no longer active");
        return;
    }

    PHP_INTERPRETER_BEGIN(objval)
    zend_try {
        if (message)
        {
            if (Z_TYPE_P(message) == IS_LONG) {
                EG(exit_status) = Z_LVAL_P(message);
            } else {
                PHPWRITE(Z_STRVAL_P(message), Z_STRLEN_P(message));
            }
        }
        zend_bailout();
    } zend_catch {
        /* goes without saying doesn't it? */
        objval->active = 0;
    }
    zend_end_try();
    PHP_INTERPRETER_END(objval)
}
/* }}} */
