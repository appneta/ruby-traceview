/**
 * @file oboe.h
 * 
 * API header for Traceview's Oboe application tracing library for use with TraceView.
 *
 * @package             Oboe
 * @author              Traceview
 * @copyright           Copyright (c) 2016, SolarWinds LLC
 * @license             
 * @link                https://traceview.solarwinds.com
 **/

#ifndef LIBOBOE_H
#define LIBOBOE_H


#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <inttypes.h>
#if defined _WIN32
    #include <unistd.h> // On Windows ssize_t definition was put in this header.
#endif
#include "bson/bson.h"
#include "oboe_debug.h"

/** Compile time debug logging detail level - cannot log more detailed than this. */
#define OBOE_DEBUG_LEVEL OBOE_DEBUG_HIGH

/** Limit for number of messages at specified level before demoting to debug MEDIUM. */
#define MAX_DEBUG_MSG_COUNT 1

/**
 * Default configuration settings update interval in seconds.
 *
 * Borrowed from the Tracelyzer's oboe.h.
 */
#define OBOE_DEFAULT_SETTINGS_INTERVAL 30

/**
 * Default interval to check for timed out settings records in seconds
 */
#define OBOE_DEFAULT_TIMEOUT_CHECK_INTERVAL 10

/**
 * Default heartbeat status update interval in seconds.
 */
#define OBOE_DEFAULT_HEARTBEAT_INTERVAL 60

/**
 * Default throughput metrics update interval in seconds
 */
#define OBOE_DEFAULT_COUNTER_INTERVAL_SEC 30

/**
 * Default keepalive interval in seconds.
 *
 * A keepalive message will be sent after communications are idle for this interval.
 */
#define OBOE_DEFAULT_KEEPALIVE_INTERVAL 20

#define OBOE_SAMPLE_RESOLUTION 1000000

#define OBOE_MAX_TASK_ID_LEN 20
#define OBOE_MAX_OP_ID_LEN 8
#define OBOE_MAX_METADATA_PACK_LEN 512

#define XTR_CURRENT_VERSION 1
#define XTR_UDP_PORT 7831

#define OBOE_REPORTER_PROTOCOL_FILE "file"
#define OBOE_REPORTER_PROTOCOL_UDP "udp"
#define OBOE_REPORTER_PROTOCOL_SSL "ssl"
#define OBOE_REPORTER_PROTOCOL_DEFAULT OBOE_REPORTER_PROTOCOL_UDP

/** Maximum reasonable length of an arguments string for configuring a reporter. */
#define OBOE_REPORTER_ARGS_SIZE 4000

#ifdef _WIN32
/// SRv1 bitwise value mask for the RUM_ENABLE flag.
#define SETTINGS_RUM_ENABLE_MASK 0x00000001
#endif

#ifndef HOST_NAME_MAX
#define HOST_NAME_MAX 256
#endif

// structs

typedef struct oboe_ids {
    uint8_t task_id[OBOE_MAX_TASK_ID_LEN];
    uint8_t op_id[OBOE_MAX_OP_ID_LEN];
} oboe_ids_t;

typedef struct oboe_metadata {
    oboe_ids_t  ids;
    size_t      task_len;
    size_t      op_len;
#ifdef _FUTURE_PLANS_
    /* Can't add this without breaking the ABI, but someday... */
    int         auto_delete;
#endif /* _FUTURE_PLANS_ */
} oboe_metadata_t;

typedef struct oboe_event {
    oboe_metadata_t metadata;
    bson_buffer     bbuf;
    char *          bb_str;
#ifdef _FUTURE_PLANS_
    /* Can't add this without breaking the ABI, but someday... */
    int             auto_delete;
#endif /* _FUTURE_PLANS_ */
} oboe_event_t;


// oboe_metadata

#ifdef _FUTURE_PLANS_
oboe_metadata_t *oboe_metadata_new();
#endif /* _FUTURE_PLANS_ */
int oboe_metadata_init      (oboe_metadata_t *);
int oboe_metadata_destroy   (oboe_metadata_t *);

