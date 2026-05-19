/* ========================================================================
   Copyright (c) 1990,1996	Synergistic Software
   All Rights Reserved
   ========================================================================
   Filename: adventur.cpp  - control the adventure groups position.
   Author:   Gary Powell

   ========================================================================

   Contains the following general functions:


   ======================================================================== */

/* ------------------------------------------------------------------------
   Includes
   ------------------------------------------------------------------------ */
#include "adventur.hxx"
#include "avatar.hxx"
#include "gametype.hxx"
#include "scnmgr.hxx"
#include "sound.hxx"
#include "scene.hxx"
#include "playstat.hxx"
#include "logger.h"

/* ------------------------------------------------------------------------
   Notes
   ------------------------------------------------------------------------ */

/* ------------------------------------------------------------------------
   Defines and Compile Flags
   ------------------------------------------------------------------------ */
#define TEAM_SPACING	2
#define FIRST_TEAM_SPACING	4
#define SPLASH_DELAY	9						// in ticks (18.2 ticks per second)
/* ------------------------------------------------------------------------
   Macros
   ------------------------------------------------------------------------ */

/* ------------------------------------------------------------------------
   Prototypes
   ------------------------------------------------------------------------ */

/* ------------------------------------------------------------------------
   Global Variables
   ------------------------------------------------------------------------ */

/* ------------------------------------------------------------------------
   Local Variables
   ------------------------------------------------------------------------ */
BOOL ADVENTURER::fPlayerMoved = FALSE;
SHORT ADVENTURER::fhdlPathPositions = fERROR;
DEFINE_VECTOR_MEMBER_DATA_S(SHORT,ADVENTURER,fAdventurersHdl,MAX_ADVENTURERS) = {
	fERROR, 
	fERROR, 
	fERROR, 
	fERROR};
DEFINE_VECTOR_MEMBER_CLASS(SHORT, ADVENTURER,fAdventurersHdl);
SBYTE ADVENTURER::fAdventurerCount = 0;
LONG ADVENTURER::fTimeLastBump = 0;
LONG ADVENTURER::fTimeLastSplash = 0;
BOOL ADVENTURER::fLavaSoundOn = FALSE;
SHORT ADVENTURER::fLavaSoundID = fERROR;
SBYTE const ADVENTURER::fFirstAdventurerIndex = (MAX_TRAIL_POINTS - 1);
SBYTE ADVENTURER::fNumberOfGoodTrailPts = 0;
SHORT ADVENTURER::fhWhoGetsObjects = fERROR;

static const LONG SoundDelay = 7;
/* ========================================================================
   Function    - mfUpdateAdventureTeam
   Description - drop the bread crumb trail.
   				 Note: The array is stored with the first location at the end
   				       for fast copying.
   Returns     -
   ======================================================================== */
