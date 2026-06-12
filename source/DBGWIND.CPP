/* ========================================================================
	File		- DBGWIND.CPP
	Description - Debug test window and associated debug action helpers.
				  Compiled only when _DEBUG is defined.  On Windows builds
				  a modal pop-up window lets developers trigger in-game test
				  scenarios (grant items, trigger assassinations, show
				  end-of-adventure screens) without modifying saved state or
				  recompiling.  On non-Windows builds the public entry point
				  is a no-op stub.
	======================================================================== */

#ifdef _WINDOWS
#include <windows.h>
#endif

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "adventur.hxx"
#include "avatar.hxx"
#include "combatui.hxx"
#include "dbgwind.hxx"
#include "game.h"
#include "gamemap.hxx"
#include "gametype.hxx"
#include "invntory.hxx"
#include "logger.h"
#include "memmanag.h"
#include "playstat.hxx"
#include "scene.hxx"
#include "scnmgr.hxx"
#include "strmgr.h"
#include "things.h"
#include "thingtyp.h"
#include "tmsgbox.hxx"

#ifdef _WINDOWS
/* Main application window handle; defined in the platform layer. */
extern HWND hwndApp;
#endif

/* Displays the victory screen shown when the player picks up the quest item
   in an adventure.  Defined in ADVENTUR.CPP / COMBATUI area. */
extern void ShowQuestItemVictoryScreen(void);

#if defined(_DEBUG)

/* ========================================================================
	Enum		- DEBUG_TEST_ACTION
	Description - Identifies which test action was selected by the developer
				  in the debug test window.  The window stores the result in
				  a file-static variable and the modal message loop reads it
				  after the window is destroyed.
	======================================================================== */
enum DEBUG_TEST_ACTION
{
	/* No action was chosen (window was closed without a selection). */
	DEBUG_TEST_ACTION_NONE = 0,

	/* Force an NPC assassination event against one of the player's realm units. */
	DEBUG_TEST_ACTION_ASSASSINATE_REALM_UNIT,

	/* Grant a named inventory item to every adventurer in the current party. */
	DEBUG_TEST_ACTION_GRANT_ITEM,

	/* Trigger the end-of-adventure quest-item victory screen. */
	DEBUG_TEST_ACTION_SHOW_ADVENTURE_END,

	/* Mark every non-party avatar in the scene as aware (refresh awareness)
	   so the party will auto-target them without needing prior LOS. */
	DEBUG_TEST_ACTION_SPOT_ALL_ENEMIES,

	/* Clear awareness on every non-party avatar so the party stops
	   auto-targeting enemies it has not seen since the clear. */
	DEBUG_TEST_ACTION_CLEAR_SPOTTED,

	/* Write a per-avatar AI/pathfinding state dump to the log. */
	DEBUG_TEST_ACTION_DUMP_AI_STATE,

	/* Mark all loaded FLC animation art purgable and force a memory purge,
	   simulating the long-session memory pressure behind issue #4. */
	DEBUG_TEST_ACTION_PURGE_ANIM_ART
};

/* ========================================================================
	Function	- DebugNormalizeToken
	Description - Converts a raw string into a canonical comparison token by
				  upper-casing every character and stripping whitespace,
				  underscores, and hyphens.  Used so that item name lookups
				  are insensitive to spacing and punctuation differences
				  between user input and stored identifiers.
	Parameters	- cpSource  : null-terminated source string to normalise.
				  cpDest    : caller-supplied buffer that receives the result.
				  maxLen    : capacity of cpDest in bytes, including the null
				              terminator.  If <= 0 the function returns
				              immediately without writing anything.
	Returns		- (void)
	======================================================================== */
static void DebugNormalizeToken(const char *cpSource, char *cpDest, LONG maxLen)
{
	LONG inIndex = 0;
	LONG outIndex = 0;

	if (maxLen <= 0)
		return;

	while (cpSource[inIndex] != '\0' && outIndex < maxLen - 1)
	{
		char c = cpSource[inIndex++];
		if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '_' || c == '-')
			continue;
		cpDest[outIndex++] = (char)toupper((unsigned char)c);
	}

	cpDest[outIndex] = '\0';
}

/* ========================================================================
	Function	- DebugParseThingTypeId
	Description - Attempts to interpret cpSource as a decimal integer and
				  map it to a valid THINGTYPE value in the range
				  [FIRST_GAME_THING, LAST_GAME_THING].  Any trailing
				  non-whitespace characters after the integer cause the
				  parse to fail so that partial matches (e.g. "10abc") are
				  rejected.
	Parameters	- cpSource   : null-terminated string containing the
				               candidate decimal number.  May be NULL.
				  pThingType : receives the parsed THINGTYPE on success.
				               Must not be NULL.
	Returns		- TRUE  : cpSource was a valid integer in range; *pThingType
				          has been set.
				  FALSE : parse failed or value is out of range; *pThingType
				          is unchanged.
	======================================================================== */