int oboe_metadata_is_valid   (const oboe_metadata_t *);

void oboe_metadata_copy     (oboe_metadata_t *, const oboe_metadata_t *);

void oboe_metadata_random   (oboe_metadata_t *);

int oboe_metadata_set_lengths   (oboe_metadata_t *, size_t, size_t);
int oboe_metadata_create_event  (const oboe_metadata_t *, oboe_event_t *);

int oboe_metadata_tostr     (const oboe_metadata_t *, char *, size_t);
int oboe_metadata_fromstr   (oboe_metadata_t *, const char *, size_t);


// oboe_event

#ifdef _FUTURE_PLANS_
oboe_event_t *oboe_event_new(const oboe_metadata_t *);
#endif /* _FUTURE_PLANS_ */
int oboe_event_init     (oboe_event_t *, const oboe_metadata_t *);
int oboe_event_destroy  (oboe_event_t *);

int oboe_event_add_info (oboe_event_t *, const char *, const char *);
int oboe_event_add_info_binary (oboe_event_t *, const char *, const char *, size_t);
int oboe_event_add_info_int64 (oboe_event_t *, const char *, const int64_t);
int oboe_event_add_info_double (oboe_event_t *, const char *, const double);
int oboe_event_add_info_bool (oboe_event_t *, const char *, const int);
int oboe_event_add_info_fmt (oboe_event_t *, const char *key, const char *fmt, ...);
int oboe_event_add_info_bson (oboe_event_t *, const char *key, const bson *val);
int oboe_event_add_edge (oboe_event_t *, const oboe_metadata_t *);
int oboe_event_add_edge_fromstr(oboe_event_t *, const char *, size_t);

/**
 * Send event message using the default reporter.
 *
 * @param channel the channel to send out this message (OBOE_SEND_EVENT or OBOE_SEND_INIT)
 * @param evt The event message.
 * @param md The X-Trace metadata.
 * @return Length of message sent in bytes on success; otherwise -1.
 */
int oboe_event_send(int channel, oboe_event_t *evt, oboe_metadata_t *md);


// oboe_context

oboe_metadata_t *oboe_context_get();
void oboe_context_set(oboe_metadata_t *);
int oboe_context_set_fromstr(const char *, size_t);

void oboe_context_clear();

int oboe_context_is_valid();


// oboe_reporter

struct oboe_reporter;

/* TODO: Move struct oboe_reporter to private header. */
typedef ssize_t (*reporter_send)(void *, int, const char *, size_t);
typedef int (*reporter_send_span)(void *, const char *, int64_t, const char *);
typedef int (*reporter_destroy)(void *);
typedef struct oboe_reporter {
    void *              descriptor;     /*!< Reporter's context. */
    reporter_send       send;           /*!< Send a trace event message. */
    reporter_send_span  sendSpan;
    reporter_destroy    destroy;        /*!< Destroy the reporter - release all resources. */
} oboe_reporter_t;

int oboe_reporter_udp_init  (oboe_reporter_t *, const char *, const char *);    /* DEPRECATE - Use oboe_init_reporter() */
int oboe_reporter_udp_init_str(oboe_reporter_t *, const char *);    /* DEPRECATE - Use oboe_init_reporter() */
int oboe_reporter_file_init (oboe_reporter_t *, const char *);      /* DEPRECATE - Use oboe_init_reporter() */
int oboe_reporter_file_init_str(oboe_reporter_t *, const char *);   /* DEPRECATE - Use oboe_init_reporter() */
int oboe_reporter_ssl_init (oboe_reporter_t *, const char *);       /* DEPRECATE - Use oboe_init_reporter() */


/**
 * Initialize a reporter structure for use with the specified protocol.
 *
 * @param rep Pointer to an uninitialized reporter structure.
 * @param protocol One of  OBOE_REPORTER_PROTOCOL_FILE, OBOE_REPORTER_PROTOCOL_UDP,
 *      or OBOE_REPORTER_PROTOCOL_SSL.
 * @param args A configuration string for the specified protocol (protocol dependent syntax).
 * @return Zero on success; otherwise -1.
 */
