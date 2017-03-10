/**
 * @file oboe.hpp - C++ liboboe wrapper primarily for generating SWIG interfaces
 *
 * This API should follow https://github.com/tracelytics/tracelons/wiki/Instrumentation-API
 */

#ifndef OBOE_HPP
#define OBOE_HPP

#include <string>
#include <oboe.h>


class Event;
class Reporter;
class Context;

/**
 * Metadata is the X-Trace identifier and the information needed to work with it.
 */
class Metadata : private oboe_metadata_t {
    friend class Reporter;
    friend class SslReporter;
    friend class UdpReporter;
    friend class FileReporter;
    friend class Context;

public:
    Metadata(oboe_metadata_t *md) {
        oboe_metadata_copy(this, md);
    }

    ~Metadata() {
        oboe_metadata_destroy(this);
    }

    static Metadata* fromString(std::string s) {
        oboe_metadata_t md;
        oboe_metadata_fromstr(&md, s.data(), s.size());
        return new Metadata(&md); // copies md
    }

    // these new objects are managed by SWIG %newobject
    Event *createEvent();

    static Metadata *makeRandom() {
        oboe_metadata_t md;
        oboe_metadata_init(&md);
        oboe_metadata_random(&md);
        return new Metadata(&md); // copies md
    }

    Metadata *copy() {
        return new Metadata(this);
    }

