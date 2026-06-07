/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <windows.h>
#include "logger.h"

// File-based logger implementation.
// Supports severity filtering, optional buffer mode, and timestamped output.
// Designed for simple runtime diagnostics in the patch codebase.

// Global logger state used by all logging entry points.
// When true, the log file handle remains open between writes.
BOOL logBufferingStarted = FALSE;

// If true, buffer mode is permanently disabled and the log stream remains open
// once opened, allowing flush-only behavior for diagnostics builds.
BOOL logBufferingDisabled = FALSE;

// The active file handle used by the logger.
FILE *logFile;

// Default log filename used when no filename is supplied.
static char defaultLogFileName[] = "debug.log";

// Current log filename pointer. May point at defaultLogFileName or heap data.
char *logFileName = defaultLogFileName;

// Length of the current filename, excluding the terminating NUL.
size_t logFileNameLength = sizeof(defaultLogFileName) - 1;

// True when logFileName was allocated on the heap and must be freed.
BOOL logFileNameHeapAllocated = FALSE;

// Default minimum severity for emitted log messages. DEBUG for debug builds,
// WARN for release builds.
#if defined(_DEBUG)
LogLevel currentLogLevel = LogDebug;
#else
LogLevel currentLogLevel = LogWarn;
#endif // defined

/**
 * Sets the log destination file and writes an initial metadata line.
 * If filename is NULL the default debug.log name is used.
 * @param filename Optional path to the log output file.
 */
void initializeLogging(const char *filename)
{
	// Close any previously open log file before reinitializing.
	if (logFile != NULL) {
		fflush(logFile);
		fclose(logFile);
		logFile = NULL;
	}

	if (logFileNameHeapAllocated)
	{
		delete[] logFileName;
		logFileName = defaultLogFileName;
		logFileNameLength = sizeof(defaultLogFileName) - 1;
		logFileNameHeapAllocated = FALSE;
	}

	if (filename == NULL) {
		logFileName = defaultLogFileName;
		logFileNameLength = sizeof(defaultLogFileName) - 1;
	} else {
		logFileNameLength = strlen(filename);
		logFileName = new char[logFileNameLength+1];
		strcpy(logFileName, filename);
		logFileNameHeapAllocated = TRUE;
	}

	// Create or truncate the destination file immediately so early logging
	// failures are visible and the file exists for later writes.
	logFile = fopen(logFileName, "w");
	closeLogging();

	logMeta("Initialized logging file=%s level=%s.", logFileName, logLevelToString(currentLogLevel));
}

/**
 * Opens the current log file for appending.
 * If buffering is enabled, this function returns without reopening.
 * On failure the process aborts after reporting the error.
 * @return Non-zero when the log file is open or already available.
 */
int openLogging()
{
	if (logBufferingStarted) {
		return 1;
	}

	// In flush-only mode the file stays open across writes so repeated open/close
	// does not exhaust process-level file descriptors.
	if (logBufferingDisabled && logFile != NULL) {
		return 1;
	}

	logFile = fopen(logFileName, "a");
	if (logFile == NULL) {
		perror("Unable to initialize logging.");
		abort();
	}
	return logFile != NULL;
}

/**
 * Flushes and closes the current log file unless buffer mode is active.
 * @return 1 when the file was flushed/closed or buffering is active; 0 when there was no file.
 */
int closeLogging()
{
	if (logBufferingStarted) {
		return 1;
	}
	if (logFile != NULL) {
		fflush(logFile);
		if (!logBufferingDisabled) {
			fclose(logFile);
			logFile = NULL;
		}
		return 1;
	}
	return 0;
}

/**
 * Enables buffered logging so the file handle remains open across writes.
 * This reduces open/close overhead while logging multiple messages.
 */
void startLogBuffer()
{
	if(logBufferingDisabled) {
		return;
	}
	openLogging();
	logBufferingStarted = TRUE;
}

/**
 * Disables buffered logging and returns to per-message open/close behavior.
 */
void stopLogBuffer()
{
	if(logBufferingDisabled) {
		return;
	}
	logBufferingStarted = FALSE;
	closeLogging();
}