int oboe_reporter_init (oboe_reporter_t *rep, const char *protocol, const char *args);  /* DEPRECATE - Use oboe_init_reporter() */

/**
 * Check if the reporter is ready to send.
 *
 * The concept of 'ready' is depends on the specific reporter being used.
 *
 * @param rep The reporter context (optional).
 * @return Non-zero if the reporter is ready to send.
 */
int oboe_reporter_is_ready(oboe_reporter_t *rep);   /* DEPRECATE: Use oboe_is_ready() */

/**
 * Release any resources held by the reporter context.
 *
 * @param rep Pointer to a reporter context structure.
 * @return Zero on success; otherwise non-zero to indicate an error.
 */
int oboe_reporter_destroy(oboe_reporter_t *rep);    /* DEPRECATE: Use oboe_shutdown() */

/**
 * Disconnect or shut down the Oboe reporter, but allow it to be reconnected.
 *
 * @param rep Pointer to the active reporter object.
 */
void oboe_disconnect(oboe_reporter_t *rep); /* DEPRECATE: Use oboe_reporter_disconnect() */

/**
 * Reconnect or restart the Oboe reporter.
 *
 * @param rep Pointer to the active reporter object.
 */
void oboe_reconnect(oboe_reporter_t *rep);  /* DEPRECATE: Use oboe_reporter_reconnect() */

ssize_t oboe_reporter_udp_send(void *desc, const char *data, size_t len);   /* DEPRECATE - Use oboe_event_send() */


/* Oboe initialization and reporter management */

/**
 * Initialize the Oboe subsystems.
 *
 * This should be called before any other oboe_* functions.  However, in order
 * to make the library easier to work with, checks are in place so that it
 * will be called by any of the other functions that depend on it.
 *
 * Besides initializing the oboe library, this will also initialize a
 * reporter based on the values of environment variables, configuration
 * file options, and whether a tracelyzer is installed.
 *
 * @param access_key  Client access key
 * @return true if initialization succeeded, false otherwise
 */
int oboe_init(const char *access_key);

/**
 * Initialize the Oboe subsytems using a specific reporter configuration.
 *
 * This should be called before any other oboe_* functions butm may also be
 * used to change or re-initialize the current reporter.  To reconnect the 
 * reporter use oboe_disconnect() and oboe_reconnect() instead.
 *
 * @param protocol One of  OBOE_REPORTER_PROTOCOL_FILE, OBOE_REPORTER_PROTOCOL_UDP,
 *      or OBOE_REPORTER_PROTOCOL_SSL.
 * @param args A configuration string for the specified protocol (protocol dependent syntax).
 * @return Zero on success; otherwise an error code.
 */
int oboe_init_reporter(const char *protocol, const char *args);

/**
 * Disconnect or shut down the Oboe reporter, but allow it to be reconnect()ed.
 */
void oboe_reporter_disconnect();    /* TODO: Need implementation. */

/**
 * Reconnect or restart the Oboe reporter.
 */
void oboe_reporter_reconnect();     /* TODO: Need implementation. */

/**
 * Check if the Oboe is ready to send.
 *
 * The concept of 'ready' is depends on the specific reporter being used.
 *
 * @return Non-zero if the reporter is ready to send.
 */
int oboe_is_ready();    /* TODO: Need implementation. */

/**
 * Send a raw message using the current reporter.
 *
 * Use oboe_event_send() unless you are handling all the details of constructing
 * the messages for a valid trace.
 *
 * @param channel the channel to send out this message (OBOE_SEND_EVENT or OBOE_SEND_INIT)
 * @param data A BSON-encoded event message.
 * @param len The length of the message data in bytes.
 * @return Length of message sent in bytes on success; otherwise -1.
 */
int oboe_raw_send(int channel, const char *data, size_t len);

