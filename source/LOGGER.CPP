/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <windows.h>
#include "logger.h"

// Global logger state used by all logging entry points.
BOOL logBufferingStarted = FALSE;
BOOL logBufferingDisabled = FALSE;
FILE *logFile;
static char defaultLogFileName[] = "debug.log";
char *logFileName = defaultLogFileName;
size_t logFileNameLength = sizeof(defaultLogFileName) - 1;
BOOL logFileNameHeapAllocated = FALSE;
#if defined(_DEBUG)
LogLevel currentLogLevel = LogDebug;
#else
LogLevel currentLogLevel = LogWarn;
#endif // defined

// Sets the log destination file and writes an initial metadata line.
void initializeLogging(const char *filename)
{
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

	logFile = fopen(logFileName, "w");
	closeLogging();

	logMeta("Initialized logging file=%s level=%s.", logFileName, logLevelToString(currentLogLevel));
}

// Opens the file unless buffering keeps it open across calls.
int openLogging()
{
	if (logBufferingStarted) {
		return 1;
	}
	logFile = fopen(logFileName, "a");
	if (logFile == NULL) {
		perror("Unable to initialize logging.");
		abort();
	}
	return logFile != NULL;
}

// Flushes/closes the file unless buffering mode is active.
int closeLogging()
{
	if (logBufferingStarted) {
		return 1;
	}
	if (logFile != NULL) {
		fflush(logFile);
		fclose(logFile);
		return 1;
	}
	return 0;
}

// Buffer mode keeps the file handle open to reduce open/close overhead.
void startLogBuffer()
{
	if(logBufferingDisabled) {
		return;
	}
	openLogging();
	logBufferingStarted = TRUE;
}

// Returns to per-message open/close behavior.
void stopLogBuffer()
{
	if(logBufferingDisabled) {
		return;
	}
	logBufferingStarted = FALSE;
	closeLogging();
}

// Permanently disables buffering for the current process lifetime.
void disableLogBuffer()
{
	logBufferingDisabled = TRUE;
	stopLogBuffer();
}

void setLogLevelFromString(const char *level)
{
	setLogLevel(logLevelToEnum(level));
}

void setLogLevel(LogLevel level)
{
	LogLevel oldLevel = currentLogLevel;
	currentLogLevel = level;
	logMeta("Changing logging from %s to %s.", logLevelToString(oldLevel), logLevelToString(currentLogLevel));
}

// Core writer: applies level filter, timestamps, and writes one line.
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

// Convenience wrappers format varargs text, then delegate to logMessage.
void logTrace(const char *message, ...) {
	if (LogTrace < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogTrace, buffer);
}

void logDebug(const char *message, ...) {
	if (LogDebug < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogDebug, buffer);
}

void logInfo(const char *message, ...) {
	if (LogInfo < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogInfo, buffer);
}

void logWarn(const char *message, ...) {
	if (LogWarn < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogWarn, buffer);
}

void logError(const char *message, ...) {
	if (LogError < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogError, buffer);
}

void logFatal(const char *message, ...) {
	if (LogFatal < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogFatal, buffer);
}

void logMeta(const char *message, ...) {
	if (LogMeta < currentLogLevel)
	{
		return;
	}
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogMeta, buffer);
}

// Converts enum values to stable on-disk text labels.
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

// Parses uppercase level names; unknown input falls back to INFO.
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