static BOOL DebugParseThingTypeId(const char *cpSource, THINGTYPE *pThingType)
{
	char *cpEnd = NULL;
	long value;

	if (cpSource == NULL || cpSource[0] == '\0' || pThingType == NULL)
		return FALSE;

	value = strtol(cpSource, &cpEnd, 10);
	if (cpEnd == cpSource)
		return FALSE;
	if (cpEnd != NULL)
	{
		while (*cpEnd != '\0')
		{
			if (!isspace((unsigned char)*cpEnd))
				return FALSE;
			cpEnd++;
		}
	}
	if (value < FIRST_GAME_THING || value > LAST_GAME_THING)
		return FALSE;

	*pThingType = (THINGTYPE)value;
	return TRUE;
}

/* ========================================================================
	Function	- DebugResolveThingTypeFromItemName
	Description - Resolves a developer-supplied item identifier to a
				  THINGTYPE using a multi-pass strategy:
				    1. Try to parse cpInputName as a raw decimal THINGTYPE id.
				    2. Check hard-coded aliases for items whose names clash
				       with normalised display strings (KEY_WHITE,
				       KEY_SKELETON).
				    3. Query GAME_TTYPE::mfGetThingType() with the normalised
				       token (matches the 6-char art-file token).
				    4. Iterate every pickable THINGTYPE and compare its
				       localised display name (via STRMGR) against the
				       normalised input.  If exactly one match is found it is
				       returned; multiple matches cause an error.
				  Leading whitespace in cpInputName is ignored.
	Parameters	- cpInputName    : developer-entered item identifier; may be
				                   a display name, 6-char token, or decimal id.
				                   NULL or empty is treated as "no input".
				  cpResultReason : optional caller-supplied buffer that
				                   receives a human-readable error description
				                   when NO_THING is returned.  Pass NULL to
				                   suppress.
				  reasonLen      : capacity of cpResultReason in bytes.
	Returns		- The resolved THINGTYPE, or NO_THING on failure.
	======================================================================== */
static THINGTYPE DebugResolveThingTypeFromItemName(const char *cpInputName, char *cpResultReason, LONG reasonLen)
{
	THINGTYPE thingType = NO_THING;
	char normalizedInput[128];
	LONG t;
	LONG matchCount = 0;
	THINGTYPE matchedThingType = NO_THING;

	if (cpResultReason != NULL && reasonLen > 0)
		cpResultReason[0] = '\0';

	if (cpInputName == NULL)
	{
		if (cpResultReason != NULL && reasonLen > 0)
			strncpy(cpResultReason, "No item name entered.", reasonLen - 1);
		return NO_THING;
	}

	while (*cpInputName != '\0' && isspace((unsigned char)*cpInputName))
		cpInputName++;

	if (*cpInputName == '\0')
	{
		if (cpResultReason != NULL && reasonLen > 0)
			strncpy(cpResultReason, "No item name entered.", reasonLen - 1);
		return NO_THING;
	}

	if (DebugParseThingTypeId(cpInputName, &thingType))
		return thingType;

	DebugNormalizeToken(cpInputName, normalizedInput, sizeof(normalizedInput));

	if (strcmp(normalizedInput, "KEYWHITE") == 0 || strcmp(normalizedInput, "ITEMKEYWHITE") == 0)
		return KEY_WHITE;
	if (strcmp(normalizedInput, "KEYSKELETON") == 0 || strcmp(normalizedInput, "ITEMKEYSKELETON") == 0)
		return KEY_SKELETON;

	thingType = GAME_TTYPE::mfGetThingType(normalizedInput);
	if (thingType != NO_THING)
		return thingType;

	for (t = FIRST_GAME_THING; t <= LAST_GAME_THING; ++t)
	{
		char normalizedItemName[128];
		GAME_STRING strId;
		char const *cpItemName;

		if (!GAME_TTYPE::mfCanBePickedUp((THINGTYPE)t))
			continue;

		strId = GAME_TTYPE::mfGetSTRMgrId((THINGTYPE)t);
		if (strId == STR_NULL)
			continue;

		cpItemName = STRMGR_GetStr(strId);
		if (cpItemName == NULL)
			continue;

		DebugNormalizeToken(cpItemName, normalizedItemName, sizeof(normalizedItemName));
		if (strcmp(normalizedInput, normalizedItemName) == 0)
		{
			matchedThingType = (THINGTYPE)t;
			matchCount++;
		}
	}

	if (matchCount == 1)
		return matchedThingType;

	if (cpResultReason != NULL && reasonLen > 0)
	{
		if (matchCount > 1)
		{
			snprintf(cpResultReason, reasonLen,
				"Item name '%s' matched multiple item types. Use a specific THINGTYPE id.",
				cpInputName);
		}
		else
		{
			snprintf(cpResultReason, reasonLen,
				"Could not resolve item name '%s'. Use item display name, 6-char token, or THINGTYPE id.",
				cpInputName);
		}
	}

	return NO_THING;
}

/* ========================================================================
	Function	- DebugShowResult
	Description - Logs a debug result message via logInfo and displays it to
				  the developer in a modal TitledMessageBox.  Centralises
				  all debug feedback so the presentation can be changed in
				  one place.
	Parameters	- cpTitle   : title string for the message box.  If NULL,
				              defaults to "Debug Test".
				  cpMessage : body text for the message box.  If NULL,
				              defaults to "Done.".
	Returns		- (void)
	======================================================================== */