/**
 * Shut down the Oboe subsystems.
 *
 * This may be called on exit in order to release any resources held by
 * the Oboe library including any child threads.
 */
void oboe_shutdown();


// Settings interface

#define OBOE_SETTINGS_VERSION 1
#define OBOE_SETTINGS_MAGIC_NUMBER 0x6f626f65
#define OBOE_SETTINGS_TYPE_SKIP 0
#define OBOE_SETTINGS_TYPE_STOP 1
#define OBOE_SETTINGS_TYPE_DEFAULT_SAMPLE_RATE 2
#define OBOE_SETTINGS_TYPE_LAYER_SAMPLE_RATE 3
#define OBOE_SETTINGS_TYPE_LAYER_APP_SAMPLE_RATE 4
#define OBOE_SETTINGS_TYPE_LAYER_HTTPHOST_SAMPLE_RATE 5
#define OBOE_SETTINGS_TYPE_CONFIG_STRING 6
#define OBOE_SETTINGS_TYPE_CONFIG_INT 7
#define OBOE_SETTINGS_FLAG_OK             0x0
#define OBOE_SETTINGS_FLAG_INVALID        0x1
#define OBOE_SETTINGS_FLAG_OVERRIDE       0x2
#define OBOE_SETTINGS_FLAG_SAMPLE_START   0x4
#define OBOE_SETTINGS_FLAG_SAMPLE_THROUGH 0x8
#define OBOE_SETTINGS_FLAG_SAMPLE_THROUGH_ALWAYS 0x10
#define OBOE_SETTINGS_FLAG_SAMPLE_AVW_ALWAYS     0x20
#define OBOE_SETTINGS_FLAG_SAMPLE_BUCKET_ENABLED 0x40
#define OBOE_SETTINGS_MAX_STRLEN 256

#define OBOE_SETTINGS_UNSET -1
#define OBOE_SETTINGS_MIN_REFRESH_INTERVAL 30

// Value for "SampleSource" info key
// where was the sample rate specified? (oboe settings, config file, hard-coded default, etc)
#define OBOE_SAMPLE_RATE_SOURCE_FILE 1
#define OBOE_SAMPLE_RATE_SOURCE_DEFAULT 2
#define OBOE_SAMPLE_RATE_SOURCE_OBOE 3
#define OBOE_SAMPLE_RATE_SOURCE_LAST_OBOE 4
#define OBOE_SAMPLE_RATE_SOURCE_DEFAULT_MISCONFIGURED 5
#define OBOE_SAMPLE_RATE_SOURCE_OBOE_DEFAULT 6 

#define OBOE_SAMPLE_RESOLUTION 1000000

// Used to convert to settings flags:
#define OBOE_TRACE_NEVER   0
#define OBOE_TRACE_ALWAYS  1
#define OBOE_TRACE_THROUGH 2

#if defined _WIN32
    #pragma pack(push, 1)
#endif

#define TOKEN_BUCKET_CAPACITY_DEFAULT 16               // bucket capacity (how many tokens fit into the bucket)
#define TOKEN_BUCKET_RATE_PER_SECOND_DEFAULT 8         // rate per second (number of tokens per second)

#define OBOE_SEND_EVENT 0
#define OBOE_SEND_STATUS 1

typedef struct {
    uint32_t magic;
    uint32_t timestamp;
    uint16_t type;
    uint16_t flags;
    uint32_t value;
    uint32_t ttl;
    uint32_t _pad;
    char layer[OBOE_SETTINGS_MAX_STRLEN];
    double bucket_capacity;
    double bucket_rate_per_sec;
} oboe_settings_t;

typedef struct {
    float available;
    double capacity;
    double rate_per_usec; // time is usecs from gettimeofday
    struct timeval last_check;
} token_bucket_t;