void ADVENTURER::mfUpdateAdventureTeam(PLAYER const * const pPlayer )
{
	SHORT			oldSector;					// add a ker-splash when entering water or acid
		logDebug("ADVENTURER::mfUpdateAdventureTeam begin bump=%d index=%ld sector=%d pos=%ld,%ld,%ld lavaOn=%d lavaSound=%d trailPts=%ld",
			pPlayer->bump,
			pPlayer->BumpIndex,
			pPlayer->currentSector,
			pPlayer->x,
			pPlayer->y,
			pPlayer->z,
			fLavaSoundOn,
			fLavaSoundID,
			fNumberOfGoodTrailPts);

	if (fhdlPathPositions != fERROR)
	{
		// retrieve the path array
		DumbAutoLockArray<ADVENTURER_POSITION> const pPath(fhdlPathPositions);
		
		if(pPath[fFirstAdventurerIndex].mfHasMoved(pPlayer))
		{
			// Keep them from all standing on top of each other.
			if (pPath[fFirstAdventurerIndex - 1].mfCanIMoveHere(&pPath[fFirstAdventurerIndex], pPlayer->w))
			{
				// Move the bread crumb trail along.
				// Note: The memcpy trick only works because we read from the
				//       array in reverse order.
				memcpy(&pPath[0], &pPath[1], ((MAX_TRAIL_POINTS - 1 )* sizeof(ADVENTURER_POSITION)));
				
				// As good points are saved, we could retrace those.
				if (fNumberOfGoodTrailPts < MAX_TRAIL_POINTS)
				{
					fNumberOfGoodTrailPts++;
				}
			}
			oldSector = pPath[fFirstAdventurerIndex].fPlayer.currentSector;
			pPath[fFirstAdventurerIndex].mfUpdatePosition(pPlayer);
			if (pPlayer->z <= sectors[pPlayer->currentSector].fh && IsSplashSector (pPlayer->currentSector))
			{
				if (!IsSplashSector (oldSector))
				{
					// Add an extra delay between the first ker-splash and
					// the water walking sounds.
					logInfo("Adventure splash start oldSector=%d newSector=%d pos=%ld,%ld,%ld trailPts=%ld",
						oldSector,
						pPlayer->currentSector,
						pPlayer->x,
						pPlayer->y,
						pPlayer->z,
						fNumberOfGoodTrailPts);
					fTimeLastSplash = SCENE_MGR::gTick + SPLASH_DELAY;
					AddSndObj (SND_SPLASH1, 0, VOLUME_FULL);
				}
				else if (SCENE_MGR::gTick > SPLASH_DELAY + fTimeLastSplash)
				{
					logDebug("Adventure water-walk sound sector=%d pos=%ld,%ld,%ld nextSplashTick=%lu",
						pPlayer->currentSector,
						pPlayer->x,
						pPlayer->y,
						pPlayer->z,
						fTimeLastSplash);
					fTimeLastSplash = SCENE_MGR::gTick;
					AddSndObj (SND_WALK_ON_WATER1, SND_WALK_ON_WATER_TOTAL, VOLUME_FULL);
				}
			}

			if (pPlayer->z <= sectors[pPlayer->currentSector].fh && IsLavaSector (pPlayer->currentSector))
			{
				// Turn on lava sound if it is not on.
				if (!fLavaSoundOn)
				{
					fLavaSoundID = AddSndObj (SND_LAVA_LOOP1, 0, VOLUME_FULL);
					logInfo("Adventure lava sound start sector=%d soundId=%d pos=%ld,%ld,%ld",
						pPlayer->currentSector,
						fLavaSoundID,
						pPlayer->x,
						pPlayer->y,
						pPlayer->z);
					fLavaSoundOn = TRUE;
				}
			}
			else if (fLavaSoundOn)
			{
				logInfo("Adventure lava sound stop sector=%d soundId=%d pos=%ld,%ld,%ld",
					pPlayer->currentSector,
					fLavaSoundID,
					pPlayer->x,
					pPlayer->y,
					pPlayer->z);
				if (fLavaSoundID != fERROR)
					StopASound (SND_LAVA_LOOP1, fLavaSoundID);
				fLavaSoundOn = FALSE;
				fLavaSoundID = fERROR;
			}
		}

		// [d11-15-96 JPC] Whether player could move or not, he might have run
		// into something, so handle the noises here.
		// GWP Later play the sound for this ArtThing instead of generic noise.
		switch( pPlayer->bump)
		{
		case iOBJECT:
			if (SCENE_MGR::gTick > SoundDelay + fTimeLastBump)
			{
				fTimeLastBump = SCENE_MGR::gTick;
				if (pPlayer->BumpIndex >= 0 &&
					pPlayer->BumpIndex < MAX_THINGS &&
					mythings[pPlayer->BumpIndex].valid == TRUE &&
					GAME_TTYPE::mfIsAvatarType(mythings[pPlayer->BumpIndex].type))
				{
					logDebug("Adventure bump object index=%ld thingType=%ld deadSeq=%d pos=%ld,%ld,%ld",
						pPlayer->BumpIndex,
						mythings[pPlayer->BumpIndex].type,
						CAvatar::mfDeadFlicSeq(pPlayer->BumpIndex),
						pPlayer->x,
						pPlayer->y,
						pPlayer->z);
					if (CAvatar::mfDeadFlicSeq(pPlayer->BumpIndex))
					{
						AddSndObj(SND_BUMP_DEAD_BODY1,SND_BUMP_DEAD_BODY_TOTAL, -1);
					}
					else
					{
						AddSndObj(SND_BUMP_BODY1,SND_BUMP_BODY_TOTAL, -1);
					}
				}
				else
				{
					if (pPlayer->BumpIndex >= MAX_THINGS)
					{
						logWarn("Adventure bump index out of range: bump=%d index=%ld sector=%d pos=%ld,%ld,%ld",
							pPlayer->bump,
							pPlayer->BumpIndex,
							pPlayer->currentSector,
							pPlayer->x,
							pPlayer->y,
							pPlayer->z);
					}
					else if (pPlayer->BumpIndex >= 0 && mythings[pPlayer->BumpIndex].valid != TRUE)
					{
						logWarn("Adventure bump index references invalid thing: bump=%d index=%ld sector=%d pos=%ld,%ld,%ld",
							pPlayer->bump,
							pPlayer->BumpIndex,
							pPlayer->currentSector,
							pPlayer->x,
							pPlayer->y,
							pPlayer->z);
					}
					AddSndObj(SND_HIT_WALL1,SND_HIT_WALL_TOTAL, -1);
				}
			}
			break;
	   // GWP This noise is too anoy'ing
	   // GWP 	case iWALL:
	   // GWP 		if (SCENE_MGR::gTick > SoundDelay + fTimeLastBump)
	   // GWP 		{
	   // GWP 			fTimeLastBump = SCENE_MGR::gTick;
	   // GWP 			AddSndObj(SND_HIT_WALL1,SND_HIT_WALL_TOTAL, -1);
	   // GWP 		}
	   // GWP 		break;
		case iEDGE_OF_WORLD:
			if (SCENE_MGR::gTick > SoundDelay + fTimeLastBump)
			{
					logDebug("Adventure bump edge-of-world sector=%d pos=%ld,%ld,%ld", pPlayer->currentSector, pPlayer->x, pPlayer->y, pPlayer->z);
				fTimeLastBump = SCENE_MGR::gTick;
				AddSndObj(SND_UI_NOT_PERMITTED, 0, -1);
			}
			break;
	   // GWP This noise is too anoy'ing
	   // GWP 	case iSLIDE_ON_WALL:
	   // GWP 		if (SCENE_MGR::gTick > SoundDelay + fTimeLastBump)
	   // GWP 		{
	   // GWP 			fTimeLastBump = SCENE_MGR::gTick;
	   // GWP 			AddSndObj(SND_HIT_WALL1,SND_HIT_WALL_TOTAL, -1);
	   // GWP 		}
	   // GWP 		break;
		case iCEILING:
			// You are too tall.
			if (SCENE_MGR::gTick > SoundDelay + fTimeLastBump)
			{
				logDebug("Adventure bump ceiling sector=%d pos=%ld,%ld,%ld", pPlayer->currentSector, pPlayer->x, pPlayer->y, pPlayer->z);
				fTimeLastBump = SCENE_MGR::gTick;
				AddSndObj(SND_HIT_CEILING1,SND_HIT_CEILING_TOTAL, -1);
			}
			break;
		case iFLOOR:
			// Step too high
			if (SCENE_MGR::gTick > SoundDelay + fTimeLastBump)
			{
				logDebug("Adventure bump floor sector=%d pos=%ld,%ld,%ld", pPlayer->currentSector, pPlayer->x, pPlayer->y, pPlayer->z);
				fTimeLastBump = SCENE_MGR::gTick;
				AddSndObj(SND_JUMP_BUMP1,SND_JUMP_BUMP_TOTAL, -1);
			}
			break;
		}
	}
	logDebug("ADVENTURER::mfUpdateAdventureTeam complete bump=%d sector=%d pos=%ld,%ld,%ld trailPts=%ld lavaOn=%d",
		pPlayer->bump,
		pPlayer->currentSector,
		pPlayer->x,
		pPlayer->y,
		pPlayer->z,
		fNumberOfGoodTrailPts,
		fLavaSoundOn);
}

