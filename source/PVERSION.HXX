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

// The BUILD_PATCH is manually incremented by 1 during promotion to Prod.
// Do not update this unless you are promoting to Prod.
#define BUILD_PATCH 0

// The BUILD_BUILD is auto-computed from latest commit at promotion to Prod.
// You should update this field to the number of successful PRs in GitHub against the `develop` branch + 2, but keep in mind this will likely be replaced.
#define BUILD_BUILD 14

// These are for the Character Editor only.
#define CHARED_BUILD_MAJOR 1
#define CHARED_BUILD_MINOR 0
#define CHARED_BUILD_PATCH 0
#define CHARED_BUILD_BUILD 10

#define BUILD_VERSION MAKEVER(BUILD_MAJOR,BUILD_MINOR,BUILD_PATCH,BUILD_BUILD)
#define CHARED_BUILD_VERSION MAKEVER(CHARED_BUILD_MAJOR,CHARED_BUILD_MINOR,CHARED_BUILD_PATCH,CHARED_BUILD_BUILD)

#endif // _PVERSION_HXX