    bool isValid() {
        return oboe_metadata_is_valid(this);
    }

#ifdef SWIGJAVA
    std::string toStr() {
#else
    std::string toString() {
#endif
        char buf[OBOE_MAX_METADATA_PACK_LEN];

        int rc = oboe_metadata_tostr(this, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

};

/**
 * The Context class manages the metadata and the settings configuration.
 *
 * The metadata includes the X-Trace identifier fields and the information work working with it.
 * The metadata is needed before any trace messages can be sent and must either be generated for
 * new traces or derived from the X-Trace header of an existing trace.
 *
 * The settings information is used primarily to determine when a new request should be traced.
 * The information begins with configuration values for tracing_mode and sample_rate and then
 * updates are received periodically from the collector to adjust the rate at which traces
 * are generated.
 */
class Context {
public:
    /**
     * Set the tracing mode.
     *
     * @param newMode One of
     * - OBOE_TRACE_NEVER(0) to disable tracing,
     * - OBOE_TRACE_ALWAYS(1) to start a new trace if needed, or
     * - OBOE_TRACE_THROUGH(2) to only add to an existing trace.
     */
    static void setTracingMode(int newMode) {
        oboe_settings_cfg_tracing_mode_set(newMode);
    }

    /**
     * Set the default sample rate.
     *
     * This rate is used until overridden by the TraceView servers.  If not set then the
     * value comes from settings records downloaded from TraceView.
     *
     * The rate is interpreted as a ratio out of OBOE_SAMPLE_RESOLUTION (currently 1,000,000).
     *
     * @param newRate A number between 0 (none) and OBOE_SAMPLE_RESOLUTION (a million)
     */
    static void setDefaultSampleRate(int newRate) {
        oboe_settings_cfg_sample_rate_set(newRate);
    }

    /**
     * Check if the current request should be traced based on the current settings.
     *
     * If in_xtrace is empty, or if it is identified as a foreign (ie. cross customer)
     * trace, then sampling will be considered as a new trace.
     * Otherwise sampling will be considered as adding to the current trace.
     * Different layers may have special rules.  Also special rules for AppView
     * Web synthetic traces apply if in_tv_meta is given a non-empty string.
     *
     * This is designed to be called once per layer per request.
     *
     *  @param layer Name of the layer being considered for tracing
     *  @param in_xtrace Incoming X-Trace ID (NULL or empty string if not present)
     *  @param in_tv_meta AppView Web ID from X-TV-Meta HTTP header or higher layer (NULL or empty string if not present).
     *  @return Zero to not trace; otherwise return the sample rate used in the low order
     *          bytes 0 to 2 and the sample source in the higher-order byte 3.
     */
    static int sampleRequest(
        std::string layer,
        std::string in_xtrace,
        std::string in_tv_meta)
    {
        int sample_rate = 0;
        int sample_source = 0;
        int rc = (oboe_sample_layer(layer.c_str(), in_xtrace.c_str(), in_tv_meta.c_str(), &sample_rate, &sample_source));

        return (rc == 0 ? 0 : (((sample_source & 0xFF) << 24) | (sample_rate & 0xFFFFFF)));
    }

    /**
     * Get a pointer to the current context (from thread-local storage)
     */
    static oboe_metadata_t *get() {
        return oboe_context_get();
    }

    /**
     * Get the current context as a printable string.
     */
#ifdef SWIGJAVA
    static std::string toStr() {
#else
    static std::string toString() {
#endif
        char buf[OBOE_MAX_METADATA_PACK_LEN];

        oboe_metadata_t *md = Context::get();
        int rc = oboe_metadata_tostr(md, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

    /**
     * Set the current context (this updates thread-local storage).
     */
    static void set(oboe_metadata_t *md) {
        oboe_context_set(md);
    }

    /**
     * Set the current context from a string.
     */
    static void fromString(std::string s) {
        oboe_context_set_fromstr(s.data(), s.size());
    }

    // this new object is managed by SWIG %newobject
    static Metadata *copy() {
        return new Metadata(Context::get());
    }

    static void clear() {
        oboe_context_clear();
    }

    static bool isValid() {
        return oboe_context_is_valid();
    }

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
     */
    static void init(std::string access_key) {
        oboe_init(access_key.c_str());
    }

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
    static int init_reporter(const char *protocol, const char *args) {
        return oboe_init_reporter(protocol, args);
    }

    /**
     * Disconnect or shut down the Oboe reporter, but allow it to be reconnect()ed.
     *
     * We don't make this a Reporter method in case there is other housework to do.
     *
     * @param rep Pointer to the active reporter object.
     */
    static void disconnect(Reporter *rep);

    /**
     * Reconnect or restart the Oboe reporter.
     *
     * We don't make this a Reporter method in case there is other housework to do.
     *
     * @param rep Pointer to the active reporter object.
     */
    static void reconnect(Reporter *rep);

    /**
     * Shut down the Oboe library.
     *
     * This releases any resources held by the library which may include terminating
     * child threads.
     */
    static void shutdown() {
        oboe_shutdown();
    }

    // these new objects are managed by SWIG %newobject
    static Event *createEvent();
    static Event *startTrace();

private:

};

class Event : private oboe_event_t {
    friend class Reporter;
    friend class SslReporter;
    friend class UdpReporter;
    friend class FileReporter;
    friend class Context;
    friend class Metadata;

private:
    Event() {
        oboe_event_init(this, Context::get());
    }

    Event(const oboe_metadata_t *md, bool addEdge=true) {
        // both methods copy metadata from md -> this
        if (addEdge) {
            // create_event automatically adds edge in event to md
            oboe_metadata_create_event(md, this);
        } else {
            // initializes new Event with this md's task_id & new random op_id; no edges set
            oboe_event_init(this, md);
        }
    }

public:
    ~Event() {
        oboe_event_destroy(this);
    }

    // called e.g. from Python e.addInfo("Key", None) & Ruby e.addInfo("Key", nil)
    bool addInfo(char *key, void* val) {
        // oboe_event_add_info(evt, key, NULL) does nothing
        (void) key;
        (void) val;
        return true;
    }

    bool addInfo(char *key, const std::string& val) {
        if (memchr(val.data(), '\0', val.size())) {
            return oboe_event_add_info_binary(this, key, val.data(), val.size()) == 0;
        } else {
            return oboe_event_add_info(this, key, val.data()) == 0;
        }
    }

    bool addInfo(char *key, long val) {
        int64_t val_ = val;
        return oboe_event_add_info_int64(this, key, val_) == 0;
    }

    bool addInfo(char *key, double val) {
        return oboe_event_add_info_double(this, key, val) == 0;
    }

    bool addEdge(oboe_metadata_t *md) {
        return oboe_event_add_edge(this, md) == 0;
    }

    bool addEdgeStr(const std::string& val) {
        return oboe_event_add_edge_fromstr(this, val.c_str(), val.size()) == 0;
    }

    /**
     * Get a new copy of this metadata.
     *
     * NOTE: The returned object must be "delete"d.
     */
    Metadata* getMetadata() {
        return new Metadata(&this->metadata);
    }

    std::string metadataString() {
        char buf[OBOE_MAX_METADATA_PACK_LEN];

        int rc = oboe_metadata_tostr(&this->metadata, buf, sizeof(buf) - 1);
        if (rc == 0) {
            return std::string(buf);
        } else {
            return std::string(); // throw exception?
        }
    }

    /**
     * Report this event.
     *
     * This sends the event using the default reporter.
     *
     * @return True on success; otherwise an error message is logged.
     */
    bool send() {
        return (oboe_event_send(OBOE_SEND_EVENT, this, Context::get()) >= 0);
    }

    static Event* startTrace(const oboe_metadata_t *md);

};

/**
 * Create a new event object using the thread's context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Context::createEvent() {
    return new Event(Context::get());
}

/**
 * Create a new event object using this Metadata's context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Metadata::createEvent() {
    return new Event(this);
}

/**
 * Create a new event object with a new trace context.
 *
 * NOTE: The returned object must be "delete"d.
 */
Event *Context::startTrace() {
    oboe_metadata_t *md = Context::get();
    oboe_metadata_random(md);
    return new Event();
}

/**
 * Create a new event object using the given metadata context.
 *
 * NOTE: The metadata context must be unique to the new trace.
 *
 * NOTE: The returned object must be "delete"d.
 *
 * @param md The metadata object to use when creating the new event.
 */
Event *Event::startTrace(const oboe_metadata_t *md) {
    return new Event(md, false);
}

class Reporter : private oboe_reporter_t {
    friend class Context;   // Access to the private oboe_reporter_t base structure.
public:
    /**
     * Initialize a reporter structure for use with the specified protocol.
     *
     * @param protocol One of  "file", "udp", or "ssl".
     * @param args A configuration string for the specified protocol (protocol dependent syntax).
     */
    Reporter(const char *protocol, const char *args) {
        oboe_reporter_init(this, protocol, args);
    }

    ~Reporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, Context::get()) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, md) >= 0;
    }
};


class SslReporter : private oboe_reporter_t {
public:
    SslReporter(const char *config) {
        oboe_reporter_ssl_init(this, config);
    }

    ~SslReporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, Context::get()) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, md) >= 0;
    }
};


