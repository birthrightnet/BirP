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

void logTrace(const char *message, ...);
void logDebug(const char *message, ...);
void logInfo(const char *message, ...);
void logWarn(const char *message, ...);
void logError(const char *message, ...);
void logFatal(const char *message, ...);
void logMeta(const char *message, ...);

void initializeLogging(const char *filename);
int openLogging();
int closeLogging();
void startLogBuffer();
void stopLogBuffer();
void disableLogBuffer();
void setLogLevelFromString(const char *level);
void setLogLevel(LogLevel level);
void logMessage(LogLevel level, const char *message);
const char* logLevelToString(LogLevel level);
LogLevel logLevelToEnum(const char *level);

#ifdef __cplusplus
}
#endif

#endif // _LOGGER_H