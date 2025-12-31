/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <string.h>
#include "logger.h"

FILE *logFile;
LogLevel currentLogLevel;
#if defined(_DEBUG)
LogLevel defaultLogLevel = LogDebug;
#else
LogLevel defaultLogLevel = LogWarn;
#endif // defined

int initializeLogging(const char *filename)
{
    setLogLevel(defaultLogLevel);
	logFile = fopen(filename, "w");
	if (logFile == NULL) {
		perror("Unable to initialize logging.");
		abort();
	}
	logMeta("Initialized logging to %s.", logLevelToString(currentLogLevel));
	return logFile != NULL;
}

int closeLogging()
{
	logMeta("Closing logging.");
	if (logFile != NULL) {
		fclose(logFile);
		return 1;
	}
	return 0;
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

void logMessage(LogLevel level, const char *message)
{
	// Should this message be logged?
	if (level < currentLogLevel)
	{
		return;
	}
	if (logFile)
	{
		// Get the current time
		time_t now = time(NULL);
		struct tm *localTime = localtime(&now);
		char datetime[100];
		strftime(datetime, sizeof(datetime), "%Y-%m-%d %H:%M:%S", localTime);

		fprintf(logFile, "[%s] %s: %s\n", datetime, logLevelToString(level), message);
	}
	else
	{
		fprintf(stderr, "Log file is not open!\n");
	}
}

void logTrace(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogTrace, buffer);
}

void logDebug(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogDebug, buffer);
}

void logInfo(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogInfo, buffer);
}

void logWarn(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogWarn, buffer);
}

void logError(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogError, buffer);
}

void logFatal(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogFatal, buffer);
}

void logMeta(const char *message, ...) {
	char buffer[256];
	va_list args;
	va_start(args, message);
	vsprintf(buffer, message, args);
	va_end(args);
	logMessage(LogMeta, buffer);
}

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

LogLevel logLevelToEnum(const char *level)
{
	if (level == NULL)
	{
		return defaultLogLevel;
	}

	if (strcmp(level, "TRACE") == 0) return LogTrace;
	else if (strcmp(level, "DEBUG") == 0) return LogDebug;
	else if (strcmp(level, "INFO" ) == 0) return LogInfo;
	else if (strcmp(level, "WARN" ) == 0) return LogWarn;
	else if (strcmp(level, "ERROR") == 0) return LogError;
	else if (strcmp(level, "FATAL") == 0) return LogFatal;

	return defaultLogLevel;
}
