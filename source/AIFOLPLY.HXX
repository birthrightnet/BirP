/* ========================================================================
   Copyright (c) 1990,1996      Synergistic Software
   All Rights Reserved
   ========================================================================
   Filename: aifolply.hxx
   Author:   Gary Powell
   ======================================================================== */
#ifndef _AIFOLPLY_H
#define _AIFOLPLY_H

#if !defined(_TYPEDEFS_H)
#include "typedefs.h"
#endif

#if !defined(_ADVENTUR_HXX)
#include "adventur.hxx"
#endif

#if !defined(_AIPATH_HXX)
#include "aipath.hxx"
#endif

/* -----------------------------------------------------------------
   class definition
   ----------------------------------------------------------------- */
class FOLLOW_PLAYER_DATA
{
public:
	typedef enum {
		THE_PLAYER,
		THE_ADVENTURE_TEAM
	} FOLLOWING_STATE;
	
	// Write to Scene File
	void mfWriteData(FILE *fp) const;
	
	// Read from Scene File
	LONG mfReadData(FILE *fp);
	
	void mfInitVals(PLAYER *pPlayer, SHORT const /* hAvatar */);
	void mfJoinAdventureTeam();
	void mfDelete();
	
	static void mfSwitchToFollowPlayer(LONG /* hAvatar */ );
	
	inline BOOL const mfCanIWalkThruWall() const;
	inline BOOL const mfAmICrouching() const;
	inline BOOL const mfDidIMove(LONG const /* x */,
                                 LONG const /* y */,
                                 LONG const /* z */,
                                 LONG const /* a */) const;
	inline void mfGetMyPosition(LONG * const /* px */,
					            LONG * const /* py */,
					            LONG * const /* pz */,
					            LONG * const /* pa */) const;
	
	// [d4-25-97 JPC] Added pStartFallZ param.
	inline WadThingType const mfBumpAndFloor(LONG * const /* pThingIndex */,
	                            LONG * const /* pFloor */,
										 LONG * const /* pFallHeight */,
										 LONG * const /* pStartFallZ */) const;
	void mfFollowPlayer();
	inline void mfFollowAdventureTeam();
	inline void mfSwapPlaces(FOLLOW_PLAYER_DATA & const);
	
	
	
	SBYTE			fCurrentSpellBox;
	
	
	// So we can tell if the animation should go to the walk sequence.
	// GWP UNUSED
	// GWP LONG		fPrevX;		//Save in the same 24.8 format as the pPlayer->x
	// GWP LONG		fPrevY;		//Save in the same 24.8 format as the pPlayer->y
	// GWP LONG		fPrevZ;
	// GWP LONG		fPrevA;
	
	LONG	fTimeLastBump;
	LONG	dAngle;		// Wall-steering offset angle; widens each retry, resets on clear move

	/**
	 * @name Sector-graph A* pathfinding state
	 *
	 * Computed once per target-sector acquisition and consumed frame-by-frame
	 * in AI_MOVING.  Reset whenever the enemy changes sectors or the avatar
	 * gives up steering.
	 *
	 * fPathWaypointCount:
	 *   -1  = A* was run but no path exists (use direct movement).
	 *    0  = no path computed yet (or path was explicitly cleared).
	 *   >0  = number of valid waypoints in the arrays below.
	 *
	 * fPathTargetSector:
	 *   The enemy sector for which the current path was computed.  -1 means
	 *   the stored path is stale and must be recomputed.  Compared against
	 *   the enemy's current sector each frame; a mismatch triggers recompute.
	 * @{
	 */
	LONG fPathWaypointsX[AIPATH_MAX_WAYPOINTS]; /**< X world-coords of portal midpoints, travel order. */
	LONG fPathWaypointsY[AIPATH_MAX_WAYPOINTS]; /**< Y world-coords of portal midpoints, travel order. */
	int  fPathWaypointCount;  /**< Number of valid waypoints; -1 = no path; 0 = not computed. */
	int  fPathWaypointIndex;  /**< Index of the next waypoint to navigate to. */
	LONG fPathTargetSector;   /**< Enemy sector when path was computed; -1 = stale/unset. */
	/** @} */

private:
	ADVENTURER		fAdventurer;
	PLAYER			*fpPlayer;
	FOLLOWING_STATE	fFollowState;
	SHORT			fhAvatar;
};
	
/* -----------------------------------------------------------------
   inline member functions
   ----------------------------------------------------------------- */
