/* ========================================================================
   Copyright (c) 1990,1997   Synergistic Software
   All Rights Reserved
   ========================================================================
   Filename: AIPATH.CPP
   Author:   (birp-dev pathfinding extension)

   Overview:
     Implements sector-graph A* pathfinding for in-game AI navigation.

   Map representation:
     The Doom-style WAD engine stores map geometry as:
       - linedefs  : wall segments, each with two vertex endpoints and two
                     sidedef references (one per side).
       - sidedefs  : one entry per linedef side, carrying the sector index.
       - sectors   : convex-ish floor/ceiling areas.

     A "portal" is a two-sided, non-IMPASSABLE linedef.  Its midpoint
     (the average of its two vertex endpoints) is a safe waypoint for
     crossing from one sector to the adjacent one.

   Graph construction (BuildSectorGraph):
     Scans every linedef.  A linedef qualifies as a portal when:
       - Both sidedef references are valid (psdt != -1 and psdb != -1), AND
       - The IMPASSABLE_BIT flag is clear, AND
       - The two sidedefs reference different sectors.
     A bidirectional portal edge is stored in both sector's adjacency list.

   A* search (FindSectorPath):
     Nodes are sectors.  Edges are portal connections.  The g-cost of
     traversing an edge is the approximate Euclidean distance between the
     two sector centres.  The heuristic h is also the approximate Euclidean
     distance to the target sector centre, which is admissible.  Nasty
     sectors (lava, acid, deep water) are excluded from traversal.
   ======================================================================== */

#include <stdlib.h>
#include <string.h>

#include "system.h"
#include "engine.h"
#include "engint.h"
#include "special.h"
#include "logger.h"
#include "aipath.hxx"

/* ========================================================================
   Compile-time capacity limit.
   All known combat WADs have well under 1024 sectors; guard against
   pathological or future maps without dynamic allocation for A* state.
   ======================================================================== */
#define AIPATH_MAX_SECTORS 1024

/* ========================================================================
   Private types
   ======================================================================== */

/**
 * @brief One directed portal edge leading from a sector to an adjacent one.
 */
struct SectorPortal
{
    LONG toSector;  /**< Index of the sector on the other side of the portal. */
    LONG midX;      /**< X world-coordinate of the portal linedef midpoint. */
    LONG midY;      /**< Y world-coordinate of the portal linedef midpoint. */
};

/**
 * @brief Per-sector node in the sector connectivity graph.
 *
 * @var portals     Heap-allocated array of outbound portal edges.
 * @var numPortals  Number of valid entries in portals[].
 * @var centerX     Approximate sector centre X, derived as the centroid of
 *                  all connected portal midpoints.  Used as the A* heuristic
 *                  origin; not required to be the geometric centroid.
 * @var centerY     Approximate sector centre Y.
 */
struct SectorNode
{
    SectorPortal *portals;
    int           numPortals;
    LONG          centerX;
    LONG          centerY;
};

/* ========================================================================
   Module-level state
   ======================================================================== */

/** @brief Array of SectorNode, one per sector in the current WAD. NULL when no graph exists. */
static SectorNode *gSectorGraph = NULL;

/** @brief Number of sectors in gSectorGraph; 0 when the graph has been freed. */
static int gSectorGraphCount = 0;

/* ========================================================================
   Private helper functions
   ======================================================================== */

/* ========================================================================
   Function    - IsNastySpecial
   Description - Returns TRUE if a sector special marks impassable terrain.
   ======================================================================== */
/**
 * @brief Returns TRUE if a sector special code represents hazardous terrain
 *        that the AI should not route through.
 *
 * Matches the same set of specials checked by CAvatar::mfIsNastySector().
 *
 * @param special  The sector special value from BR_SECTOR::special.
 * @return TRUE if the sector is lava, acid floor, or deep water.
 */
static BOOL IsNastySpecial(LONG special)
{
    return (special == (LONG)SSP_LAVA       ||
            special == (LONG)SSP_ACID_FLOOR ||
            special == (LONG)SSP_DEEP_WATER) ? TRUE : FALSE;
}

/* ========================================================================
   Function    - PathHeuristicDist
   Description - Admissible A* heuristic between two sector centres.
   ======================================================================== */