static void DebugShowResult(char const *cpTitle, char const *cpMessage)
{
	if (cpTitle == NULL)
		cpTitle = "Debug Test";
	if (cpMessage == NULL)
		cpMessage = "Done.";

	logInfo("[DEBUG] %s: %s", cpTitle, cpMessage);
	TitledMessageBox::Display(cpTitle, cpMessage);
}

/* ========================================================================
	Function	- DebugHasActiveAdventureContext
	Description - Returns TRUE when the current game state has an active
				  adventure context. This includes standalone
				  GAME_ADVENTURE sessions and realm games that currently
				  have an adventure party in progress.
	Parameters	- (none)
	Returns		- TRUE  : adventure actions can operate on the current state.
				  FALSE : no active adventure context exists.
	======================================================================== */
static BOOL DebugHasActiveAdventureContext(void)
{
	return (master_game_type == GAME_ADVENTURE || ADVENTURER::mfNumberOfAdventurers() > 0);
}

/* ========================================================================
	Function	- DebugIsAdventureTeamMember
	Description - Returns TRUE when hAvatar is a member of the current
				  adventure team (a player character), FALSE for NPCs,
				  monsters, and invalid handles.
	Parameters	- hAvatar : avatar handle to test.
	Returns		- TRUE if the handle belongs to the adventure team.
	======================================================================== */
static BOOL DebugIsAdventureTeamMember(SHORT hAvatar)
{
	if (hAvatar == fERROR)
		return FALSE;

	for (ADVENTURER_TEAM_ITOR advItor = ADVENTURER::begin(); advItor != ADVENTURER::end(); advItor++)
	{
		if (*advItor == hAvatar)
			return TRUE;
	}

	return FALSE;
}

/* ========================================================================
	Function	- DebugAIStatusName
	Description - Maps a CAvatar::AISTATUS value to a short human-readable
				  name for log output.  States not relevant to combat
				  debugging fall through to a numeric fallback handled by
				  the caller (returns NULL).
	Parameters	- status : the avatar's Status field.
	Returns		- Static string name, or NULL if the value is not mapped.
	======================================================================== */
static char const *DebugAIStatusName(LONG status)
{
	switch (status)
	{
	case CAvatar::AI_INIT:      return "INIT";
	case CAvatar::AI_PAUSED:    return "PAUSED";
	case CAvatar::AI_MOVING:    return "MOVING";
	case CAvatar::AI_RUNNING:   return "RUNNING";
	case CAvatar::AI_SEARCH:    return "SEARCH";
	case CAvatar::AI_ATTACK:    return "ATTACK";
	case CAvatar::AI_DEFEND:    return "DEFEND";
	case CAvatar::AI_FALLBACK:  return "FALLBACK";
	case CAvatar::AI_CASTSPELL: return "CASTSPELL";
	case CAvatar::AI_DEAD:      return "DEAD";
	case CAvatar::AI_STONE:     return "STONE";
	default:                    return NULL;
	}
}

/* ========================================================================
	Function	- DebugSetAllEnemiesSpotted
	Description - Sets or clears `awareness` on every non-party avatar
				  in the current scene.  Awareness gates hero auto-targeting:
				  heroes only chase enemies the party is aware of (issue 36).
				  Setting it lets testers exercise pathfinding to enemies
				  around corners without first walking a hero into LOS;
				  clearing it verifies heroes ignore enemies they are unaware of.
	Parameters	- spotted : TRUE refreshes awareness, FALSE clears it.
	Returns		- (void).  Reports the number of avatars changed via
				  DebugShowResult().
	======================================================================== */
static void DebugSetAllEnemiesSpotted(BOOL spotted)
{
	LONG changed = 0;
	char message[256];

	if (SCENE_MGR::hCurrentScene == fERROR)
	{
		DebugShowResult("Debug Test", "No active scene. Enter an adventure first.");
		return;
	}

	PTR_SCENE const pCurrentScene = (PTR_SCENE) BLKPTR(SCENE_MGR::hCurrentScene);
	if (pCurrentScene == NULL)
	{
		DebugShowResult("Debug Test", "Current scene handle is invalid.");
		return;
	}

	for (LONG i = 0; i < MAX_AVATARS; ++i)
	{
		SHORT const hAvatar = pCurrentScene->Avatars[i];
		if (hAvatar == fERROR || DebugIsAdventureTeamMember(hAvatar))
			continue;

		CAvatar * const pAvatar = (CAvatar * const) BLKPTR(hAvatar);
		if (pAvatar == NULL)
			continue;

		if (spotted)
			pAvatar->mfMarkAware();
		else
			pAvatar->mfClearAwareness();
		changed++;
	}

	snprintf(message, sizeof(message),
		"%s awareness on %ld non-party avatar(s).",
		spotted ? "Set" : "Cleared",
		changed);
	DebugShowResult("Debug Test", message);
}

/* ========================================================================
	Function	- DebugDumpAIState
	Description - Writes one logInfo line per avatar in the current scene
				  describing its AI and pathfinding state: thing index, type
				  description, party membership, AI function index, AI
				  status, current enemy handle, sector, position, awareness
				  (aware / seenEnemy), the shared sector-graph path state
				  (waypoint count/index/cached target sector), and the
				  wall-steering angle.
				  Read the output in winbr.log (or DOS.LOG) to diagnose
				  stuck or idle characters.
	Parameters	- (none)
	Returns		- (void).  Reports the number of avatars dumped via
				  DebugShowResult().
	======================================================================== */
