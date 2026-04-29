/* =================================================================
	Birthright Preservation Patch
   =================================================================*/

#ifndef _PVERSION_HXX
#define _PVERSION_HXX

#define STRINGIFY(x) # x
#define MAKEVER(ma,mi,pa,bu) STRINGIFY(ma) "." STRINGIFY(mi) "." STRINGIFY(pa) "." STRINGIFY(bu)

// The BUILD_MAJOR should always be 1, to reflect the last official game version (1).
#define BUILD_MAJOR 1

// The BUILD_MINOR should always be 4, to reflect the last official game patch (1.4).
#define BUILD_MINOR 4

// The BUILD_PATCH is manually incremented by 1 for every new public patch release. It began as 0 for the first beta public release.
#define BUILD_PATCH 0

// The BUILD_BUILD is auto-computed as 2 (base 1 + 1 for this branch PR) plus the total number of successful PRs merged or rebased into the birp-dev develop branch.
// Do not include cancelled or abandoned PRs in the count, only include successful PRs.
#define BUILD_BUILD 11

// These are for the Character Editor only.
#define CHARED_BUILD_MAJOR 1
#define CHARED_BUILD_MINOR 0
#define CHARED_BUILD_PATCH 0
#define CHARED_BUILD_BUILD 10

#define BUILD_VERSION MAKEVER(BUILD_MAJOR,BUILD_MINOR,BUILD_PATCH,BUILD_BUILD)
#define CHARED_BUILD_VERSION MAKEVER(CHARED_BUILD_MAJOR,CHARED_BUILD_MINOR,CHARED_BUILD_PATCH,CHARED_BUILD_BUILD)

#endif // _PVERSION_HXX