/**
 * @brief Compute the approximate Euclidean distance between the centres of
 *        two sectors, used as the A* heuristic.
 *
 * Uses aprox_dist (octagonal-diamond approximation, never more than ~4 %
 * above the true Euclidean distance) rather than an exact sqrt.  The
 * result is still admissible as a lower bound on actual travel distance.
 *
 * @param sectorA  Index of the first sector.
 * @param sectorB  Index of the second sector.
 * @return Approximate Euclidean distance in world units.
 */
static LONG PathHeuristicDist(int sectorA, int sectorB)
{
    return aprox_dist(
        gSectorGraph[sectorA].centerX, gSectorGraph[sectorA].centerY,
        gSectorGraph[sectorB].centerX, gSectorGraph[sectorB].centerY);
}

/* ========================================================================
   Public interface
   ======================================================================== */

/* ========================================================================
   Function    - BuildSectorGraph
   ======================================================================== */
/**
 * @brief Build the sector connectivity graph from the currently loaded WAD.
 *
 * Two-pass algorithm:
 *
 *   Pass 1 -- Count qualifying portals per sector so that portal arrays can
 *             be allocated exactly to size.  A linedef qualifies when both
 *             sidedef references are valid, IMPASSABLE_BIT is clear, and
 *             the two sides reference distinct sectors.
 *
 *   Pass 2 -- Fill each sector's portal array with the midpoint coordinates
 *             and the adjacent-sector index.  Simultaneously accumulate the
 *             sum of portal midpoints per sector to derive the centre
 *             coordinate used by the A* heuristic.
 *
 * Memory:
 *   gSectorGraph[] is a heap-allocated SectorNode array (one per sector).
 *   Each SectorNode's portals[] is separately heap-allocated and exactly
 *   sized to the number of portals found in pass 1.
 *
 * Error handling:
 *   If any allocation fails the function logs an error, frees whatever
 *   was allocated, and leaves the graph in the "not built" state so that
 *   FindSectorPath() falls back to direct movement.
 */