// Cleanup the memory
inline void FOLLOW_PLAYER_DATA::mfDelete()
{
	fAdventurer.mfRelease();
}

// write member data to scene file
inline void FOLLOW_PLAYER_DATA::mfWriteData(FILE *) const
{
	//fprintf(fp, "%ld %ld\n", DistX, DistY);
}

// read member data from scene file
inline LONG FOLLOW_PLAYER_DATA::mfReadData(FILE *)
{
	//char cpBuffer[80];
	//LONG Result = GetNextLine(fp, cpBuffer, sizeof(cpBuffer));
	//
	//if (Result != EOF)
	//{
	//	Result = ( (2 == sscanf(cpBuffer, "%ld %ld", &DistX, &DistY) ) ? Result : EOF);
	//}
	//return Result;
	return 1;
}

// Attach this ai to this PLAYER structure.
inline void FOLLOW_PLAYER_DATA::mfInitVals(PLAYER * pPlayer, SHORT const hAvatar)
{
	fpPlayer = pPlayer;
	fAdventurer.mfInitData();
	fFollowState = THE_PLAYER;
	fhAvatar = hAvatar;
	dAngle = 8;
	fPathWaypointCount = 0;
	fPathWaypointIndex = 0;
	fPathTargetSector  = -1;
}

// Connect up to an adventure team
inline void FOLLOW_PLAYER_DATA::mfJoinAdventureTeam()
{
	fAdventurer.mfJoinAdventureTeam(fhAvatar);
	fFollowState = THE_ADVENTURE_TEAM;
}


inline void FOLLOW_PLAYER_DATA::mfFollowAdventureTeam()
{
	fFollowState = THE_ADVENTURE_TEAM;
}

inline BOOL const FOLLOW_PLAYER_DATA::mfCanIWalkThruWall() const
{
	return (fFollowState == THE_ADVENTURE_TEAM) ?
	        fAdventurer.mfCanIWalkThruWall() : fpPlayer->WalkThruWall;
}

inline BOOL const FOLLOW_PLAYER_DATA::mfAmICrouching() const
{
	return (fFollowState == THE_ADVENTURE_TEAM) ?
	        fAdventurer.mfAmICrouching() : fpPlayer->Crouching;
}

inline void FOLLOW_PLAYER_DATA::mfGetMyPosition(LONG * const px,
					                            LONG * const py,
					                            LONG * const pz,
					                            LONG * const pa) const
{
	if (fFollowState == THE_ADVENTURE_TEAM)
	{
		fAdventurer.mfGetMyPosition(px, py, pz, pa);
	}
	else
	{
		*px = PLAYER_INT_VAL(fpPlayer->x);
		*py = PLAYER_INT_VAL(fpPlayer->y);
		*pz = fpPlayer->z;
		*pa = fpPlayer->a;
	}
}

inline WadThingType const FOLLOW_PLAYER_DATA::mfBumpAndFloor(
	LONG * const  pThingIndex ,
    LONG * const  pFloor ,
	LONG * const  pFallHeight,
	LONG * const  pStartFallZ) const
{
	WadThingType Result;
	
	if (fFollowState == THE_ADVENTURE_TEAM)
	{
		Result = fAdventurer.mfBumpAndFloor(pThingIndex, pFloor, pFallHeight, pStartFallZ);
	}
	else
	{
		*pThingIndex = fpPlayer->BumpIndex;
		*pFloor = fpPlayer->floor;
		*pFallHeight = fpPlayer->fallHeight;
		*pStartFallZ = fpPlayer->startFallZ;
		Result = fpPlayer->bump;
	}
	
	return Result;
}

inline BOOL const FOLLOW_PLAYER_DATA::mfDidIMove(LONG const x,
                                                 LONG const y,
                                                 LONG const z,
                                                 LONG const a) const
{
	BOOL Result;
	
	if (fFollowState == THE_ADVENTURE_TEAM)
	{
		Result = fAdventurer.mfDidIMove(x, y, z, a);
	}
	else
	{
		Result = (x != PLAYER_INT_VAL(fpPlayer->x) ||
				  y != PLAYER_INT_VAL(fpPlayer->y) ||
				  z != fpPlayer->z ||
				  a != fpPlayer->a);
	}
	
	return Result;
}
inline void FOLLOW_PLAYER_DATA::mfSwapPlaces(FOLLOW_PLAYER_DATA & const OtherFollower)
{
	fAdventurer.mfSwapPlaces(OtherFollower.fAdventurer);
}
#endif	// _AIFOLPLY_HXX