typedef struct {
    char name[OBOE_SETTINGS_MAX_STRLEN];
    token_bucket_t bucket;
    volatile uint32_t request_count;            // all the requests that came through this layer
    volatile uint32_t exhaustion_count;         // # of times the token bucket limiting caused a trace to not occur
    volatile uint32_t trace_count;              // # of traces that were sent (includes "always", "through", or "AVW" traces)
    volatile uint32_t sample_count;             // # of traces that caused a random coin-flip (not "through" traces)
    volatile uint32_t through_count;            // # of through traces
    volatile uint32_t through_ignored_count;    // # of new requests, that are rejected due to start_always_flag == 0
                                                // that have through_always_flag == 1
    volatile uint32_t avw_count;                // # of AppView Web (AVW) traces
    volatile uint32_t last_used_sample_rate;
    volatile uint32_t last_used_sample_source;
} entry_layer_t;

// Current settings configuration:
typedef struct {
    int tracing_mode;          // loaded from config file
    int sample_rate;           // loaded from config file
    int default_sample_rate;   // default sample rate (fallback)
//    oboe_reporter_t *reporter; // the initialized event reporter
    oboe_settings_t *settings; // cached settings, updated by tracelyzer (init to NULL)
    int last_auto_sample_rate; // stores last known automatic sampling rate 
    uint16_t last_auto_flags;  // stores last known flags associated with above 
    uint32_t last_auto_timestamp; // timestamp from last *settings lookup
    uint32_t last_refresh;        // last refresh time
    entry_layer_t *entry_layer;
} oboe_settings_cfg_t;

int oboe_settings_init_local();
oboe_settings_t* oboe_settings_get(uint16_t type, const char* layer, const char* arg);
oboe_settings_t* oboe_settings_get_layer_tracing_mode(const char* layer);
oboe_settings_t* oboe_settings_get_layer_sample_rate(const char* layer);
uint32_t oboe_settings_get_latest_timestamp(const char* layer);
int oboe_settings_get_value(oboe_settings_t *s, int *outval, unsigned short *outflags, uint32_t *outtimestamp);
entry_layer_t* oboe_settings_entry_layer_get(const char* name);

oboe_settings_cfg_t* oboe_settings_cfg_get();
void oboe_settings_cfg_set(oboe_settings_cfg_t*);
void oboe_settings_cfg_init(oboe_settings_cfg_t *cfg);

void oboe_settings_cfg_tracing_mode_set(int new_mode);
void oboe_settings_cfg_sample_rate_set(int new_rate);

int oboe_rand_get_value();

/**
 * Convert a tracing mode to a printable string.
 */
const char *oboe_tracing_mode_to_string(int tracing_mode);

/**
 * Check if sampling is enabled.
 *
 * @param cfg Optional pointer to the settings configuration for the current
 *          thread, as an optimization to avoid retrieving it.  May be NULL.
 * @return Non-zero if sampling is now enabled.
 */
int oboe_sample_is_enabled(oboe_settings_cfg_t *cfg);

/**
 * Check if this request should be sampled.
 *
 * Checks for sample rate flags and settings for the specified layer, considers
 * the current tracing mode and any special features in the X-Trace and
 * X-TV-Meta HTTP headers, and, if appropriate, rolls the virtual dice to
 * decide if this request should be sampled.
 *
 * This is designed to be called once per layer per request.
 *
 * This replaces oboe_sample_request with a version that uses the settings
 * configuration kept in thread-local storage and takes the X-TV-Meta HTTP
 * header value in order to support AppView Web integration.
 *
 * @param layer Layer name as used in oboe_settings_t.layer (may be NULL to use default settings)
 * @param xtrace X-Trace ID string from an HTTP request or higher layer (NULL or empty string if not present).
 * @param tv_meta AppView Web ID from X-TV-Meta HTTP header or higher layer (NULL or empty string if not present).
 * @param sample_rate_out The sample rate used to check if this request should be sampled
 *          (output - may be zero if not used).
 * @param sample_source_out The OBOE_SAMPLE_RATE_SOURCE used to check if this request
 *          should be sampled (output - may be zero if not used).
 * @return Non-zero if the given layer should be sampled.
 */
int oboe_sample_layer(
    const char *layer,
    const char *xtrace,
    const char *tv_meta,
    int *sample_rate_out,
    int *sample_source_out
);