class UdpReporter : private oboe_reporter_t {
public:
    UdpReporter(const char *addr, const char *port=NULL) {
        if (port == NULL)
            port = "7831";

        oboe_reporter_udp_init(this, addr, port);
    }

    ~UdpReporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, Context::get()) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, md) >= 0;
    }
};

class FileReporter : private oboe_reporter_t {
public:
    FileReporter(const char *file) {
        oboe_reporter_file_init(this, file);
    }

    ~FileReporter() {
        oboe_reporter_destroy(this);
    }

    bool sendReport(Event *evt) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, Context::get()) >= 0;
    }

    bool sendReport(Event *evt, oboe_metadata_t *md) {
        return oboe_event_send(OBOE_SEND_EVENT, evt, md) >= 0;
    }
};


/**
 * Base class for a diagnostic log message handler.
 */
class DebugLogger {
public:
    virtual ~DebugLogger() {}
    virtual void log(int module, int level, const char *source_name, int source_lineno, const char *msg) = 0;
};

/**
 * "C" language wrapper for DebugLogger classes.
 *
 * A logging function that can be added to the logger chain using
 * DebugLog::addDebugLogger().
 *
 * @param context The context pointer that was registered in the call to
 *          DebugLog::addDebugLogger().  Use it to pass the pointer-to-self for
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
extern "C" void oboe_debug_log_handler(void *context, int module, int level, const char *source_name, int source_lineno, const char *msg) {
    ((DebugLogger *)context)->log(module, level, source_name, source_lineno, msg);
}

class DebugLog {
public:
    /**
     * Get a printable name for a diagnostics logging level.
     *
     * @param level A detail level in the range 0 to 6 (OBOE_DEBUG_FATAL to OBOE_DEBUG_HIGH).
     */
    static std::string getLevelName(int level) {
        return std::string(oboe_debug_log_level_name(level));
    }

    /**
     * Get a printable name for a diagnostics logging module identifier.
     *
     * @param module One of the OBOE_MODULE_* values.
     */
    static std::string getModuleName(int module) {
        return std::string(oboe_debug_module_name(module));
    }

    /**
     * Get the maximum logging detail level for a module or for all modules.
     *
     * This level applies to the default logger only.  Added loggers get all messages
     * below their registed detail level and need to do their own module-specific
     * filtering.
     *
     * @param module One of the OBOE_MODULE_* values.  Use OBOE_MODULE_ALL (-1) to
     *          get the overall maximum detail level.
     * @return Maximum detail level value for module (or overall) where zero is the
     *          lowest and higher values generate more detailed log messages.
     */
    static int getLevel(int module) {
        return oboe_debug_log_level_get(module);
    }

    /**
     * Set the maximum logging detail level for a module or for all modules.
     *
     * This level applies to the default logger only.  Added loggers get all messages
     * below their registered detail level and need to do their own module-specific
     * filtering.
     *
     * @param module One of the OBOE_MODULE_* values.  Use OBOE_MODULE_ALL to set
     *          the overall maximum detail level.
     * @param newLevel Maximum detail level value where zero is the lowest and higher
     *          values generate more detailed log messages.
     */
    static void setLevel(int module, int newLevel) {
        oboe_debug_log_level_set(module, newLevel);
    }

    /**
     * Set the output stream for the default logger.
     *
     * @param newStream A valid, open FILE* stream or NULL to disable the default logger.
     * @return Zero on success; otherwise an error code (normally from errno).
     */
    static int setOutputStream(FILE *newStream) {
        return oboe_debug_log_to_stream(newStream);
    }

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
    static int setOutputFile(const char *pathname) {
        return oboe_debug_log_to_file(pathname);
    }

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
    static int addDebugLogger(DebugLogger *newLogger, int logLevel) {
        return oboe_debug_log_add(oboe_debug_log_handler, newLogger, logLevel);
    }

    /**
     * Remove a logger.
     *
     * Remove the logger from the message handling chain.
     *
     * @return Zero on success, one if it was not found, and otherwise a negative
     *          value to indicate an error.
     */
    static int removeDebugLogger(DebugLogger *oldLogger) {
        return oboe_debug_log_remove(oboe_debug_log_handler, oldLogger);
    }

    /**
     * Low-level diagnostics logging function.
     *
     * Use this to pass
     * @param module One of the numeric module identifiers defined in debug.h - used to control logging detail by module.
     * @param level Diagnostic detail level of this message - used to control logging volume by detail level.
     * @param source_name Name of the source file, if available, or another useful name, or NULL.
     * @param source_lineno Number of the line in the source file where message is logged from, if available, or zero.
     * @param format A C language printf format specification string.
     * @param args A variable argument list in VA_ARG format containing arguments for each argument specifier in the format.
     */
    static void logMessage(int module, int level, const char *source_name, int source_lineno, const char *msg) {
        oboe_debug_logger(module, level, source_name, source_lineno, "%s", msg);
    }
};

class Config {
public:
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
    static bool checkVersion(int version, int revision) {
        return (oboe_config_check_version(version, revision) != 0);
    }

    /**
     * Get the Oboe library version number.
     *
     * This number increments whenever an incompatible change to the API/ABI is made.
     *
     * @return The library's version number or -1 if the version is not known.
     */
    static int getVersion() {
        return oboe_config_get_version();
    }

    /**
     * Get the Oboe library revision number.
     *
     * This number increments whenever a compatible change is made to the
     * API/ABI (ie. an addition).
     *
     * @return The library's revision number or -1 if not known.
     */
    static int getRevision() {
        return oboe_config_get_revision();
    }
};


void Context::disconnect(Reporter *rep) {
    oboe_disconnect(rep);
}

void Context::reconnect(Reporter *rep) {
    oboe_reconnect(rep);
}


#endif      // OBOE_HPP