static void DebugDumpAIState(void)
{
	LONG dumped = 0;
	char message[128];

	if (SCENE_MGR::hCurrentScene == fERROR)
	{
		DebugShowResult("Debug Test", "No active scene. Enter an adventure first.");
		return;
	}

	PTR_SCENE const pCurrentScene = (PTR_SCENE) BLKPTR(SCENE_MGR::hCurrentScene);
	if (pCurrentScene == NULL)
	{
		DebugShowResult("Debug Test", "Current scene handle is invalid.");
		return;
	}

	logInfo("[DEBUG] ---- AI state dump begin ----");
	for (LONG i = 0; i < MAX_AVATARS; ++i)
	{
		SHORT const hAvatar = pCurrentScene->Avatars[i];
		if (hAvatar == fERROR)
			continue;

		CAvatar * const pAvatar = (CAvatar * const) BLKPTR(hAvatar);
		if (pAvatar == NULL)
			continue;

		char const *cpStatusName = DebugAIStatusName(pAvatar->Status);
		char statusBuffer[16];
		if (cpStatusName == NULL)
		{
			snprintf(statusBuffer, sizeof(statusBuffer), "%d", (int)pAvatar->Status);
			cpStatusName = statusBuffer;
		}

		logInfo("[DEBUG] thing=%ld type=%s party=%d aiFunc=%d status=%s enemy=%d "
			"sector=%ld x=%ld y=%ld aware=%d seenEnemy=%d path(count=%d index=%d targetSector=%ld) dAngle=%ld",
			pAvatar->ThingIndex,
			GAME_TTYPE::mfGetDescription(pAvatar->mfType()),
			(int)DebugIsAdventureTeamMember(hAvatar),
			(int)pAvatar->GetAIFuncIndex(),
			cpStatusName,
			(int)pAvatar->hEnemy,
			pAvatar->mfGetSector(),
			pAvatar->mfX(),
			pAvatar->mfY(),
			(int)pAvatar->mfIsAware(),
			(int)pAvatar->mfHasSeenEnemyRecently(),
			pAvatar->fAiPath.fPathWaypointCount,
			pAvatar->fAiPath.fPathWaypointIndex,
			pAvatar->fAiPath.fPathTargetSector,
			pAvatar->dAngle);
		dumped++;
	}
	logInfo("[DEBUG] ---- AI state dump end (%ld avatars) ----", dumped);

	snprintf(message, sizeof(message),
		"Dumped AI state for %ld avatar(s) to the log.",
		dumped);
	DebugShowResult("Debug Test", message);
}

/* ========================================================================
	Function	- DebugPurgeAnimationArt
	Description - Marks every loaded FLC animation sequence in the current
				  scene purgable (the same MarkOldAnimPurgable path used
				  between fights), then forces the memory manager to flush
				  the purgable blocks by allocating and releasing one block
				  spanning nearly all free-plus-purgable memory.  This
				  reproduces on demand the long-session memory-pressure
				  state behind the issue #4 crash-to-desktop: the next
				  frame render and combat start must then survive flushed
				  animation handles (degrading visuals and logging errors)
				  instead of faulting in decode_frame.
				  PCX-art things are skipped because NextPCXFrame raises
				  fatal_error on flushed art in debug builds, which would
				  mask the behaviour under test.
	Parameters	- (none)
	Returns		- (void)
	======================================================================== */
static void DebugPurgeAnimationArt(void)
{
	LONG marked = 0;
	SHORT iTemp = fERROR;
	ULONG freeMem = 0;
	char message[256];

	if (SCENE_MGR::hCurrentScene == fERROR || mythings == NULL || TTypePtr == NULL)
	{
		DebugShowResult("Debug Test", "No active scene. Enter an adventure first.");
		return;
	}

	for (LONG t = 0; t < MAX_THINGS; ++t)
	{
		if (!mythings[t].valid || mythings[t].iAnim == fERROR)
			continue;

		if ((((TTYPE *)(TTypePtr + (G_TTypeSize * mythings[t].type)))->attrib & ART_TYPE_MASK) != FLC_ART)
			continue;

		for (ULONG seq = ANIMATION0SEQ; seq < MAX_ANIMATIONSEQ; ++seq)
			MarkOldAnimPurgable(mythings[t].iAnim, seq);
		marked++;
	}

	/* Allocating nearly all remaining memory makes PurgeMem_ dispose the
	   blocks just marked purgable, the same way it would mid-session. */
	freeMem = ReportFreeMem(TRUE);
	if (freeMem > 8192)
	{
		iTemp = NewBlock(freeMem - 8192);
		if (iTemp > 0)
			DisposBlock(iTemp);
	}

	logInfo("[DEBUG] Purged FLC animation art for %ld thing(s), freeMem=%lu purgeBlock=%d",
		marked, freeMem, (int)iTemp);

	snprintf(message, sizeof(message),
		"Marked FLC art purgable on %ld thing(s) and %s a memory purge. "
		"Start a fight to exercise stale-animation handling.",
		marked,
		(iTemp > 0) ? "forced" : "FAILED to force");
	DebugShowResult("Debug Test", message);
}