/* ========================================================================
   Function    - mfInitAdventureTeam
   Description - Initialize the player position array. Called at the beginning
                 of the scene.
   Returns     -
   ======================================================================== */
void ADVENTURER::mfInitAdventureTeam(PLAYER const * const pPlayer)
{
	LONG	spacing = pPlayer->w * 2;
	VECTOR	OffsetBehind;
	VECTOR	OffsetRight;
	VECTOR	OffsetLeft;
	LONG i;
	fPlayerMoved = FALSE;
	fAdventurerCount = 0;
	fTimeLastBump = 0;
	
	fhdlPathPositions = NewBlock(sizeof(ADVENTURER_POSITION) * MAX_TRAIL_POINTS);
	if (fhdlPathPositions == fERROR)
	{
		logError("mfInitAdventureTeam failed to allocate %lu bytes; freeMem=%ld",
			(ULONG)(sizeof(ADVENTURER_POSITION) * MAX_TRAIL_POINTS),
			ReportFreeMem(TRUE));
		return;
	}
	logInfo("mfInitAdventureTeam allocated path handle=%d trailPoints=%d freeMem=%ld",
		fhdlPathPositions,
		MAX_TRAIL_POINTS,
		ReportFreeMem(TRUE));
	DumbAutoLockArray<ADVENTURER_POSITION> const pPath(fhdlPathPositions);
	
	pPath[fFirstAdventurerIndex].mfUpdatePosition(pPlayer);
	OffsetBehind.dx = 0;
	OffsetBehind.dy = -spacing; // Line'em up behind the player.
	Rotate((POINT *)&OffsetBehind, pPlayer->a);
	
	OffsetRight.dx = pPlayer->w;
	OffsetRight.dy = 0;
	Rotate((POINT *)&OffsetRight, pPlayer->a);
		
	OffsetLeft.dx = -pPlayer->w;
	OffsetLeft.dy = 0;
	Rotate((POINT *)&OffsetLeft, pPlayer->a);
		
	// Note: The array is in reverse order.
	for (i = fFirstAdventurerIndex - 1; i >= 0; i--)
	{
		LONG x;
		LONG y;
		
		switch (i % 4)
		{
		case 0:
			x = OffsetRight.dx;
			y = OffsetRight.dy;
			break;
		case 1:
			x = OffsetBehind.dx;
			y = OffsetBehind.dy;
			break;
		case 2:
			x = OffsetLeft.dx;
			y = OffsetLeft.dy;
			break;
		case 3:
			x = OffsetBehind.dx;
			y = OffsetBehind.dy;
			break;
		}
		
		pPath[i].fPlayer.x = pPath[i + 1].fPlayer.x + x;
		pPath[i].fPlayer.y = pPath[i + 1].fPlayer.y + y;
		pPath[i].fPlayer.z = pPath[i + 1].fPlayer.z;
		pPath[i].fPlayer.a = pPath[i + 1].fPlayer.a;
		pPath[i].fPlayer.Crouching = pPath[i + 1].fPlayer.Crouching;
		pPath[i].fPlayer.floor = pPath[i + 1].fPlayer.floor;
		pPath[i].fPlayer.WalkThruWall = pPath[i + 1].fPlayer.WalkThruWall;
		pPath[i].fPlayer.bump = iNOTHING;
		pPath[i].fPlayer.BumpIndex = fERROR;
		pPath[i].fPlayer.currentSector = point_to_sector(pPath[i].fPlayer.x,
		                                   pPath[i].fPlayer.y);
		pPath[i].fPlayer.fallHeight = pPath[i + 1].fPlayer.fallHeight; // [d11-22-96 JPC]
	}
	
	fNumberOfGoodTrailPts = 1;
	
	
	for (i = 0; i < MAX_ADVENTURERS; i++)
	{
		fAdventurersHdl[i] = fERROR;
	}
}

