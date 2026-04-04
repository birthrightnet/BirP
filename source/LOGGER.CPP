/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <windows.h>
#include "logger.h"

BOOL logBufferingStarted = FALSE;
BOOL logBufferingDisabled = FALSE;
FILE *logFile;
char *logFileName = "debug.log";
size_t logFileNameLength = strlen("debug.log");
#if defined(_DEBUG)
LogLevel currentLogLevel = LogDebug;
#else
LogLevel currentLogLevel = LogWarn;
#endif // defined

void initializeLogging(const char *filename)
{
	delete[] logFileName;
	if (filename == NULL) {
		logFileName = "debug.log";
		logFileNameLength = strlen("debug.log");
	} else {
		logFileNameLength = strlen(filename);
		logFileName = new char[logFileNameLength+1];
		strcpy(logFileName, filename);
	}

	logFile = fopen(logFileName, "w");
	closeLogging();

	logMeta("Initialized logging to %s.", logLevelToString(currentLogLevel));
}

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

void startLogBuffer()
{
	if(logBufferingDisabled) {
		return;
	}
	openLogging();
	logBufferingStarted = TRUE;
}

void stopLogBuffer()
{
	if(logBufferingDisabled) {
		return;
	}
	logBufferingStarted = FALSE;
	closeLogging();
}

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