/**
 * Permanently disables buffered logging for the current process lifetime.
 * Any active buffer mode is stopped immediately.
 */
void disableLogBuffer()
{
	logBufferingDisabled = TRUE;
	stopLogBuffer();
}

/**
 * Sets the current log level using an uppercase string label.
 * Unknown or NULL input falls back to INFO.
 * @param level Uppercase log level name such as TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
 */
void setLogLevelFromString(const char *level)
{
	setLogLevel(logLevelToEnum(level));
}

/**
 * Updates the current minimum log level used by the logger.
 * Messages below this severity are suppressed.
 * @param level New minimum log level to emit.
 */
void setLogLevel(LogLevel level)
{
	LogLevel oldLevel = currentLogLevel;
	currentLogLevel = level;
	logMeta("Changing logging from %s to %s.", logLevelToString(oldLevel), logLevelToString(currentLogLevel));
}

/**
 * Core writer for logger output.
 * Applies the current severity filter, timestamps the message, and writes one line.
 * @param level Severity level for the message.
 * @param message Already formatted text to write to the log.
 */
void logMessage(LogLevel level, const char *message)
{
	if (level < currentLogLevel)
	{
		return;
	}
	if (!openLogging()) {
		return;
	}

	if (logFile)
	{
		// Get and format the current time
		time_t now = time(NULL);
		struct tm *localTime = localtime(&now);
		char datetime[100];
		strftime(datetime, sizeof(datetime), "%Y-%m-%d %H:%M:%S", localTime);

		fprintf(logFile, "[%s] %s: %s\n", datetime, logLevelToString(level), message);
	}
	closeLogging();
}

/**
 * Logs a TRACE-level formatted message.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logTrace(const char *message, ...) {
	if (LogTrace < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogTrace, buffer);
}

/**
 * Logs a DEBUG-level formatted message.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logDebug(const char *message, ...) {
	if (LogDebug < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogDebug, buffer);
}

/**
 * Logs an INFO-level formatted message.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logInfo(const char *message, ...) {
	if (LogInfo < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogInfo, buffer);
}

/**
 * Logs a WARN-level formatted message.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logWarn(const char *message, ...) {
	if (LogWarn < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogWarn, buffer);
}

/**
 * Logs an ERROR-level formatted message.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logError(const char *message, ...) {
	if (LogError < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogError, buffer);
}

/**
 * Logs a FATAL-level formatted message.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logFatal(const char *message, ...) {
	if (LogFatal < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogFatal, buffer);
}

/**
 * Logs an internal logger metadata message.
 * This is used for logger state changes and initialization records.
 * @param message printf-style format string.
 * @param ... Format arguments.
 */
void logMeta(const char *message, ...) {
	if (LogMeta < currentLogLevel)
	{
		return;
	}
	char buffer[2048];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogMeta, buffer);
}

/**
 * Converts a log level enum into a stable uppercase label.
 * @param level Log level enum value.
 * @return Uppercase string label for the level.
 */
const char* logLevelToString(LogLevel level)
{
	switch (level) {
		case LogTrace: return "TRACE";
		case LogDebug: return "DEBUG";
		case LogInfo:  return "INFO";
		case LogWarn:  return "WARN";
		case LogError: return "ERROR";
		case LogFatal: return "FATAL";
		case LogMeta: return "LOG";
	}
	return "INFO";
}

/**
 * Parses an uppercase log level name into a LogLevel enum.
 * Unknown or NULL strings fall back to LogInfo.
 * @param level Uppercase text label for the log level.
 * @return Parsed LogLevel enum.
 */
LogLevel logLevelToEnum(const char *level)
{
	if (level == NULL)
	{
		return LogInfo;
	}

	if (strcmp(level, "TRACE") == 0) return LogTrace;
	else if (strcmp(level, "DEBUG") == 0) return LogDebug;
	else if (strcmp(level, "INFO" ) == 0) return LogInfo;
	else if (strcmp(level, "WARN" ) == 0) return LogWarn;
	else if (strcmp(level, "ERROR") == 0) return LogError;
	else if (strcmp(level, "FATAL") == 0) return LogFatal;

	return LogInfo;
}