void BuildSectorGraph()
{
    FreeSectorGraph();

    if (tot_sectors == 0 || tot_linedefs == 0)
    {
        logDebug("BuildSectorGraph: no WAD data loaded, skipping");
        return;
    }

    if ((int)tot_sectors > AIPATH_MAX_SECTORS)
    {
        logWarn("BuildSectorGraph: tot_sectors=%lu exceeds AIPATH_MAX_SECTORS=%d -- graph not built",
            tot_sectors, AIPATH_MAX_SECTORS);
        return;
    }

    gSectorGraphCount = (int)tot_sectors;
    gSectorGraph = (SectorNode*)calloc(gSectorGraphCount, sizeof(SectorNode));
    if (!gSectorGraph)
    {
        logError("BuildSectorGraph: failed to allocate SectorNode[%d]", gSectorGraphCount);
        gSectorGraphCount = 0;
        return;
    }

    /* Temporary scratch arrays -- freed before returning. */
    int  *portalCounts = (int*)calloc(gSectorGraphCount, sizeof(int));
    LONG *sumX         = (LONG*)calloc(gSectorGraphCount, sizeof(LONG));
    LONG *sumY         = (LONG*)calloc(gSectorGraphCount, sizeof(LONG));
    int  *centerCount  = (int*)calloc(gSectorGraphCount, sizeof(int));

    if (!portalCounts || !sumX || !sumY || !centerCount)
    {
        logError("BuildSectorGraph: failed to allocate scratch arrays");
        free(portalCounts);
        free(sumX);
        free(sumY);
        free(centerCount);
        FreeSectorGraph();
        return;
    }

    /* ------------------------------------------------------------------
       Pass 1: count portal edges per sector.
       ------------------------------------------------------------------ */
    for (ULONG i = 0; i < tot_linedefs; ++i)
    {
        const LINEDEF *ld = &linedefs[i];

        /* One-sided wall -- solid, not a portal. */
        if (ld->psdt == -1 || ld->psdb == -1)
            continue;

        /* Explicitly impassable linedef. */
        if (ld->flags & IMPASSABLE_BIT)
            continue;

        int sA = (int)sidedefs[ld->psdt].sec_ptr;
        int sB = (int)sidedefs[ld->psdb].sec_ptr;

        /* Degenerate self-portal (malformed WAD). */
        if (sA == sB)
            continue;

        /* Out-of-range sector references (malformed WAD). */
        if (sA < 0 || sA >= gSectorGraphCount ||
            sB < 0 || sB >= gSectorGraphCount)
            continue;

        ++portalCounts[sA];
        ++portalCounts[sB];
    }

    /* Allocate portal arrays.  portalCounts[] is then reused as write cursors
       in pass 2 (reset to 0 after allocation). */
    for (int s = 0; s < gSectorGraphCount; ++s)
    {
        if (portalCounts[s] > 0)
        {
            gSectorGraph[s].portals = (SectorPortal*)calloc(
                portalCounts[s], sizeof(SectorPortal));
            if (!gSectorGraph[s].portals)
            {
                logError("BuildSectorGraph: portal alloc failed for sector %d -- portals omitted", s);
                /* Proceed; sectors with no portal array are treated as dead-ends. */
            }
        }
        portalCounts[s] = 0; /* reset for use as write cursor in pass 2 */
    }

    /* ------------------------------------------------------------------
       Pass 2: fill portal arrays and accumulate sector centre data.
       ------------------------------------------------------------------ */
    for (ULONG i = 0; i < tot_linedefs; ++i)
    {
        const LINEDEF *ld = &linedefs[i];
        if (ld->psdt == -1 || ld->psdb == -1)
            continue;
        if (ld->flags & IMPASSABLE_BIT)
            continue;

        int sA = (int)sidedefs[ld->psdt].sec_ptr;
        int sB = (int)sidedefs[ld->psdb].sec_ptr;
        if (sA == sB)
            continue;
        if (sA < 0 || sA >= gSectorGraphCount ||
            sB < 0 || sB >= gSectorGraphCount)
            continue;

        const LONG ax   = (LONG)vertexs[ld->a].x;
        const LONG ay   = (LONG)vertexs[ld->a].y;
        const LONG bx   = (LONG)vertexs[ld->b].x;
        const LONG by   = (LONG)vertexs[ld->b].y;
        const LONG midX = (ax + bx) / 2;
        const LONG midY = (ay + by) / 2;

        /* Add A -> B directed portal. */
        if (gSectorGraph[sA].portals)
        {
            int idx = portalCounts[sA]++;
            gSectorGraph[sA].portals[idx].toSector = (LONG)sB;
            gSectorGraph[sA].portals[idx].midX     = midX;
            gSectorGraph[sA].portals[idx].midY     = midY;
        }

        /* Add B -> A directed portal. */
        if (gSectorGraph[sB].portals)
        {
            int idx = portalCounts[sB]++;
            gSectorGraph[sB].portals[idx].toSector = (LONG)sA;
            gSectorGraph[sB].portals[idx].midX     = midX;
            gSectorGraph[sB].portals[idx].midY     = midY;
        }

        /* Accumulate portal midpoints for sector centre estimation. */
        sumX[sA] += midX;  sumY[sA] += midY;  ++centerCount[sA];
        sumX[sB] += midX;  sumY[sB] += midY;  ++centerCount[sB];
    }

    /* Finalise each sector node. */
    for (int s = 0; s < gSectorGraphCount; ++s)
    {
        gSectorGraph[s].numPortals = portalCounts[s];
        if (centerCount[s] > 0)
        {
            gSectorGraph[s].centerX = sumX[s] / centerCount[s];
            gSectorGraph[s].centerY = sumY[s] / centerCount[s];
        }
        /* Sectors with no portals retain (0,0) as their centre -- they are
           isolated rooms reachable only by teleport and will never appear
           in a FindSectorPath result. */
    }

    free(portalCounts);
    free(sumX);
    free(sumY);
    free(centerCount);

    logInfo("BuildSectorGraph: built sector graph (%d sectors, %lu linedefs)",
        gSectorGraphCount, tot_linedefs);
}

/* ========================================================================
   Function    - FreeSectorGraph
   ======================================================================== */
/**
 * @brief Free all heap memory owned by the sector graph.
 *
 * Iterates gSectorGraph[], freeing each sector's portal array, then frees
 * gSectorGraph itself and resets the count to zero.
 */
void FreeSectorGraph()
{
    if (!gSectorGraph)
        return;

    for (int s = 0; s < gSectorGraphCount; ++s)
    {
        if (gSectorGraph[s].portals)
        {
            free(gSectorGraph[s].portals);
            gSectorGraph[s].portals = NULL;
        }
    }

    free(gSectorGraph);
    gSectorGraph      = NULL;
    gSectorGraphCount = 0;

    logDebug("FreeSectorGraph: sector graph freed");
}

/* ========================================================================
   Function    - FindSectorPath
   ======================================================================== */