/* ========================================================================
	Function	- DebugGrantAdventureItemByName
	Description - Grants one copy of the named item to every member of the
				  current adventure party.  The function:
				    1. Verifies the game is in adventure mode: either
				       master_game_type == GAME_ADVENTURE (standalone
				       adventure-only game) or an active adventure team
				       exists inside a full realm game (GAME_NORMAL).
				    2. Resolves cpItemName to a THINGTYPE via
				       DebugResolveThingTypeFromItemName().
				    3. Confirms the type is pickable and has an inventory
				       mapping.
				    4. Adds the item to the pickup-priority avatar first
				       (ADVENTURER::mfWhoGetsObjectsPickedUp()), then to
				       every remaining adventurer.
				    5. Reports the number of successful and failed additions
				       via DebugShowResult().
				  If the party does not end up owning the item after the
				  grant attempt (verified via mfDoesAdventureTeamHave()) the
				  result message notes the verification failure.
	Parameters	- cpItemName : developer-entered item identifier forwarded
				               directly to DebugResolveThingTypeFromItemName().
				               May be NULL (treated as empty input).
	Returns		- (void)
	======================================================================== */
static void DebugGrantAdventureItemByName(char const *cpItemName)
{
	THINGTYPE thingType;
	ITEMTYPE itemType;
	SHORT hPickupAvatar;
	LONG granted = 0;
	LONG failed = 0;
	char reason[256];
	char message[512];
	char const *cpDisplayName = NULL;

	if (!DebugHasActiveAdventureContext())
	{
		DebugShowResult("Debug Test", "Grant item only works in adventures.");
		return;
	}

	thingType = DebugResolveThingTypeFromItemName(cpItemName, reason, sizeof(reason));
	if (thingType == NO_THING)
	{
		DebugShowResult("Debug Test", reason);
		return;
	}

	if (!GAME_TTYPE::mfCanBePickedUp(thingType))
	{
		snprintf(message, sizeof(message),
			"THINGTYPE %d cannot be picked up and cannot be added to inventory.",
			thingType);
		DebugShowResult("Debug Test", message);
		return;
	}

	itemType = ObjectList::mfGameTypetoItemType(thingType);
	if (itemType >= MAX_ITEM_TYPES)
	{
		snprintf(message, sizeof(message),
			"THINGTYPE %d has no inventory item mapping.",
			thingType);
		DebugShowResult("Debug Test", message);
		return;
	}

	if (GAME_TTYPE::mfGetSTRMgrId(thingType) != STR_NULL)
		cpDisplayName = STRMGR_GetStr(GAME_TTYPE::mfGetSTRMgrId(thingType));
	if (cpDisplayName == NULL)
		cpDisplayName = GAME_TTYPE::mfGetArtFileName(thingType);

	hPickupAvatar = ADVENTURER::mfWhoGetsObjectsPickedUp();
	if (hPickupAvatar != fERROR)
	{
		CAvatar * const pPickupAvatar = (CAvatar * const)BLKPTR(hPickupAvatar);
		if (pPickupAvatar != NULL && pPickupAvatar->hPlayerStats != fERROR)
		{
			PLAYER_STATS * const pPS = (PLAYER_STATS * const)BLKPTR(pPickupAvatar->hPlayerStats);
			if (pPS != NULL)
			{
				if (pPS->mfGetInventory().mfAddItem(itemType) & ADD_OK)
					granted++;
				else
					failed++;
			}
			else
			{
				failed++;
			}
		}
		else
		{
			failed++;
		}
	}

	for (ADVENTURER_TEAM_ITOR advItor = ADVENTURER::begin(); advItor != ADVENTURER::end(); advItor++)
	{
		SHORT const hAvatar = *advItor;
		CAvatar *pAvatar;
		PLAYER_STATS *pPS;

		if (hAvatar == fERROR || hAvatar == hPickupAvatar)
			continue;

		pAvatar = (CAvatar * const)BLKPTR(hAvatar);
		if (pAvatar == NULL || pAvatar->hPlayerStats == fERROR)
		{
			failed++;
			continue;
		}

		pPS = (PLAYER_STATS * const)BLKPTR(pAvatar->hPlayerStats);
		if (pPS == NULL)
		{
			failed++;
			continue;
		}

		if (pPS->mfGetInventory().mfAddItem(itemType) & ADD_OK)
			granted++;
		else
			failed++;
	}

	if (ADVENTURER::mfDoesAdventureTeamHave(thingType))
	{
		snprintf(message, sizeof(message),
			"Granted '%s' (THINGTYPE %d) to %ld adventurer(s). Failed adds: %ld.",
			cpDisplayName,
			thingType,
			granted,
			failed);
	}
	else
	{
		snprintf(message, sizeof(message),
			"Grant attempted for '%s' (THINGTYPE %d), but party verification failed.",
			cpDisplayName,
			thingType);
	}

	DebugShowResult("Debug Test", message);
}

#ifdef _WINDOWS

/* -----------------------------------------------------------------------
   Win32 child-window control IDs used by the debug test window.
   Values are in the 4100 range to avoid collisions with any standard
   dialog resource IDs used elsewhere in the project.
   ----------------------------------------------------------------------- */