/* Oboe configuration interface. */

/**
 * Check if the Oboe library is compatible with a given version.revision.
 *
 * This will succeed if the library is at least as recent as specified and if no
 * definitions have been removed since that revision.
 *
 * @param version The library's version number which increments every time the API changes.
 * @param revision The revision of the current version of the library.
 * @return Non-zero if the Oboe library is considered compatible with the specified revision.
 */
extern int oboe_config_check_version(int version, int revision);

/**
 * Get the Oboe library version number.
 *
 * This number increments whenever the API is changed.
 *
 * @return The library's version number or -1 if the version is not known.
 */
extern int oboe_config_get_version();

/**
 * Prototype for a logger call-back function.
 *
 * A logging function of this form can be added to the logger chain using
 * oboe_debug_log_add().
 *
 * @param context The context pointer that was registered in the call to
 *          oboe_debug_log_add().  Use it to pass the pointer-to-self for
 *          objects (ie. "this" in C++) or just a structure in C,  May be
 *          NULL.
 * @param module The module identifier as passed to oboe_debug_logger().
 * @param level The diagnostic detail level as passed to oboe_debug_logger().
 * @param source_name Name of the source file as passed to oboe_debug_logger().
 * @param source_lineno Number of the line in the source file where message is
 *          logged from as passed to oboe_debug_logger().
 * @param msg The formatted message produced from the format string and its
 *          arguments as passed to oboe_debug_logger().
 */
typedef void (*OboeDebugLoggerFcn)(void *context, int module, int level, const char *source_name, int source_lineno, const char *msg);

/**
 * Get a printable name for a diagnostics logging level.
 */
extern const char *oboe_debug_log_level_name(int level);

/**
 * Get a printable name for a diagnostics logging module identifier.
 */
extern const char *oboe_debug_module_name(int module);

/**
 * Get the maximum logging detail level for a module or for all modules.
 *
 * This level applies to the stderr logger only.  Added loggers get all messages
 * below their registed detail level and need to do their own module-specific
 * filtering.
 *
 * @param module One of the OBOE_MODULE_* values.  Use OBOE_MODULE_ALL (-1) to
 *          get the overall maximum detail level.
 * @return Maximum detail level value for module (or overall) where zero is the
 *          lowest and higher values generate more detailed log messages.
 */
extern int oboe_debug_log_level_get(int module);

/**
 * Set the maximum logging detail level for a module or for all modules.
 *
 * This level applies to the stderr logger only.  Added loggers get all messages
 * below their registered detail level and need to do their own module-specific
 * filtering.
 *
 * @param module One of the OBOE_MODULE_* values.  Use OBOE_MODULE_ALL to set
 *          the overall maximum detail level.
 * @param newLevel Maximum detail level value where zero is the lowest and higher
 *          values generate more detailed log messages.
 */
extern void oboe_debug_log_level_set(int module, int newLevel);

/**
 * Set the output stream for the default logger.
 *
 * @param newStream A valid, open FILE* stream or NULL to disable the default logger.
 * @return Zero on success; otherwise an error code (normally from errno).
 */
extern int oboe_debug_log_to_stream(FILE *newStream);

/**
 * If we're logging to a stream, flush it.
 *
 * @return Zero on success; otherwise an error code (normally from errno).
 */
extern int oboe_debug_log_flush();

/**
 * Set the default logger to write to the specified file.
 *
 * A NULL or empty path name will disable the default logger.
 *
 * If the file exists then it will be opened in append mode.
 *
 * @param pathname The path name of the
 * @return Zero on success; otherwise an error code (normally from errno).
 */
extern int oboe_debug_log_to_file(const char *pathname);

/**
 * Add a logger that takes messages up to a given logging detail level.
 *
 * This adds the logger to a chain in order of the logging level.  Log messages
 * are passed to each logger down the chain until the remaining loggers only
 * accept messages of a lower detail level.
 *
 * @return Zero on success, one if re-registered with the new logging level, and
 *          otherwise a negative value to indicate an error.
 */
