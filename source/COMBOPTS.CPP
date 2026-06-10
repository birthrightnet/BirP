/* ========================================================================
   Copyright (c) 1990,1996	Synergistic Software
   All Rights Reserved
   ========================================================================
   Filename: combopts.cpp  - Options data for combat.
   Author:   Gary Powell
   
   ========================================================================
   
   Contains the following general functions:

   
   ======================================================================== */

/* ------------------------------------------------------------------------
   Includes
   ------------------------------------------------------------------------ */
#include "system.h"
#include "combopts.hxx"
#include "combatui.hxx"
#include "combcntl.hxx"
#include "gamekey.hxx"
#include "gmenuenm.h"
#include "panel.h"

/* ------------------------------------------------------------------------
   Notes
   ------------------------------------------------------------------------ */

/* ------------------------------------------------------------------------
   Defines and Compile Flags
   ------------------------------------------------------------------------ */
   
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
COMBAT_MODE::MODE	COMBAT_MODE::fMode = COMBAT_MODE::ARCADE;

BOOL RECHECK_OPTIONS::fOptionsChanged = FALSE;

SBYTE COMBAT_ARCADE_SPEED::fSpeed = 10;
SHORT const COMBAT_ARCADE_SPEED::fDelay[MAX_COMBAT_DELAY] = {
	0,	// 0 ticks
	10,
	20,
	50,
	90,
	100,
	125,
	150,
	200,
	250,
};

COMBAT_PLAY::LEVEL COMBAT_PLAY::fLevel = COMBAT_PLAY::MODERATE;

COMBAT_INITIAL_VIEWPT::MODE COMBAT_INITIAL_VIEWPT::fInitialState = COMBAT_INITIAL_VIEWPT::AUTO_POSITION;

/* ========================================================================
   Function    - mfUpDateOptions.
   Description - Change the bar buttons and some of the hot keys.
   Returns     - 
   ======================================================================== */

void RECHECK_OPTIONS::mfUpDateOptions()
{
	KEYSTRUCT oldKey;
	
	if (COMBAT_MODE::mfIsModeRPG() == TRUE)
	{
		replace_key(GAME_KEYS::mfGetKey(GAME_KEYS::COMBAT_DONE), CombatTurnDoneKey, 0, &oldKey);

		SetButtonLabel(D_COMBAT_RPGBOTTOM_BAR, BUTNO_RPG_DONE, COMBAT_STR_DONE, 223);
		// [Issue 36] The BUTNO_RPG_DONE button's click proc is hardwired to CombatTurnDoneKey
		// in GAMEMENU.H.  Restore it explicitly so the RPG button works after an arcade switch.
		SetButtonProc(D_COMBAT_RPGBOTTOM_BAR, BUTNO_RPG_DONE, CombatTurnDoneKey, 0, 0);
	}
	else
	{
		replace_key(GAME_KEYS::mfGetKey(GAME_KEYS::COMBAT_DEFEND), CombatDefendKey, 0, &oldKey);
		replace_key(GAME_KEYS::mfGetKey(GAME_KEYS::COMBAT_DONE), CombatHaltKey, 0, &oldKey);

		SetButtonLabel(D_COMBAT_RPGBOTTOM_BAR, BUTNO_RPG_DONE, COMBAT_STR_HALT, 223);
		// [Issue 36] Repoint the on-screen button's click proc to CombatHaltKey.  Changing only
		// the label and the keyboard key left the button itself still calling CombatTurnDoneKey
		// (its GAMEMENU.H proc), which no-ops in arcade mode -- so clicking "Halt" did nothing
		// but play the button click sound.  This is what makes the button actually halt the party.
		SetButtonProc(D_COMBAT_RPGBOTTOM_BAR, BUTNO_RPG_DONE, CombatHaltKey, 0, 0);
	}
	
	
	CONTROL_PANELS::mfUpdateOptions();
	
	fOptionsChanged = FALSE;
	fUpdatePanels = TRUE;
}
