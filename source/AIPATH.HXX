/* ========================================================================
   Copyright (c) 1990,1997   Synergistic Software
   All Rights Reserved
   ========================================================================
   Filename: AIPATH.HXX
   Author:   (birp-dev pathfinding extension)

   Overview:
     Public interface for sector-graph A* pathfinding.

     The game uses a Doom-style WAD engine whose map geometry is stored as
     linedefs (line-segment walls), sidedefs (one per linedef side carrying
     the sector reference), and sectors (convex-ish floor/ceiling areas).

     A "portal" is a two-sided, non-IMPASSABLE linedef connecting two
     sectors.  BuildSectorGraph() scans all linedefs after a WAD is loaded
     and builds a bidirectional adjacency list of portal edges.

     FindSectorPath() runs a standard A* search on this graph and returns
     an ordered list of portal midpoint coordinates that an AI character
     can follow to navigate from its sector to a target sector, routing
     cleanly around walls, corners, and furniture.

   Lifecycle:
     1. After load_new_wad():   call BuildSectorGraph()
     2. Before PurgeLevel():    call FreeSectorGraph()
     3. In AI_MOVING:           call FindSectorPath() and follow waypoints

   ======================================================================== */
#ifndef _AIPATH_HXX
#define _AIPATH_HXX

#if !defined(_TYPEDEFS_H)
#include "typedefs.h"
#endif

/* ========================================================================
   Constants
   ======================================================================== */

/**
 * @brief Maximum number of portal waypoints returned by FindSectorPath().
 *
 * Paths longer than this are truncated at the last stored waypoint;
 * the AI will fall back to direct movement for the remainder.
 * 24 portals is sufficient for all expected combat map layouts.
 */
#define AIPATH_MAX_WAYPOINTS 24

/**
 * @brief Distance threshold (world units) at which an AI character is
 *        considered to have reached a waypoint and may advance to the next.
 *
 * Matches the original WaypointReachDistance constant used in AIFOLPLY.CPP
 * before pathfinding was generalised to all character types.
 */
#define AIPATH_WAYPOINT_REACH_DISTANCE 80

/* ========================================================================
   AI_PATH_STATE -- per-character pathfinding state
   ======================================================================== */

/**
 * @brief Sector-graph A* pathfinding state for one AI character.
 *
 * Stored as a non-union member (AI_PATH_STATE fAiPath) on CAvatar so that
 * every AI function -- follow-player, ping-pong, hellhound, spider, spectre,
 * and any future types -- can use the sector-graph path without sharing
 * storage with their own AI-specific union data.
 *
 * Lifecycle:
 *   Initialise to { 0, 0, -1 } at AI_INIT time.  ApplySectorPath() updates
 *   the state each frame during AI_MOVING.  Reset fPathWaypointCount = 0
 *   and fPathTargetSector = -1 whenever the AI gives up steering so that the
 *   next pursuit attempt triggers a fresh A* query.
 */
struct AI_PATH_STATE
{
    LONG fPathWaypointsX[AIPATH_MAX_WAYPOINTS]; /**< X world-coords of portal midpoints, travel order. */
    LONG fPathWaypointsY[AIPATH_MAX_WAYPOINTS]; /**< Y world-coords of portal midpoints, travel order. */
    int  fPathWaypointCount;  /**< Waypoint count: -1=no path found, 0=not computed, >0=count. */
    int  fPathWaypointIndex;  /**< Index of the next waypoint to navigate toward. */
    LONG fPathTargetSector;   /**< Enemy sector when path was computed; -1 = stale/unset. */
};

/* ========================================================================
   Public interface
   ======================================================================== */

/**
 * @brief Build the sector connectivity graph from the currently loaded WAD.
 *
 * Must be called after load_new_wad() completes and before any call to
 * FindSectorPath().  Scans all linedefs for two-sided, non-IMPASSABLE
 * portals and constructs per-sector adjacency lists.  Also computes a
 * representative centre coordinate for every sector (used as the A*
 * heuristic origin).
 *
 * Calling BuildSectorGraph() when a graph already exists silently frees
 * the previous graph first.
 *
 * @note This function must not be called while the AI main loop is running
 *       (i.e., only call it during scene load, not mid-frame).
 */
void BuildSectorGraph();

/**
 * @brief Free all memory associated with the current sector graph.
 *
 * Must be called before PurgeLevel() / load_new_wad() so that stale
 * sector and linedef pointers are not accessed after the WAD is unloaded.
 * Safe to call when no graph has been built (no-op in that case).
 */
void FreeSectorGraph();

/**
 * @brief Find a path from one sector to another via A* on the sector graph.
 *
 * Performs an A* search where nodes are sectors and edges are passable
 * portal linedefs.  The heuristic is the Euclidean (octagonal-diamond)
 * distance between sector centres, which is admissible.  Hazardous
 * sectors (lava, acid, deep water) are excluded from the search.
 *
 * @param fromSector    Index of the starting sector (avatar's current sector).
 * @param toSector      Index of the destination sector (enemy's current sector).
 * @param waypointsX    Output array; receives X world-coordinates of each
 *                      portal midpoint along the path, in travel order.
 * @param waypointsY    Output array; receives Y world-coordinates.
 * @param maxWaypoints  Capacity of the output arrays; use AIPATH_MAX_WAYPOINTS.
 *
 * @return  Number of waypoints written (>= 0) on success.
 *          0  means fromSector == toSector (already in the target sector).
 *          -1 means no path exists (impassable geometry or graph not built).
 *
 * @note    The caller should navigate to each waypoint in sequence, advancing
 *          to the next waypoint when within WaypointReachDistance of the current
 *          one.  After all waypoints are consumed, switch to direct movement
 *          toward the enemy.
 */
int FindSectorPath(LONG fromSector, LONG toSector,
                   LONG *waypointsX, LONG *waypointsY, int maxWaypoints);

#endif /* _AIPATH_HXX */