extern int oboe_debug_log_add(OboeDebugLoggerFcn newLogger, void *context, int logLevel);

/**
 * Remove a logger.
 *
 * Remove the logger from the message handling chain.
 *
 * @return Zero on success, one if it was not found, and otherwise a negative
 *          value to indicate an error.
 */
extern int oboe_debug_log_remove(OboeDebugLoggerFcn oldLogger, void *context);

/*
 * Log the application's Oboe configuration.
 *
 * We use this to get a reasonable standard format between apps.
 *
 * @param module An OBOE_MODULE_* module identifier.  Use zero for undefined.
 * @param app_name Either NULL or a pointer to a string containing a name for 
 *          the application - will prefix the log entry.  Useful when multiple 
 *          apps log to the same destination. 
 * @param trace_mode A string identifying the configured tracing mode, one of:
 *          "never", "always", "never", "unset", or "undef" (for invalid values)
 *          Use the oboe_tracing_mode_to_string() function to convert from
 *          numeric values.
 * @param sample_rate The configured sampling rate: -1 for unset or a
 *          integer fraction of 1000000.
 * @param reporter_type String identifying the type of reporter configured: 
 *          One of 'udp' (the default), 'ssl', or 'file'.
 * @param reporter_args The string of comma-separated key=value settings
 *          used to initialize the reporter.
 * @param extra: Either NULL or a pointer to a string to be appended to
 *          the log message and designed to include a few other 
 *          configuration parameters of interest.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_INFO
# define OBOE_DEBUG_LOG_CONFIG(module, app_name, trace_mode, sample_rate, reporter_type, reporter_args, extra) \
  {                                                                                 \
    oboe_debug_logger(module, OBOE_DEBUG_INFO, __FILE__, __LINE__,                  \
        "%s Oboe config: tracing=%s, sampling=%d, reporter=('%s', '%s') %s",        \
        (app_name == NULL ? "" : app_name),                                         \
        trace_mode,                                                                 \
        sample_rate,                                                                \
        (reporter_type == NULL ? "?" : reporter_type),                              \
        (reporter_args == NULL ? "?" : reporter_args),                              \
        (extra == NULL ? "" : extra));                                              \
  }
#else
# define OBOE_DEBUG_LOG_CONFIG(module, app_name, trace_mode, sample_rate, reporter_type, reporter_args, extra) {}
#endif

/**
 * Log a fatal error.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_FATAL
# define OBOE_DEBUG_LOG_FATAL(module, ...)                   \
  {                                                          \
    oboe_debug_logger(module, OBOE_DEBUG_FATAL, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_FATAL(module, format_string, ...) {}
#endif

/**
 * Log a recoverable error.
 *
 * Each message is limited in the number of times that it will be reported at the 
 * ERROR level after which it will be logged at the debug MEDIUM level.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_ERROR
# define OBOE_DEBUG_LOG_ERROR(module, ...)                   \
  {                                                          \
    static int usage_counter = 0;                            \
    int loglev = (++usage_counter <= MAX_DEBUG_MSG_COUNT ? OBOE_DEBUG_ERROR : OBOE_DEBUG_MEDIUM); \
    oboe_debug_logger(module, loglev, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_ERROR(module, format_string, ...) {}
#endif

/**
 * Log a warning.
 *
 * Each message is limited in the number of times that it will be reported at the 
 * WARNING level after which it will be logged at the debug MEDIUM level.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_WARNING
# define OBOE_DEBUG_LOG_WARNING(module, ...)                 \
  {                                                          \
    static int usage_counter = 0;                            \
    int loglev = (++usage_counter <= MAX_DEBUG_MSG_COUNT ? OBOE_DEBUG_WARNING : OBOE_DEBUG_MEDIUM); \
    oboe_debug_logger(module, loglev, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_WARNING(module, format_string,...) {}
#endif

/**
 * Log an informative message.
 *
 * Each message is limited in the number of times that it will be reported at the 
 * INFO level after which it will be logged at the debug MEDIUM level.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_INFO
# define OBOE_DEBUG_LOG_INFO(module, ...)                    \
  {                                                                     \
    static int usage_counter = 0;                            \
    int loglev = (++usage_counter <= MAX_DEBUG_MSG_COUNT ? OBOE_DEBUG_INFO : OBOE_DEBUG_MEDIUM); \
    oboe_debug_logger(module, loglev, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_INFO(module, format_string, ...) {}
#endif

/**
 * Log a low-detail diagnostic message.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_LOW
# define OBOE_DEBUG_LOG_LOW(module, ...)                    \
  {                                                                     \
    oboe_debug_logger(module, OBOE_DEBUG_LOW, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_LOW(module, format_string, ...) {}
#endif

/**
 * Log a medium-detail diagnostic message.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_MEDIUM
# define OBOE_DEBUG_LOG_MEDIUM(module, ...)                    \
  {                                                                     \
    oboe_debug_logger(module, OBOE_DEBUG_MEDIUM, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_MEDIUM(module, ...) {}
#endif

/**
 * Log a high-detail diagnostic message.
 */
