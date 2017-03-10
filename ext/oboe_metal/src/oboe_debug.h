/**
 * @file: debug.h - Diagnostic logging functions for liboboe.
 *
 * Most of the diagnostics logging interface is defined in oboe.h but we
 * separate some of it out here for special handling when generating
 * SWIG interfaces.
 */

#ifndef _OBOE_DEBUG_H
#define _OBOE_DEBUG_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Defined diagnostic log detail levels.
 */
enum OBOE_DEBUG_LOG_LEVEL {
    OBOE_DEBUG_FATAL = 0,
    OBOE_DEBUG_ERROR = 1,
    OBOE_DEBUG_WARNING = 2,
    OBOE_DEBUG_INFO = 3,
    OBOE_DEBUG_LOW = 4,
    OBOE_DEBUG_MEDIUM = 5,
    OBOE_DEBUG_HIGH = 6
};

/**
 * Defined modules that do diagnostic logging.
 */
enum OBOE_DEBUG_MODULE {
    OBOE_MODULE_ALL = -1,           /*!< Pseudo module to refer to ALL modules - used for configuring generic settings */
    OBOE_MODULE_UNDEF = 0,          /*!< Generic (undefined) module */
    OBOE_MODULE_LIBOBOE,            /*!< The core Oboe library */
    OBOE_MODULE_SETTINGS,           /*!< The Oboe settings functionality */
    OBOE_MODULE_REPORTER_FILE,      /*!< File reporter */
    OBOE_MODULE_REPORTER_UDP,       /*!< UDP (Tracelyzer) reporter */
    OBOE_MODULE_REPORTER_SSL,       /*!< SSL reporter */
    OBOE_MODULE_APACHE,             /*!< Apache webserver */
    OBOE_MODULE_NGINX,              /*!< Nginx webserver */
    OBOE_MODULE_PHP,                /*!< PHP interpreter */
};

#ifdef __cplusplus
} // extern "C"
#endif

#endif // _OBOE_DEBUG_H