/* ========================================================================
   Function    - mfIsAdventureTeam
   Description - Test a condition of the Adventure team
   Returns     -
   ======================================================================== */
BOOL const ADVENTURER::mfIsAdventureTeam(CAvatar_pmfv pmfv)
{
	BOOL Result = FALSE;
	ADVENTURER_TEAM_ITOR AdvItor;
	
	for (AdvItor = begin();
	     AdvItor != end();
	     AdvItor++)
	{
		CAvatar const * const pAvatar = (CAvatar const * const) BLKPTR(*AdvItor);
		if (pAvatar == NULL)
		{
			logWarn("mfIsAdventureTeam skipping invalid avatar handle=%d", *AdvItor);
			continue;
		}
		if (TRUE == (pAvatar->*pmfv)())
		{
			Result = TRUE;
			break;
		}
	}
	return Result;
}
/* ========================================================================
   Function    - mfFirstAdventurerIs
   Description - To be called to attach the combat camera.
   Returns     -
   ======================================================================== */
// Go thru the adventure team and find the first one under attack.
SHORT const ADVENTURER::mfFirstAdventurerIs(CAvatar_pmfv pmfv)
{
	SHORT Result = fERROR;
	ADVENTURER_TEAM_ITOR AdvItor;

	for (AdvItor = begin();
	     AdvItor != end();
	     AdvItor++)
	{
		CAvatar const * const pAvatar = (CAvatar const * const) BLKPTR(*AdvItor);
		if (pAvatar == NULL)
		{
			logWarn("mfFirstAdventurerIs skipping invalid avatar handle=%d", *AdvItor);
			continue;
		}
		
		if (TRUE == (pAvatar->*pmfv)())
		{
			Result = *AdvItor;
			break;
		}
	}
	
	return Result;
}