#if OBOE_DEBUG_LEVEL >= OBOE_DEBUG_HIGH
# define OBOE_DEBUG_LOG_HIGH(module, ...)                    \
  {                                                                     \
    oboe_debug_logger(module, OBOE_DEBUG_HIGH, __FILE__, __LINE__, __VA_ARGS__); \
  }
#else
# define OBOE_DEBUG_LOG_HIGH(module, format_string, ...) {}
#endif


/**
 * Low-level diagnostics logging function.
 *
 * This is normally used only by the OBOE_DEBUG_LOG_* function macros and not used directly.
 *
 * This function may be adapted to format and route diagnostic log messages as desired.
 *
 * @param module One of the numeric module identifiers defined in debug.h - used to control logging detail by module.
 * @param level Diagnostic detail level of this message - used to control logging volume by detail level.
 * @param source_name Name of the source file, if available, or another useful name, or NULL.
 * @param source_lineno Number of the line in the source file where message is logged from, if available, or zero.
 * @param format A C language printf format specification string.
 * @param args A variable argument list in VA_ARG format containing arguments for each argument specifier in the format.
 */
void oboe_debug_logger(int module, int level, const char *source_name, int source_lineno, const char *format, ...);

/**
 * Get the Oboe library revision number.
 *
 * This is the revision of the current version which is updated whenever
 * compatible changes are made to the API/ABI (ie. additions).
 *
 * @return The library's revision number or -1 if not known.
 */
extern int oboe_config_get_revision();

/*
 * Get the Oboe library version as a string.
 *
 * Returns the complete VERSION string or null
 */
const char* oboe_config_get_version_string();

/*
 * Generate UUID for RUM
 *
 * @param access_key User Access Key
 * @param uuid_length Size of the UUID to generate
 * @param digest Pointer to array where the digest value gets stored
 * @param dlen Number of bytes of data stored
 */
void oboe_rum_create_digest(const char* access_key, unsigned int uuid_length, unsigned char* digest, unsigned int *dlen);

// Span reporting

/*
 * generate a new span
 *
 * @param duration  the duration of the span in micro seconds (usec)
 * @param name      the name of the span
 * @param tags      a list of tags associated with the span (format: key1=value1&key2=value2&key3=value3)
 */
void oboe_span(const int64_t duration, const char *name, const char *tags);

/*
 * helper function to mark the start of a span
 *
 * @return monotonic time in micro seconds (usec) since some unspecified starting point
 */
int64_t oboe_span_start();

/*
 * mark the end of a span and generate a new span
 *
 * @param start     the span start time in micro seconds (usec) as returned by oboe_span_start()
 * @param name      the name of the span
 * @param tags      a list of tags associated with the span (format: key1=value1&key2=value2&key3=value3)
 */
void oboe_span_stop(const int64_t start, const char *name, const char *tags);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // LIBOBOE_H