enum
{
	/* Static label at the top of the window. */
	DBGWIND_CTL_LABEL = 4100,

	/* Edit control for entering the item name / id to grant. */
	DBGWIND_CTL_ITEM_EDIT = 4101,

	/* "Grant item" push-button. */
	DBGWIND_CTL_GRANT_BTN = 4102,

	/* "Assassinate random unit" push-button. */
	DBGWIND_CTL_ASSASSINATE_BTN = 4103,

	/* "Show end-of-adventure event" push-button. */
	DBGWIND_CTL_ADVENTURE_END_BTN = 4104,

	/* "Spot all enemies" push-button. */
	DBGWIND_CTL_SPOT_ALL_BTN = 4105,

	/* "Clear spotted flags" push-button. */
	DBGWIND_CTL_CLEAR_SPOTTED_BTN = 4106,

	/* "Dump AI state to log" push-button. */
	DBGWIND_CTL_DUMP_AI_BTN = 4107,

	/* "Purge animation art" push-button. */
	DBGWIND_CTL_PURGE_ANIM_BTN = 4108
};

/* TRUE once "BirpDebugTestWindow" has been successfully registered with
   the Win32 class atom table.  Prevents redundant RegisterClass() calls
   across multiple debug window invocations. */
static BOOL gDebugWindowClassRegistered = FALSE;

/* Holds the action selected by the developer before DestroyWindow() is
   called.  Read by DebugShowWindowAndGetSelection() after the message
   loop exits. */
static DEBUG_TEST_ACTION gSelectedAction = DEBUG_TEST_ACTION_NONE;

/* Holds the item name text captured from DBGWIND_CTL_ITEM_EDIT before
   DestroyWindow() is called. */
static char gSelectedItemName[128];

/* ========================================================================
	Function	- DebugWindowProc
	Description - Win32 window procedure for the "BirpDebugTestWindow"
				  class.  Handles three messages:
				    WM_CREATE  : creates all child controls (static label,
				                 edit box, and three push-buttons).
				    WM_COMMAND : handles button clicks; captures the item
				                 name from the edit control when needed,
				                 writes the selection to gSelectedAction /
				                 gSelectedItemName, then destroys the window
				                 to unblock the message loop in
				                 DebugShowWindowAndGetSelection().
				    WM_CLOSE   : destroys the window (leaves gSelectedAction
				                 as DEBUG_TEST_ACTION_NONE).
				  All other messages are forwarded to DefWindowProc().
	Parameters	- hwnd   : handle to the debug test window.
				  msg    : Win32 message identifier.
				  wParam : message-specific data (word parameter).
				  lParam : message-specific data (long parameter); unused
				           here but accepted to match the WNDPROC signature.
	Returns		- 0 for messages handled internally; result of DefWindowProc
				  for all others.
	======================================================================== */