/* ========================================================================
   Function    - mfReleaseAdventureTeam
   Description - To be called when the SCENE AI cleans up.
   Returns     -
   ======================================================================== */
void ADVENTURER::mfReleaseAdventureTeam()
{
	LONG i;
	LONG const AdventureCount = fAdventurerCount;
	
	if (fhdlPathPositions != fERROR)
	{
		logInfo("mfReleaseAdventureTeam releasing path handle=%d adventurers=%ld freeMem=%ld",
			fhdlPathPositions,
			AdventureCount,
			ReportFreeMem(TRUE));
		DisposBlock(fhdlPathPositions);
		fhdlPathPositions = fERROR;
	}
	
	for (i = 0; i < MAX_ADVENTURERS; i++)
	{
		fAdventurersHdl[i] = fERROR;
	}
	fAdventurerCount = 0;
	
	fNumberOfGoodTrailPts = 0;
	
	fhWhoGetsObjects = fERROR;

	if (fLavaSoundOn)
	{
		logInfo("mfReleaseAdventureTeam shutting down lava sound id=%d",
			fLavaSoundID);
		if (fLavaSoundID != fERROR)
			StopASound (SND_LAVA_LOOP1, fLavaSoundID);
		fLavaSoundOn = FALSE;
		fLavaSoundID = fERROR;
	}
}

/* ========================================================================
   Function    - mfJoinAdventureTeam
   Description - Add another avatar to the team.
   Returns     -
   ======================================================================== */
BOOL const ADVENTURER::mfJoinAdventureTeam(SHORT const hdlAvatar)
{
	BOOL Result = FALSE;

	if (fhdlPathPositions == fERROR)
	{
		logError("mfJoinAdventureTeam called without valid path positions avatar=%d", hdlAvatar);
		return FALSE;
	}
	
	if (hdlAvatar != fERROR)
	{
		SBYTE i;
		for (i = 0; i < MAX_ADVENTURERS; i++)
		{
			if (fAdventurersHdl[i] == fERROR )
			{
				LONG NewX;
				LONG NewY;
				LONG NewZ;
				LONG NewA;
				
				CAvatar * const pAvatar = (CAvatar * const) BLKPTR(hdlAvatar);
				if (pAvatar == NULL)
				{
					logWarn("mfJoinAdventureTeam received invalid avatar handle=%d", hdlAvatar);
					break;
				}
				
				fhAvatar = hdlAvatar;
				if (i == 0)
				{
					fAdventurerPathIndex = fFirstAdventurerIndex;
					
					// Hack But I don't know where else to put this attachment.
					pAvatar->mfSetMeToThePlayer();
					fhWhoGetsObjects = hdlAvatar;
				}
				else
				{
					fAdventurerPathIndex = (SBYTE)(fFirstAdventurerIndex - (FIRST_TEAM_SPACING + (i * TEAM_SPACING)));
				}
				fAdventurersHdl[i] = hdlAvatar;
				
				
				// give the avatar an initial position.
				mfGetMyPosition(&NewX, &NewY, &NewZ, &NewA);
				pAvatar->mfMoveToXYZA(NewX, NewY, NewZ, NewA);
				logInfo("mfJoinAdventureTeam avatar=%d slot=%d pathIndex=%d pos=%ld,%ld,%ld angle=%ld",
					hdlAvatar,
					i,
					fAdventurerPathIndex,
					NewX,
					NewY,
					NewZ,
					NewA);
				
				fAdventurerCount++;
				
				Result = TRUE;
				break;
			}
		}
	}
	return Result;
}

