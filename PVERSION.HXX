/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#ifndef _PVERSION_HXX
#define _PVERSION_HXX

#define STRINGIFY(x) # x
#define MAKEVER(ma,mi,pa,bu) STRINGIFY(ma) "." STRINGIFY(mi) "." STRINGIFY(pa) "." STRINGIFY(bu)

#define BUILD_MAJOR 1
#define BUILD_MINOR 4
#define BUILD_PATCH 0
#define BUILD_BUILD 10

#define CHARED_BUILD_MAJOR 1
#define CHARED_BUILD_MINOR 0
#define CHARED_BUILD_PATCH 0
#define CHARED_BUILD_BUILD 8

#define BUILD_VERSION MAKEVER(BUILD_MAJOR,BUILD_MINOR,BUILD_PATCH,BUILD_BUILD)
#define CHARED_BUILD_VERSION MAKEVER(CHARED_BUILD_MAJOR,CHARED_BUILD_MINOR,CHARED_BUILD_PATCH,CHARED_BUILD_BUILD)

#endif // _PVERSION_HXX