static LRESULT CALLBACK DebugWindowProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	(void)lParam;

	switch (msg)
	{
		case WM_CREATE:
			CreateWindowEx(0, "STATIC",
				"Please select one of the following test options:",
				WS_CHILD | WS_VISIBLE,
				12, 14, 430, 20,
				hwnd, (HMENU)DBGWIND_CTL_LABEL, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Grant item (adventure only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 46, 220, 24,
				hwnd, (HMENU)DBGWIND_CTL_GRANT_BTN, GetModuleHandle(NULL), NULL);

			CreateWindowEx(WS_EX_CLIENTEDGE, "EDIT",
				"KEY_WHITE",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
				238, 46, 192, 24,
				hwnd, (HMENU)DBGWIND_CTL_ITEM_EDIT, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Assassinate one of your random units (realm only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 84, 418, 24,
				hwnd, (HMENU)DBGWIND_CTL_ASSASSINATE_BTN, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Show end-of-adventure event (adventure only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 122, 418, 24,
				hwnd, (HMENU)DBGWIND_CTL_ADVENTURE_END_BTN, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Spot all enemies - party will auto-target them (adventure only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 160, 418, 24,
				hwnd, (HMENU)DBGWIND_CTL_SPOT_ALL_BTN, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Clear spotted flags - party ignores unseen enemies (adventure only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 198, 418, 24,
				hwnd, (HMENU)DBGWIND_CTL_CLEAR_SPOTTED_BTN, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Dump AI / pathfinding state to log (adventure only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 236, 418, 24,
				hwnd, (HMENU)DBGWIND_CTL_DUMP_AI_BTN, GetModuleHandle(NULL), NULL);

			CreateWindowEx(0, "BUTTON",
				"Purge animation art - simulate low-memory purge (adventure only)",
				WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
				12, 274, 418, 24,
				hwnd, (HMENU)DBGWIND_CTL_PURGE_ANIM_BTN, GetModuleHandle(NULL), NULL);
			return 0;

		case WM_COMMAND:
		{
			WORD const id = LOWORD(wParam);
			if (id == DBGWIND_CTL_GRANT_BTN)
			{
				HWND hEdit = GetDlgItem(hwnd, DBGWIND_CTL_ITEM_EDIT);
				gSelectedAction = DEBUG_TEST_ACTION_GRANT_ITEM;
				if (hEdit != NULL)
					GetWindowText(hEdit, gSelectedItemName, sizeof(gSelectedItemName));
				DestroyWindow(hwnd);
				return 0;
			}
			if (id == DBGWIND_CTL_ASSASSINATE_BTN)
			{
				gSelectedAction = DEBUG_TEST_ACTION_ASSASSINATE_REALM_UNIT;
				DestroyWindow(hwnd);
				return 0;
			}
			if (id == DBGWIND_CTL_ADVENTURE_END_BTN)
			{
				gSelectedAction = DEBUG_TEST_ACTION_SHOW_ADVENTURE_END;
				DestroyWindow(hwnd);
				return 0;
			}
			if (id == DBGWIND_CTL_SPOT_ALL_BTN)
			{
				gSelectedAction = DEBUG_TEST_ACTION_SPOT_ALL_ENEMIES;
				DestroyWindow(hwnd);
				return 0;
			}
			if (id == DBGWIND_CTL_CLEAR_SPOTTED_BTN)
			{
				gSelectedAction = DEBUG_TEST_ACTION_CLEAR_SPOTTED;
				DestroyWindow(hwnd);
				return 0;
			}
			if (id == DBGWIND_CTL_DUMP_AI_BTN)
			{
				gSelectedAction = DEBUG_TEST_ACTION_DUMP_AI_STATE;
				DestroyWindow(hwnd);
				return 0;
			}
			if (id == DBGWIND_CTL_PURGE_ANIM_BTN)
			{
				gSelectedAction = DEBUG_TEST_ACTION_PURGE_ANIM_ART;
				DestroyWindow(hwnd);
				return 0;
			}
			break;
		}

		case WM_CLOSE:
			DestroyWindow(hwnd);
			return 0;
	}

	return DefWindowProc(hwnd, msg, wParam, lParam);
}

/* ========================================================================
	Function	- DebugEnsureWindowClass
	Description - Registers the "BirpDebugTestWindow" Win32 window class on
				  first call.  Subsequent calls return immediately using the
				  gDebugWindowClassRegistered flag to skip redundant
				  RegisterClass() calls (which would otherwise fail with
				  ERROR_CLASS_ALREADY_EXISTS).
	Parameters	- (none)
	Returns		- TRUE  : class is registered and ready for use.
				  FALSE : RegisterClass() failed; error is logged via
				          logError().
	======================================================================== */
static BOOL DebugEnsureWindowClass(void)
{
	WNDCLASS wc;

	if (gDebugWindowClassRegistered)
		return TRUE;

	memset(&wc, 0, sizeof(wc));
	wc.lpfnWndProc = DebugWindowProc;
	wc.hInstance = GetModuleHandle(NULL);
	wc.lpszClassName = "BirpDebugTestWindow";
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
	wc.style = CS_DBLCLKS;

	if (!RegisterClass(&wc))
	{
		logError("DebugShowTestWindow failed to register window class");
		return FALSE;
	}

	gDebugWindowClassRegistered = TRUE;
	return TRUE;
}

/* ========================================================================
	Function	- DebugShowWindowAndGetSelection
	Description - Creates the debug test window as a modal-style overlay
				  (parent disabled while the window is open), centres it over
				  the main game window when hwndApp is available, and runs a
				  dedicated Win32 message loop until the window is destroyed.
				  The parent window (hwndApp) is disabled for the duration to
				  prevent re-entrant input, then re-enabled and focused on
				  return. If hwndApp is unavailable, CreateWindowEx() falls
				  back to default Win32 placement.
				  Uses IsDialogMessage() inside the loop to handle keyboard
				  navigation between controls (Tab, Enter, Escape).
	Parameters	- cpItemName  : caller-supplied buffer that receives the
				                 text entered in DBGWIND_CTL_ITEM_EDIT when
				                 DEBUG_TEST_ACTION_GRANT_ITEM is chosen.
				                 The string is always null-terminated.
				                 Pass NULL to discard the item name.
				  maxItemLen  : capacity of cpItemName in bytes, including
				                the null terminator.  Ignored when
				                cpItemName is NULL.
	Returns		- The DEBUG_TEST_ACTION selected by the developer, or
				  DEBUG_TEST_ACTION_NONE if the window could not be created
				  or was dismissed without a selection.
	======================================================================== */
static DEBUG_TEST_ACTION DebugShowWindowAndGetSelection(char *cpItemName, LONG maxItemLen)
{
	HWND hwndDialog;
	MSG msg;
	DEBUG_TEST_ACTION selectedAction = DEBUG_TEST_ACTION_NONE;
	BOOL fParentEnabled = FALSE;
	LONG x = CW_USEDEFAULT;
	LONG y = CW_USEDEFAULT;
	LONG width = 460;
	LONG height = 360;
	RECT parentRect;

	if (!DebugEnsureWindowClass())
		return DEBUG_TEST_ACTION_NONE;

	gSelectedAction = DEBUG_TEST_ACTION_NONE;
	gSelectedItemName[0] = '\0';

	if (hwndApp != NULL && IsWindow(hwndApp) && GetWindowRect(hwndApp, &parentRect))
	{
		x = parentRect.left + ((parentRect.right - parentRect.left) - width) / 2;
		y = parentRect.top + ((parentRect.bottom - parentRect.top) - height) / 2;
	}

	hwndDialog = CreateWindowEx(
		WS_EX_DLGMODALFRAME,
		"BirpDebugTestWindow",
		"Birthright Preservation Patch Test Window",
		WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
		x,
		y,
		width,
		height,
		hwndApp,
		NULL,
		GetModuleHandle(NULL),
		NULL);

	if (hwndDialog == NULL)
	{
		logError("DebugShowTestWindow failed to create test window");
		return DEBUG_TEST_ACTION_NONE;
	}

	if (hwndApp != NULL && IsWindow(hwndApp) && IsWindowEnabled(hwndApp))
	{
		EnableWindow(hwndApp, FALSE);
		fParentEnabled = TRUE;
	}

	ShowWindow(hwndDialog, SW_SHOW);
	UpdateWindow(hwndDialog);

	while (IsWindow(hwndDialog) && GetMessage(&msg, NULL, 0, 0) > 0)
	{
		if (!IsDialogMessage(hwndDialog, &msg))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
	}

	if (fParentEnabled)
	{
		EnableWindow(hwndApp, TRUE);
		SetFocus(hwndApp);
	}

	selectedAction = gSelectedAction;
	if (cpItemName != NULL && maxItemLen > 0)
	{
		strncpy(cpItemName, gSelectedItemName, maxItemLen - 1);
		cpItemName[maxItemLen - 1] = '\0';
	}

	return selectedAction;
}

#endif

/* ========================================================================
	Function	- DebugShowTestWindow
	Description - Public entry point for the debug test facility.  On
				  Windows _DEBUG builds this displays the modal debug test
				  window via DebugShowWindowAndGetSelection() and dispatches
				  the selected action:
				    GRANT_ITEM             - calls DebugGrantAdventureItemByName()
				                            with the name captured from the edit
				                            control.
				    ASSASSINATE_REALM_UNIT - validates that the game is in realm
				                            mode (no active adventure, battle, or
				                            combat) then calls
				                            DebugTriggerRealmAssassination().
				    SHOW_ADVENTURE_END     - validates that the game is in
				                            an active adventure context
				                            (standalone adventure or realm game
				                            with an adventure party) then calls
				                            ShowQuestItemVictoryScreen().
				  On non-Windows builds, or in non-debug builds, the function
				  is a no-op stub (the non-debug stub is defined below the
				  #endif).
	Parameters	- Two LONG parameters are accepted to match the standard
				  debug-key-handler signature (key code and modifier flags).
				  Both are unused in this function.
	Returns		- (void)
	======================================================================== */
void DebugShowTestWindow(LONG, LONG)
{
#ifdef _WINDOWS
	DEBUG_TEST_ACTION selectedAction;
	char itemName[128];

	itemName[0] = '\0';
	selectedAction = DebugShowWindowAndGetSelection(itemName, sizeof(itemName));

	if (selectedAction == DEBUG_TEST_ACTION_GRANT_ITEM)
	{
		DebugGrantAdventureItemByName(itemName);
	}
	else if (selectedAction == DEBUG_TEST_ACTION_ASSASSINATE_REALM_UNIT)
	{
		if (DebugHasActiveAdventureContext() || master_game_type == GAME_BATTLE || gfInCombat)
		{
			DebugShowResult("Debug Test", "Assassinate option only works in realm.");
		}
		else
		{
			DebugTriggerRealmAssassination(0, 0);
			DebugShowResult("Debug Test", "Triggered random-unit assassination test.");
		}
	}
	else if (selectedAction == DEBUG_TEST_ACTION_SHOW_ADVENTURE_END)
	{
		if (!DebugHasActiveAdventureContext())
		{
			DebugShowResult("Debug Test", "End-of-adventure event only works in adventure.");
		}
		else
		{
			ShowQuestItemVictoryScreen();
			DebugShowResult("Debug Test", "Triggered end-of-adventure event test.");
		}
	}
	else if (selectedAction == DEBUG_TEST_ACTION_SPOT_ALL_ENEMIES)
	{
		DebugSetAllEnemiesSpotted(TRUE);
	}
	else if (selectedAction == DEBUG_TEST_ACTION_CLEAR_SPOTTED)
	{
		DebugSetAllEnemiesSpotted(FALSE);
	}
	else if (selectedAction == DEBUG_TEST_ACTION_DUMP_AI_STATE)
	{
		DebugDumpAIState();
	}
	else if (selectedAction == DEBUG_TEST_ACTION_PURGE_ANIM_ART)
	{
		if (!DebugHasActiveAdventureContext())
		{
			DebugShowResult("Debug Test", "Purge animation art only works in adventures.");
		}
		else
		{
			DebugPurgeAnimationArt();
		}
	}
#else
	logWarn("DebugShowTestWindow is only available on WIN DEBUG builds");
#endif
}

#else

/* ========================================================================
	Function	- DebugShowTestWindow  (non-debug stub)
	Description - No-op stub compiled when _DEBUG is not defined.  Keeps
				  all non-debug translation units from needing conditional
				  compilation around call sites.
	Parameters	- Two LONG parameters to match the debug-key-handler
				  signature.  Both are unused.
	Returns		- (void)
	======================================================================== */
void DebugShowTestWindow(LONG, LONG)
{
}

#endif