/* ========================================================================
   Function    - mfFillReversePlayerPts
   Description - To run a retreat, fill the player array with the previous
   				 trail points.
   Returns     -
   ======================================================================== */
void ADVENTURER::mfFillReversePlayerPts(
	PLAYER * const pPlayerPts,
	LONG const NumberOfPts,
	LONG const ThingIndex)
{
	if (fhdlPathPositions != fERROR)
	{
		DumbAutoLockArray<ADVENTURER_POSITION const> const pPosition(fhdlPathPositions);
		LONG i;
		LONG j;
		
		for (j = fFirstAdventurerIndex,i = 0;
			 i < NumberOfPts && j >= 0;
			 i++, j--)
		{
			pPosition[j].mfFillReversePlayerInfo(&pPlayerPts[i], ThingIndex);
		}
	}
}

/* ========================================================================
   Function    - mfSwapPlaces
   Description - Switch positions in line.
   Returns     -
   ======================================================================== */
void ADVENTURER::mfSwapPlaces(
	ADVENTURER & const  rAdventurer )
{
	SBYTE const OldPosition = fAdventurerPathIndex;
	
	fAdventurerPathIndex = rAdventurer.fAdventurerPathIndex;
	rAdventurer.fAdventurerPathIndex = OldPosition;
	
	// Now reorder us in the Adventure array.
	ADVENTURER_TEAM_ITOR AdvItor;
	for (AdvItor = begin();
	     AdvItor != end();
	     AdvItor++)
	{
		if (*AdvItor == fhAvatar)
		{
			*AdvItor = rAdventurer.fhAvatar;
		}
		else
		if (*AdvItor == rAdventurer.fhAvatar)
		{
			*AdvItor = fhAvatar;
		}
	}
}

/* ========================================================================
   Function    - mfDoesAdventureTeamHave
   Description - Search the inventories of the adventurers for a object of type.
   Returns     - TRUE | FALSE
   ======================================================================== */
static BOOL const ADVENTURER::mfDoesAdventureTeamHave(THINGTYPE const ThingType)
{
	BOOL Result = FALSE;
	
	ADVENTURER_TEAM_ITOR AdvItor;
	
	for (AdvItor = begin();
	     AdvItor != end();
	     AdvItor++)
	{
		CAvatar const * const  pAvatar = (CAvatar const * const) BLKPTR(*AdvItor);
		if (pAvatar == NULL)
		{
			logWarn("mfDoesAdventureTeamHave encountered invalid avatar handle=%d", *AdvItor);
			continue;
		}
		
		if (!pAvatar->mfAmIImmoblized() && pAvatar->hPlayerStats != fERROR)
		{
			DumbAutoLockPtr<PLAYER_STATS> const pPlayerStats(pAvatar->hPlayerStats);
			if (pPlayerStats->Inventory.mfDoIHaveItem(ThingType))
			{
				Result = TRUE;
				break;
			}
		}
	}
	
	return Result;
}
/* ========================================================================
   Function    - mfDoToAllAdventurers
   Description - Execute the CAvatar member fn on all the adventurers.
   Returns     -
   ======================================================================== */

void ADVENTURER::mfDoToAllAdventurers(CAvatar_pmf pmf)
{
	ADVENTURER_TEAM_ITOR AdvItor;
	
	for (AdvItor = begin();
	     AdvItor != end();
	     AdvItor++)
	{
		CAvatar * const  pAvatar = (CAvatar * const) BLKPTR(*AdvItor);
		if (pAvatar == NULL)
		{
			logWarn("mfDoToAllAdventurers encountered invalid avatar handle=%d", *AdvItor);
			continue;
		}
		(pAvatar->*pmf)();
	}
}
