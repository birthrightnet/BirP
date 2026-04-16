/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#ifndef _LOGGER_H
#define _LOGGER_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	LogTrace,
	LogDebug,
	LogInfo,
	LogWarn,
	LogError,
	LogFatal,
	LogMeta
} LogLevel;

/**
 * Logs a TRACE message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logTrace(const char *message, ...);

/**
 * Logs a DEBUG message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logDebug(const char *message, ...);

/**
 * Logs an INFO message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logInfo(const char *message, ...);

/**
 * Logs a WARN message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logWarn(const char *message, ...);

/**
 * Logs an ERROR message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logError(const char *message, ...);

/**
 * Logs a FATAL message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logFatal(const char *message, ...);

/**
 * Logs a logger-internal metadata message using printf-style formatting.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logMeta(const char *message, ...);

/**
 * Initializes logging and selects the log file path.
 * @param filename Optional file path. NULL uses the default debug.log.
 */
void initializeLogging(const char *filename);

/**
 * Opens the current log file for appending.
 * @return Non-zero on success, zero on failure.
 */
int openLogging();

/**
 * Flushes and closes the current log file.
 * @return Non-zero when the file is already buffered or closed successfully.
 */
int closeLogging();

/**
 * Enables buffered logging (keep log file open between writes).
 */
void startLogBuffer();

/**
 * Disables buffered logging (return to open/write/close behavior).
 */
void stopLogBuffer();

/**
 * Permanently disables log buffering for the current process.
 */
void disableLogBuffer();

/**
 * Sets the current log level from an uppercase level name.
 * @param level Level string (TRACE, DEBUG, INFO, WARN, ERROR, FATAL).
 */
void setLogLevelFromString(const char *level);

/**
 * Sets the current minimum log level.
 * @param level New minimum level to emit.
 */
void setLogLevel(LogLevel level);

/**
 * Writes a preformatted log message at the specified level.
 * @param level Severity level of the message.
 * @param message Text to write.
 */
void logMessage(LogLevel level, const char *message);

/**
 * Converts a LogLevel value to its string label.
 * @param level Enum value to convert.
 * @return Uppercase level text.
 */
const char* logLevelToString(LogLevel level);

/**
 * Converts a level string to a LogLevel value.
 * @param level Uppercase level text.
 * @return Parsed enum value, or LogInfo when unknown.
 */
LogLevel logLevelToEnum(const char *level);

#ifdef __cplusplus
}
#endif

#endif // _LOGGER_H