/**
 * @brief A* search on the sector graph from fromSector to toSector.
 *
 * Algorithm:
 *   1. Initialise g-costs to INT_MAX and mark all sectors as unvisited.
 *   2. Add fromSector to the open set with g=0.
 *   3. Each iteration: extract the lowest-f open sector.
 *      For each outbound portal:
 *        - Skip sectors in the closed set.
 *        - Skip sectors with nasty specials (lava, acid, deep water).
 *        - Compute tentative g = g(current) + dist(centre[current], centre[next]).
 *        - If better than known g: record parent portal, update g and f, add to open.
 *   4. When toSector is expanded, reconstruct the portal midpoint sequence.
 *
 * Open-set strategy:
 *   Linear scan over the sector array.  With at most AIPATH_MAX_SECTORS (~hundreds)
 *   sectors, this is fast enough to run per-target-acquisition without measurable
 *   frame-time impact.  A heap would be needed only if sector counts grow to
 *   thousands.
 *
 * State arrays:
 *   Declared static so no per-call heap allocation is needed.  The function
 *   is not re-entrant, but re-entrancy is not required -- the game loop
 *   processes one AI character at a time.
 *
 * @param fromSector    Starting sector index.
 * @param toSector      Destination sector index.
 * @param waypointsX    Output: X world-coordinates of portal midpoints, travel order.
 * @param waypointsY    Output: Y world-coordinates of portal midpoints, travel order.
 * @param maxWaypoints  Capacity of waypointsX / waypointsY.
 * @return  Number of waypoints written (>= 0) on success, or -1 if no path exists.
 */
int FindSectorPath(LONG fromSector, LONG toSector,
                   LONG *waypointsX, LONG *waypointsY, int maxWaypoints)
{
    if (fromSector == toSector)
        return 0;

    if (!gSectorGraph || gSectorGraphCount == 0)
    {
        logDebug("FindSectorPath: graph not available (from=%ld to=%ld)", fromSector, toSector);
        return -1;
    }

    if (fromSector < 0 || fromSector >= (LONG)gSectorGraphCount ||
        toSector   < 0 || toSector   >= (LONG)gSectorGraphCount)
    {
        logDebug("FindSectorPath: sector index out of range (from=%ld to=%ld count=%d)",
            fromSector, toSector, gSectorGraphCount);
        return -1;
    }

    /* ------------------------------------------------------------------
       A* state -- static to avoid per-call allocation overhead.
       ------------------------------------------------------------------ */
    static LONG  gCost[AIPATH_MAX_SECTORS];   /**< Best known cost from fromSector. */
    static LONG  fScore[AIPATH_MAX_SECTORS];  /**< g + h estimate to toSector. */
    static int   parent[AIPATH_MAX_SECTORS];  /**< Sector we arrived from. */
    static int   parentPortal[AIPATH_MAX_SECTORS]; /**< Portal index in parent that leads here. */
    static BOOL  inOpen[AIPATH_MAX_SECTORS];  /**< Sector is in the open set. */
    static BOOL  inClosed[AIPATH_MAX_SECTORS];/**< Sector has been fully expanded. */

    const int from = (int)fromSector;
    const int to   = (int)toSector;

    for (int i = 0; i < gSectorGraphCount; ++i)
    {
        gCost[i]        = 0x7FFFFFFF;
        fScore[i]       = 0x7FFFFFFF;
        parent[i]       = -1;
        parentPortal[i] = -1;
        inOpen[i]       = FALSE;
        inClosed[i]     = FALSE;
    }

    gCost[from]  = 0;
    fScore[from] = PathHeuristicDist(from, to);
    inOpen[from] = TRUE;

    /* ------------------------------------------------------------------
       Main A* loop.
       ------------------------------------------------------------------ */
    for (;;)
    {
        /* Find the open sector with the lowest f-score (linear scan). */
        int  current = -1;
        LONG bestF   = 0x7FFFFFFF;
        for (int i = 0; i < gSectorGraphCount; ++i)
        {
            if (inOpen[i] && fScore[i] < bestF)
            {
                bestF   = fScore[i];
                current = i;
            }
        }

        if (current == -1)
        {
            logDebug("FindSectorPath: no path from %ld to %ld", fromSector, toSector);
            return -1; /* open set exhausted -- no path */
        }

        if (current == to)
            break; /* destination reached */

        inOpen[current]   = FALSE;
        inClosed[current] = TRUE;

        for (int p = 0; p < gSectorGraph[current].numPortals; ++p)
        {
            int next = (int)gSectorGraph[current].portals[p].toSector;
            if (next < 0 || next >= gSectorGraphCount)
                continue;
            if (inClosed[next])
                continue;
            if (sectors && IsNastySpecial(sectors[next].special))
                continue;

            /* Edge cost: approximate Euclidean distance between sector centres. */
            LONG tentG = gCost[current] + PathHeuristicDist(current, next);
            if (tentG < 0)
                tentG = 0x7FFFFFFE; /* overflow guard */

            if (tentG < gCost[next])
            {
                parent[next]       = current;
                parentPortal[next] = p;
                gCost[next]        = tentG;
                fScore[next]       = tentG + PathHeuristicDist(next, to);
                inOpen[next]       = TRUE;
            }
        }
    }

    /* ------------------------------------------------------------------
       Reconstruct path: walk back from toSector to fromSector, collecting
       portal midpoints in reverse, then copy them forward into the output.
       ------------------------------------------------------------------ */
    static LONG revX[AIPATH_MAX_SECTORS];
    static LONG revY[AIPATH_MAX_SECTORS];
    int revLen = 0;
    int cur    = to;

    while (parent[cur] != -1 && revLen < AIPATH_MAX_SECTORS)
    {
        const int prevSector = parent[cur];
        const int portalIdx  = parentPortal[cur];
        revX[revLen] = gSectorGraph[prevSector].portals[portalIdx].midX;
        revY[revLen] = gSectorGraph[prevSector].portals[portalIdx].midY;
        ++revLen;
        cur = prevSector;
    }

    /* Copy portal midpoints in forward (travel) order. */
    int count = 0;
    for (int i = revLen - 1; i >= 0 && count < maxWaypoints; --i)
    {
        waypointsX[count] = revX[i];
        waypointsY[count] = revY[i];
        ++count;
    }

    logDebug("FindSectorPath: path found from=%ld to=%ld waypoints=%d",
        fromSector, toSector, count);

    return count;
}

