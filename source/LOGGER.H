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
 * TRACE is the most verbose level and is intended for detailed diagnostics.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logTrace(const char *message, ...);

/**
 * Logs a DEBUG message using printf-style formatting.
 * DEBUG is used for developer-focused diagnostic output.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logDebug(const char *message, ...);

/**
 * Logs an INFO message using printf-style formatting.
 * INFO is used for general runtime events and progress information.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logInfo(const char *message, ...);

/**
 * Logs a WARN message using printf-style formatting.
 * WARN indicates a recoverable condition that may require attention.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logWarn(const char *message, ...);

/**
 * Logs an ERROR message using printf-style formatting.
 * ERROR indicates a problem that prevented an operation from completing.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logError(const char *message, ...);

/**
 * Logs a FATAL message using printf-style formatting.
 * FATAL indicates a critical failure where the process may abort.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logFatal(const char *message, ...);

/**
 * Logs an internal logger metadata message using printf-style formatting.
 * Metadata messages describe logger state changes and initialization events.
 * @param message Format string.
 * @param ... Format arguments for message.
 */
void logMeta(const char *message, ...);

/**
 * Initializes the logging subsystem and selects the output file.
 * If filename is NULL, the logger uses the default file name.
 * @param filename Optional path to the log output file.
 */
void initializeLogging(const char *filename);

/**
 * Opens the current log file for appending.
 * @return Non-zero on success, zero on failure.
 */
int openLogging();

/**
 * Flushes and closes the current log file unless buffering remains active.
 * @return Non-zero when the file was flushed/closed or buffering is active; 0 when no file was open.
 */
int closeLogging();

/**
 * Enables buffered logging so the file handle remains open across writes.
 * This is useful when emitting many messages in a short period.
 */
void startLogBuffer();

/**
 * Disables buffered logging and returns to open/write/close behavior.
 */
void stopLogBuffer();

/**
 * Permanently disables buffered logging for the current process lifetime.
 */
void disableLogBuffer();

/**
 * Sets the current log level using an uppercase string label.
 * Unknown or NULL input falls back to INFO.
 * @param level Uppercase log level name.
 */
void setLogLevelFromString(const char *level);

/**
 * Sets the current minimum log level.
 * Messages below this severity are suppressed.
 * @param level New minimum log level.
 */
void setLogLevel(LogLevel level);

/**
 * Writes a preformatted log message at the specified severity level.
 * @param level Severity level of the message.
 * @param message Formatted text to write.
 */
void logMessage(LogLevel level, const char *message);

/**
 * Converts a LogLevel enum value to its uppercase string label.
 * @param level Enum value to convert.
 * @return Uppercase label for the log level.
 */
const char* logLevelToString(LogLevel level);

/**
 * Parses an uppercase log level name into a LogLevel enum.
 * Unknown or NULL strings fall back to LogInfo.
 * @param level Uppercase level text.
 * @return Parsed LogLevel enum.
 */
LogLevel logLevelToEnum(const char *level);

#ifdef __cplusplus
}
#endif

#endif // _LOGGER_H