/* ========================================================================
   Function    - ApplySectorPath
   ======================================================================== */
/**
 * @brief Per-frame sector-path update for one AI character in AI_MOVING.
 *
 * See AIPATH.HXX for the full description and call-site pattern.
 */
void ApplySectorPath(AI_PATH_STATE *pPath,
                     LONG fromSector, LONG toSector,
                     LONG avatarX, LONG avatarY,
                     LONG targetX, LONG targetY,
                     LONG *pMoveTargetX, LONG *pMoveTargetY)
{
    /* Default: aim directly at the target. */
    *pMoveTargetX = targetX;
    *pMoveTargetY = targetY;

    if (fromSector == toSector)
    {
        /* Same sector -- clear any stale cached path and use direct movement. */
        pPath->fPathWaypointCount = 0;
        pPath->fPathTargetSector  = -1;
        return;
    }

    /* Recompute path when the target has moved to a new sector. */
    if (pPath->fPathTargetSector != toSector)
    {
        pPath->fPathWaypointCount = FindSectorPath(fromSector, toSector,
            pPath->fPathWaypointsX, pPath->fPathWaypointsY, AIPATH_MAX_WAYPOINTS);
        pPath->fPathWaypointIndex = 0;
        pPath->fPathTargetSector  = toSector;
    }

    /* Follow the current waypoint if the path has remaining entries. */
    if (pPath->fPathWaypointCount > 0 &&
        pPath->fPathWaypointIndex < pPath->fPathWaypointCount)
    {
        *pMoveTargetX = pPath->fPathWaypointsX[pPath->fPathWaypointIndex];
        *pMoveTargetY = pPath->fPathWaypointsY[pPath->fPathWaypointIndex];

        const LONG wpDist = aprox_dist(avatarX, avatarY, *pMoveTargetX, *pMoveTargetY);
        if (wpDist <= (LONG)AIPATH_WAYPOINT_REACH_DISTANCE)
        {
            ++pPath->fPathWaypointIndex;
            if (pPath->fPathWaypointIndex < pPath->fPathWaypointCount)
            {
                *pMoveTargetX = pPath->fPathWaypointsX[pPath->fPathWaypointIndex];
                *pMoveTargetY = pPath->fPathWaypointsY[pPath->fPathWaypointIndex];
            }
            else
            {
                /* All waypoints consumed -- switch to direct movement. */
                *pMoveTargetX = targetX;
                *pMoveTargetY = targetY;
            }
        }
    }
    /* else: no path found (count == -1) or not yet computed (count == 0) --
       *pMoveTargetX/Y already set to the direct target above. */
}
