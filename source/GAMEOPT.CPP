/* ========================================================================
   Copyright (c) 1990,1996	Synergistic Software
   All Rights Reserved
   ========================================================================
   Filename: gameopt.cpp
   Author:   Donald Tsang

   ========================================================================
   Contains the following general functions:
   ========================================================================

   Includes
   ------------------------------------------------------------------------ */

#ifdef _WINDOWS
#include <windows.h>
#endif

#include "system.h"
#include "engine.h"
#include <stdio.h>
#include "typedefs.h"

#include "machint.h"

#include "charsel.hxx"
#include "game.h"
#include "sound.hxx"
#include "listbox.hxx"
#include "menu.h"
#include "panel.h"
#include "combatui.hxx"
#include "combopts.hxx"
#include "battleui.hxx"
#include "margin.hxx"
#include "multimap.hxx"
#include "context.hxx"
#include "logger.h"

/* ------------------------------------------------------------------------
   Defines
   ------------------------------------------------------------------------ */
#define OPTIONSAVEFILE "gameopt.dat"
#define OPTIONVERSION 0x00003103
#define OPTIONVERSION_LEGACY_AUTORES 0x00003102

#define MODE_MASK		0x00FF
#define MODE_CHANGED	0x0100

#define FONT_TITL_40PT  13
#define BUTTON_COUNTDOWN 3

/* ------------------------------------------------------------------------
   Global Variables
   ------------------------------------------------------------------------ */
static LONG		optmenuchoice = 4;  /* starts with Music */
static LONG		twitch = 1;
SHORT		musvol = 6;
static SHORT		oldmusvol = 6;
SHORT		sfxvol = 8;
static SHORT		oldsfxvol = 8;
static SHORT		sfxchan = 8;
static SHORT		selected_screen_size = 1;
static SHORT		combat_speed = 5;
static BOOL		newAutoRes = FALSE;
DIFFICULTY			game_difficulty = DIF_EASY;
DIFFICULTY			battle_difficulty = DIF_EASY;
DIFFICULTY			adventure_difficulty = DIF_EASY;
SPEED				battle_speed = SPD_MEDIUM;
static ENV_SETTING	sfxenv = ENV_OFF;
static BOOL		combat_firstperson_view = FALSE;
BOOL			mundane_descriptions = TRUE;
static BOOL		new_mundane = TRUE;
static LONG		newControlMode = 1;

static SHORT		num_screen_sizes = 6;
static SHORT		resolution_mode_setting = RESOLUTION_MODE_OG;
static SHORT		resolution_preset_setting = RESOLUTION_PRESET_640X480;
static SHORT		resolution_scale_setting = RESOLUTION_SCALE_ASPECT_FIT;
static SHORT		old_resolution_mode_setting = RESOLUTION_MODE_OG;
static SHORT		old_resolution_preset_setting = RESOLUTION_PRESET_640X480;
static SHORT		old_resolution_scale_setting = RESOLUTION_SCALE_ASPECT_FIT;

static SHORT sound_levels[] = {0, 13, 26, 38, 51, 64, 77, 90, 102, 115, 127};

static SHORT plusmin[2];

#ifdef _WINDOWS
static SHORT screen_mode = iGDI;
#else
static SHORT screen_mode = 0;    // 0 - GDI or 1 - DDRAW
#endif

SHORT sitecount[MAX_SITES] = {0};

/* ------------------------------------------------------------------------
   Extern Variables
   ------------------------------------------------------------------------ */

#ifdef _WINDOWS
   extern "C" HWND hwndApp;
	extern "C" LONG lSavedX;
	extern "C" LONG lSavedY;
#endif

extern LONG OptionMenuSize;
extern BOOL fDomainTurn;
extern LONG fControlMode;

extern SHORT gWinningPoints;
extern "C" {
extern BOOL fAIAutoRes;
}
/* ------------------------------------------------------------------------
   Internal Prototypes
   ------------------------------------------------------------------------ */
void WriteOptionSettings(void);

/* ------------------------------------------------------------------------
   Extern Prototypes
   ------------------------------------------------------------------------ */

extern void LoadControlSet(void);
extern void ActivateControlSet(void);

extern "C" {
int InitRedBook(void);
int ShutdownRedBook(void);
int StopRedBook (void);
extern BOOL fMinMemory;
}

static SHORT ClampResolutionMode(SHORT mode)
{
	if (mode < RESOLUTION_MODE_OG || mode > RESOLUTION_MODE_MODERN)
		return RESOLUTION_MODE_OG;

	return mode;
}

static SHORT ClampResolutionPreset(SHORT preset)
{
	if (preset < RESOLUTION_PRESET_640X480 || preset >= RESOLUTION_PRESET_COUNT)
		return RESOLUTION_PRESET_640X480;

	return preset;
}

static SHORT ClampScaleMode(SHORT mode)
{
	if (mode < RESOLUTION_SCALE_ASPECT_FIT || mode > RESOLUTION_SCALE_STRETCH)
		return RESOLUTION_SCALE_ASPECT_FIT;

	return mode;
}

static void ClampResolutionSettings(void)
{
	SHORT oldMode = resolution_mode_setting;
	SHORT oldPreset = resolution_preset_setting;
	SHORT oldScale = resolution_scale_setting;

	resolution_mode_setting = ClampResolutionMode(resolution_mode_setting);
	resolution_preset_setting = ClampResolutionPreset(resolution_preset_setting);
	resolution_scale_setting = ClampScaleMode(resolution_scale_setting);

#if !defined(_WINDOWS)
	resolution_mode_setting = RESOLUTION_MODE_OG;
#endif

	if (resolution_mode_setting == RESOLUTION_MODE_OG)
		resolution_preset_setting = RESOLUTION_PRESET_640X480;

	if (oldMode != resolution_mode_setting ||
		oldPreset != resolution_preset_setting ||
		oldScale != resolution_scale_setting)
	{
		logWarn("ClampResolutionSettings adjusted values: mode %d->%d preset %d->%d scale %d->%d",
			oldMode, resolution_mode_setting,
			oldPreset, resolution_preset_setting,
			oldScale, resolution_scale_setting);
	}
}

static void ApplyRuntimeResolutionSettings(void)
{
	ClampResolutionSettings();
	logInfo("ApplyRuntimeResolutionSettings mode=%d preset=%d scale=%d",
		resolution_mode_setting,
		resolution_preset_setting,
		resolution_scale_setting);

	SetRuntimeResolutionState(resolution_mode_setting, resolution_preset_setting, resolution_scale_setting);
	set_screen_size(MAX_VIEW_WIDTH, MAX_VIEW_HEIGHT);

#ifdef _WINDOWS
	if (sDrawMode == iGDI)
	{
		DefaultMainWindowSize(0);
		ShowWindow(hwndApp, SW_SHOW);
		SetFocus(hwndApp);
		logInfo("ApplyRuntimeResolutionSettings reapplied GDI window size to %ldx%ld",
			gDisplayWidth,
			gDisplayHeight);
	}
#endif

	logInfo("Runtime resolution applied logical=%ldx%ld display=%ldx%ld viewport=%ld,%ld %ldx%ld",
		gLogicalWidth, gLogicalHeight,
		gDisplayWidth, gDisplayHeight,
		gViewportX, gViewportY, gViewportW, gViewportH);
}
/* ------------------------------------------------------------------------
   Code
  ------------------------------------------------------------------------ */
void OptAdjLevel(LONG which, LONG what)
{
    switch(which)
    {
        case OPT_ADJ_GAME_DIF:

#ifdef _WINDOWS
			 if ( !IsMultiPlayer() )
			 {
#endif	
            game_difficulty = (DIFFICULTY) (game_difficulty + what);
            if (game_difficulty > DIF_HARD)
                game_difficulty = DIF_HARD;
            if (game_difficulty < DIF_EASY)
                game_difficulty = DIF_EASY;
#ifdef _WINDOWS
			 }
#endif

            break;
            
        case OPT_ADJ_BATTLE_DIF:
#ifdef _WINDOWS
			 if ( !IsMultiPlayer() )
			 {
#endif	
            battle_difficulty = (DIFFICULTY) (battle_difficulty + what);
            if (battle_difficulty > DIF_HARD)
                battle_difficulty = DIF_HARD;
            if (battle_difficulty < DIF_EASY)
                battle_difficulty = DIF_EASY;
#ifdef _WINDOWS
			 }
#endif
            break;

        case OPT_ADJ_BATTLE_SPEED:
#ifdef _WINDOWS
			 if ( !IsMultiPlayer() )
			 {
#endif	
            battle_speed = (SPEED) (battle_speed + what);
            if (battle_speed > SPD_TURNS)
                battle_speed = SPD_TURNS;
            if (battle_speed < SPD_SLOW)
                battle_speed = SPD_SLOW;
#ifdef _WINDOWS
			 }
#endif
            break;

        case OPT_ADJ_ADVENTURE_DIF:
            adventure_difficulty = (DIFFICULTY) (adventure_difficulty + what);
            if (adventure_difficulty > DIF_HARD)
                adventure_difficulty = DIF_HARD;
            if (adventure_difficulty < DIF_EASY)
                adventure_difficulty = DIF_EASY;
            break;

		case OPT_ADJ_ADVENTURE_MODE:
			twitch = twitch + what;
			if (twitch < 0)
				twitch = 0;
			if (twitch > 1)
				twitch = 1;	
			break;	
			
        case OPT_ADJ_ADVENTURE_SPEED:
            combat_speed += what;
            if (combat_speed > 10)
                combat_speed = 10;
            if (combat_speed < 1)
                combat_speed = 1;
            break;

		case OPT_ADJ_ADVENTURE_VIEW:
			if (what > 0)
				combat_firstperson_view = TRUE;
			else if (what < 0)
				combat_firstperson_view = FALSE;
			break;

        case OPT_ADJ_SOUND_CHANNELS:
            sfxchan += what;
            if (sfxchan > 8)
                sfxchan = 8;
            if (fMinMemory && sfxchan > 4)
            	sfxchan = 4;
            if (sfxchan < 2)
                sfxchan = 2;
            break;

        case OPT_ADJ_SOUND_MUSVOL:
            musvol += what;
            if (musvol > 10)
                musvol = 10;
            if (musvol < 0)
                musvol = 0;
			UISetMusicVolume(musvol);
            break;

        case OPT_ADJ_SOUND_SFXVOL:
            sfxvol += what;
            if (sfxvol > 10)
                sfxvol = 10;
            if (sfxvol < 0)
                sfxvol = 0;
            if (GetGlobalVolume() > 0  &&  sfxvol == 0)       // sounds off
            {
                PauseAllSounds();
            }
            else if (GetGlobalVolume() == 0  &&  sfxvol > 0)  // sounds on
	        {
                ResumePausedSounds();
	        }
	        SetGlobalVolume(sfxvol);
            break;

        case OPT_ADJ_SOUND_ENV:
            sfxenv = (ENV_SETTING) (sfxenv + what);
            if (sfxenv > ENV_ON)
                sfxenv = ENV_ON;
            if (sfxenv < ENV_OFF)
                sfxenv = ENV_OFF;
            break;

		case OPT_ADJ_SCREEN_SIZE:
		    selected_screen_size -= what;		// notice the hack!
		    if (selected_screen_size < 0)
		        selected_screen_size = 0;
		    if (selected_screen_size > 5)
		        selected_screen_size = 5;
		    break;    
		    
		case OPT_ADJ_SCREEN_AUTORES:
			// Auto Resolution is deprecated/disabled; keep state forced off.
			newAutoRes = FALSE;
		    break;

		case OPT_ADJ_SCREEN_RESMODE:
			resolution_mode_setting += what;
			logDebug("Options screen resolution mode adjust delta=%ld requested=%d", what, resolution_mode_setting);
			ApplyRuntimeResolutionSettings();
			break;

		case OPT_ADJ_SCREEN_PRESET:
			resolution_preset_setting += what;
			logDebug("Options screen resolution preset adjust delta=%ld requested=%d", what, resolution_preset_setting);
			ApplyRuntimeResolutionSettings();
			break;

#ifdef _WINDOWS
		case OPT_ADJ_SCREEN_WINDOW:
				screen_mode = iGDI;
			break;
#endif
        		    
        case OPT_ADJ_DESCRIPTIONS:
			new_mundane += what;
			if (new_mundane >= 1)
				new_mundane = TRUE;
			if (new_mundane <= 0)
				new_mundane = FALSE;
			break;	
			
		case OPT_ADJ_CONTROLMODE:
			newControlMode += what;
			if (newControlMode > 2)
				newControlMode = 2;
			if (newControlMode < 0)
				newControlMode = 0;
			break;

        default:
            break;
    }
    return;
}


void OpenOptions   (LONG, LONG)
{
	if ( mouse_button == 2 )
	{
		SystemHelp( STR_MAIN1_HELP_OPTIONS_TITLE, 
					STR_MAIN1_HELP_OPTIONS_TEXT, H_Options, 0, 0 );
	}
    else //---- We need help
	{
		SHORT i;
//		GAMEToggleMainMenu(FALSE,0);
//		RunMenus();

		// initialize the temporary variables for all of the options here
		twitch = (COMBAT_MODE::mfGetMode() == COMBAT_MODE::ARCADE);

		oldmusvol = musvol;
//		musvol = oldmusvol / 12;
   
		if (GetGlobalVolume() != fERROR)
		{
			oldsfxvol = GetGlobalVolume();
			sfxvol = oldsfxvol;
		}
		else
		{
			oldsfxvol = 10;
			sfxvol = 10;
		}
		sfxchan = UserNumSFXPlaying;
		sfxenv = (ENV_SETTING) UIPlayEnvironmentalSounds;
   
		adventure_difficulty = (DIFFICULTY) (COMBAT_PLAY::mfGetCurrValue());
       
		combat_speed	   = 10 - COMBAT_ARCADE_SPEED::mfGetCurrValue();
		battle_speed      = (SPEED)(SPD_TURNS-SpeedLevel);    /* {0,1,2,4} from {4,3,2,1} */
		battle_difficulty = (DIFFICULTY)(3-DifficultyLevel);       /* ditto */
   
		if (GetCombatMenuUp() > 0)
			selected_screen_size = MARGIN_CONTROL::mfGetReductionCount() + 1;
		else     
			selected_screen_size = 0;
       
		newAutoRes = FALSE;
       
		//GEH 6/8 game_difficulty = (DIFFICULTY) (DIF_EASY + gWinningPoints / 100 - 3);
		combat_firstperson_view = COMBAT_INITIAL_VIEWPT::mfIsModeFirstPerson();
   
		//---- GDI or DDRAW
   
#ifdef _WINDOWS
		screen_mode = iGDI;
#else
		screen_mode = 0;
#endif
		new_mundane = mundane_descriptions;
		
		newControlMode = (fControlMode & MODE_MASK);
		resolution_mode_setting = gResolutionMode;
		resolution_preset_setting = gResolutionPreset;
		resolution_scale_setting = gScaleMode;
		old_resolution_mode_setting = resolution_mode_setting;
		old_resolution_preset_setting = resolution_preset_setting;
		old_resolution_scale_setting = resolution_scale_setting;
		ClampResolutionSettings();
		logInfo("OpenOptions captured runtime resolution mode=%d preset=%d scale=%d",
			resolution_mode_setting,
			resolution_preset_setting,
			resolution_scale_setting);
   
		// make sure the values are reasonable by running a null-adjust
		for (i=0; i < OPT_ADJ_COUNT; i++)
			OptAdjLevel(i, 0);
   
		// done initializing...
		plusmin[0] = GetResourceStd ("UI\\I_ADSUBA.PCX", FALSE);
		plusmin[1] = GetResourceStd ("UI\\I_ADSUBB.PCX", FALSE);
   	
       ShowMenu(D_OPTION_MENU);
       return;

   }



}

void OptionCancel  (LONG, LONG)
{
	SHORT MenuId = D_OPTION_MENU;
	SHORT ButtonId = 1;
    
	SetButtonHilight(MenuId, ButtonId, TRUE);
	fUpdatePanels = TRUE;
	RunPanels();
	RunMenus();
	update_screen();
	TickDelay(4);
	SetButtonHilight(MenuId, ButtonId, FALSE);
	fUpdatePanels = TRUE;
	RunPanels();
	RunMenus();
	update_screen();
	TickDelay(4);
	
    del_region(OptAdjLevel, 0);

	resolution_mode_setting = old_resolution_mode_setting;
	resolution_preset_setting = old_resolution_preset_setting;
	resolution_scale_setting = old_resolution_scale_setting;
	logInfo("OptionCancel restoring previous resolution mode=%d preset=%d scale=%d",
		resolution_mode_setting,
		resolution_preset_setting,
		resolution_scale_setting);
	ApplyRuntimeResolutionSettings();

    if (musvol > 0  &&  oldsfxvol == 0)       // sounds off
    {
        PauseAllSounds();
    }
    else if (musvol == 0  &&  oldsfxvol > 0)  // sounds on
    {
        ResumePausedSounds();
    }

// Let's use musvol as an index into a volume array in redbook.c
    UISetMusicVolume(oldmusvol );
//   UISetMusicVolume(sound_levels[oldmusvol] );
    musvol = oldmusvol;

    SetGlobalVolume(oldsfxvol);
    sfxvol = oldsfxvol;
	
	if (plusmin[0]!=fERROR) SetPurge(plusmin[0]);
	if (plusmin[1]!=fERROR) SetPurge(plusmin[1]);
    HideMenu(D_OPTION_MENU);
    RunMenus();
//	GAMEToggleMainMenu(TRUE,0);
    return;
}


void UpdateOptionSettings(void)
{
    LONG i;
    
    for (i=0; i < OPT_ADJ_COUNT; i++)
        OptAdjLevel(i, 0);
        
    if (twitch)
        COMBAT_MODE::mfSetMode(COMBAT_MODE::ARCADE);
    else
        COMBAT_MODE::mfSetMode(COMBAT_MODE::RPG);
    
	if (GetGlobalVolume() > 0  &&  sfxvol == 0)       // sounds off
		PauseAllSounds();
	else if (GetGlobalVolume() == 0  &&  sfxvol > 0)  // sounds on
		ResumePausedSounds();
	
	SetGlobalVolume(sfxvol);
    UserCDVolume = musvol * 10;
    UISetMusicVolume(musvol);
    UserNumSFXPlaying = sfxchan;
    UIPlayEnvironmentalSounds = sfxenv;
	COMBAT_ARCADE_SPEED::mfSetNewValue((SBYTE) (10 - combat_speed));
	COMBAT_PLAY::mfSetNewValue((COMBAT_PLAY::LEVEL) adventure_difficulty);
	
	if (combat_firstperson_view)
		COMBAT_INITIAL_VIEWPT::mfSetFirstPersonViewPt();
	else	
		COMBAT_INITIAL_VIEWPT::mfSetAutoPositionMode();
		
    SpeedLevel =  SPD_TURNS - battle_speed;      /* {3,2,1,0} from {0,1,2,3} */
    if ( SpeedLevel == 0 )
    {
		fBtlTurnBased = TRUE;
		fBattleNextTurn = 3;
    }
    else
    {
		fBtlTurnBased = FALSE;
		fBattleNextTurn = 0;
    }
	DifficultyLevel  =  3 - battle_difficulty; /*        ditto         */
	newAutoRes = FALSE;
	fAIAutoRes = FALSE;
    if (selected_screen_size > 0)
    {
        SetCombatMenuUp(TRUE);
        MARGIN_CONTROL::mfSetReductionCount(selected_screen_size - 1);
    }
    else
    {
        SetCombatMenuUp(FALSE);
        MARGIN_CONTROL::mfSetReductionCount(0);
    }


	//---- force GDI presentation mode
#ifdef _WINDOWS
	screen_mode = iGDI;
	ShowWindow(hwndApp, SW_SHOW);
	SetFocus(hwndApp);
#endif

	mundane_descriptions = new_mundane;
	
	if (newControlMode != (fControlMode & MODE_MASK))
		fControlMode = newControlMode|MODE_CHANGED;
	else	
		fControlMode = newControlMode | (fControlMode & MODE_CHANGED);

	ApplyRuntimeResolutionSettings();

	logInfo("UpdateOptionSettings complete mode=%d preset=%d scale=%d screen_mode=%d",
		resolution_mode_setting,
		resolution_preset_setting,
		resolution_scale_setting,
		screen_mode);
	
    gWinningPoints = 300 + (LONG) game_difficulty * 100;

}



void WriteOptionSettings(void)
{
	FILE *fp;
	ULONG ver = OPTIONVERSION;
	if ((fp = fopen(OPTIONSAVEFILE, "wb")) == NULL)
	{
		logWarn("WriteOptionSettings failed to open %s for writing", OPTIONSAVEFILE);
		return;
	}
	
	fwrite(&ver, sizeof(ULONG), 1, fp);
	
	fwrite(&game_difficulty, sizeof(DIFFICULTY), 1, fp);
	fwrite(&battle_difficulty, sizeof(DIFFICULTY), 1, fp);
	fwrite(&battle_speed, sizeof(SPEED), 1, fp);
	fwrite(&adventure_difficulty, sizeof(DIFFICULTY), 1, fp);
	fwrite(&twitch, sizeof(LONG), 1, fp);
	fwrite(&combat_speed, sizeof(SHORT), 1, fp);
	fwrite(&sfxchan, sizeof(SHORT), 1, fp);
	fwrite(&musvol, sizeof(SHORT), 1, fp);
	fwrite(&sfxvol, sizeof(SHORT), 1, fp);
	fwrite(&sfxenv, sizeof(ENV_SETTING), 1, fp);
	fwrite(&selected_screen_size, sizeof(SHORT), 1, fp);
	fwrite(&combat_firstperson_view, sizeof(BOOL), 1, fp);
	fwrite(sitecount, sizeof(SHORT), MAX_SITES, fp);
	fwrite(&screen_mode, sizeof(SHORT), 1, fp);
	fwrite(&mundane_descriptions, sizeof(BOOL), 1, fp);
	fwrite(&resolution_mode_setting, sizeof(SHORT), 1, fp);
	fwrite(&resolution_preset_setting, sizeof(SHORT), 1, fp);
	fwrite(&resolution_scale_setting, sizeof(SHORT), 1, fp);
#ifdef _WINDOWS
	fwrite(&lSavedX, sizeof(LONG), 1, fp);
	fwrite(&lSavedY, sizeof(LONG), 1, fp);
#endif
	fclose(fp);
	logInfo("WriteOptionSettings saved %s mode=%d preset=%d scale=%d screen_mode=%d winPos=%ld,%ld",
		OPTIONSAVEFILE,
		resolution_mode_setting,
		resolution_preset_setting,
		resolution_scale_setting,
		screen_mode,
#ifdef _WINDOWS
		lSavedX,
		lSavedY
#else
		0L,
		0L
#endif
		);
}

extern "C" void WriteOptionSettingsFromC(void)
{
	WriteOptionSettings();
}


void ReadOptionSettings(void)
{
	FILE *fp;
	ULONG ver;
	BOOL migrateLegacyFormat = FALSE;
	
	if ((fp = fopen(OPTIONSAVEFILE, "rb")) == NULL)
	{
		logWarn("ReadOptionSettings missing %s; writing defaults", OPTIONSAVEFILE);
		for (SHORT i=0; i < MAX_SITES; i++)
			sitecount[i] = 0;
			
		UpdateOptionSettings();
		WriteOptionSettings();
		return;
	}
	
	fread(&ver, sizeof(ULONG), 1, fp);
	if (ver != OPTIONVERSION && ver != OPTIONVERSION_LEGACY_AUTORES)
	{
		logWarn("ReadOptionSettings version mismatch in %s: got 0x%08lx expected 0x%08lx or 0x%08lx; resetting file",
			OPTIONSAVEFILE, ver, OPTIONVERSION, OPTIONVERSION_LEGACY_AUTORES);
		fclose(fp);
		remove(OPTIONSAVEFILE);
		for (SHORT i=0; i < MAX_SITES; i++)
			sitecount[i] = 0;
			
		UpdateOptionSettings();
		WriteOptionSettings();
	}
	else
	{
		migrateLegacyFormat = (ver == OPTIONVERSION_LEGACY_AUTORES);
		fread(&game_difficulty, sizeof(DIFFICULTY), 1, fp);
		fread(&battle_difficulty, sizeof(DIFFICULTY), 1, fp);
		fread(&battle_speed, sizeof(SPEED), 1, fp);
		fread(&adventure_difficulty, sizeof(DIFFICULTY), 1, fp);
		fread(&twitch, sizeof(LONG), 1, fp);
		fread(&combat_speed, sizeof(SHORT), 1, fp);
		fread(&sfxchan, sizeof(SHORT), 1, fp);
		fread(&musvol, sizeof(SHORT), 1, fp);
		fread(&sfxvol, sizeof(SHORT), 1, fp);
		oldsfxvol = sfxvol;
		fread(&sfxenv, sizeof(ENV_SETTING), 1, fp);
		fread(&selected_screen_size, sizeof(SHORT), 1, fp);
		if (migrateLegacyFormat)
		{
			BOOL legacyAutoRes;
			fread(&legacyAutoRes, sizeof(BOOL), 1, fp);
			logInfo("ReadOptionSettings legacy format ignored deprecated Auto Resolution value=%d", legacyAutoRes);
		}
		newAutoRes = FALSE;
		fread(&combat_firstperson_view, sizeof(BOOL), 1, fp);
		fread(sitecount, sizeof(SHORT), MAX_SITES, fp);
		fread(&screen_mode, sizeof(SHORT), 1, fp);
		screen_mode = iGDI;
		fread(&mundane_descriptions, sizeof(BOOL), 1, fp);
		fread(&resolution_mode_setting, sizeof(SHORT), 1, fp);
		fread(&resolution_preset_setting, sizeof(SHORT), 1, fp);
		fread(&resolution_scale_setting, sizeof(SHORT), 1, fp);
#ifdef _WINDOWS
		if (fread(&lSavedX, sizeof(LONG), 1, fp) != 1 ||
			fread(&lSavedY, sizeof(LONG), 1, fp) != 1)
		{
			lSavedX = -1;
			lSavedY = -1;
		}
#endif
		new_mundane = mundane_descriptions;
		fclose(fp);
		logInfo("ReadOptionSettings loaded %s ver=0x%08lx mode=%d preset=%d scale=%d screen_mode=%d winPos=%ld,%ld",
			OPTIONSAVEFILE,
			ver,
			resolution_mode_setting,
			resolution_preset_setting,
			resolution_scale_setting,
			screen_mode,
#ifdef _WINDOWS
			lSavedX,
			lSavedY
#else
			0L,
			0L
#endif
			);
	}
	
	UpdateOptionSettings();
	if (migrateLegacyFormat)
	{
		logInfo("ReadOptionSettings migrating legacy options format from 0x%08lx to 0x%08lx",
			OPTIONVERSION_LEGACY_AUTORES,
			OPTIONVERSION);
		WriteOptionSettings();
	}
	return;
}



void OptionDo      (LONG, LONG)
{
	SHORT MenuId = D_OPTION_MENU;
	SHORT ButtonId = 2;
    
	SetButtonHilight(MenuId, ButtonId, TRUE);
	fUpdatePanels = TRUE;
	RunPanels();
	RunMenus();
	update_screen();
	TickDelay(4);
	SetButtonHilight(MenuId, ButtonId, FALSE);
	fUpdatePanels = TRUE;
	RunPanels();
	RunMenus();
	update_screen();
	TickDelay(4);
	
    del_region(OptAdjLevel, 0);
	if (plusmin[0]!=fERROR) SetPurge(plusmin[0]);
	if (plusmin[1]!=fERROR) SetPurge(plusmin[1]);
    HideMenu(D_OPTION_MENU);
    RunMenus();
    
    UpdateOptionSettings();
    WriteOptionSettings();
    
//	GAMEToggleMainMenu(TRUE,0);
    return;
}

void OptionDefaults(LONG MenuCombo, LONG)
{
	SHORT   i;
	SHORT MenuId = D_OPTION_MENU;
	SHORT ButtonId = 3;
    
	SetButtonHilight(MenuId, ButtonId, TRUE);
	fUpdatePanels = TRUE;
	RunPanels();
	RunMenus();
	update_screen();
	TickDelay(4);
	SetButtonHilight(MenuId, ButtonId, FALSE);
	fUpdatePanels = TRUE;
	RunPanels();
	RunMenus();
	update_screen();
	TickDelay(4);
	
    // reset the temporary things to their default values
    twitch = 1;
    combat_speed = 5;
    musvol = 6;
    sfxvol = 8;
    sfxchan = 8;
    sfxenv = ENV_OFF;
    selected_screen_size = 1;
    battle_speed = SPD_MEDIUM;
    battle_difficulty = DIF_EASY;
    adventure_difficulty = DIF_EASY;
    game_difficulty = DIF_EASY;
    newAutoRes = FALSE;
	combat_firstperson_view = FALSE;
    selected_screen_size = 1;
    new_mundane = TRUE;
	resolution_mode_setting = RESOLUTION_MODE_OG;
	resolution_preset_setting = RESOLUTION_PRESET_640X480;
	resolution_scale_setting = RESOLUTION_SCALE_ASPECT_FIT;

    for (i=0; i < OPT_ADJ_COUNT; i++)
        OptAdjLevel(i, 0);

#ifdef _WINDOWS
	screen_mode = iGDI;

#else
   screen_mode = 0;
#endif
	newControlMode = (fControlMode & MODE_MASK);

    return;
}

void OptionRadio1   (LONG MenuCombo, LONG)
{
	LONG	MenuId, ButtonId;
	
	SPLIT_LONG(MenuCombo, MenuId, ButtonId);
	
    optmenuchoice = ButtonId;
    return;
}

void PaintOptionAdj(LONG menu_x, LONG menu_y, SHORT row, OPT_ADJ_TYPE index)
{
	menu_x += 331;
	menu_y += 109 + row*20;
	DrawBitmap(menu_x, menu_y, plusmin[0], 0, 0, 12, 18);
	print_text_centered(menu_x+6, menu_y+9, "-", 173);
	add_region(menu_x, menu_y, 12, 18, 0, OptAdjLevel, index, -1, 0, -1);
			
	menu_x += 13;
	DrawBitmap(menu_x, menu_y, plusmin[0], 0, 0, 12, 18);
	print_text_centered(menu_x+6, menu_y+9, "+", 173);
	add_region(menu_x, menu_y, 12, 18, 0, OptAdjLevel, index, 1, 0, -1);
}


void PaintOptionMenu (LONG MenuCombo, LONG LoadSave)
{
	LONG	i, j, num_buttons;
	LONG	MenuId, ButtonId;
	char	buffer[30];
	LONG    menu_x, menu_y, color;
	(void)j;
	(void)color;
	(void)num_screen_sizes;
	(void)sound_levels;
	
	SPLIT_LONG(MenuCombo, MenuId, ButtonId);

	num_buttons = OptionMenuSize - 1;
	
	if( GetButtonPosition( MenuId, 0, &menu_x, &menu_y ) == fERROR)
	    return;
	
	// paint the background
	init_gfont(FONT_TITL_40PT);
	sprintf(buffer, "^N%s", STRMGR_GetStr(STR_OPT_TITLE));
	print_textf(menu_x + 55, menu_y + 23, 0, buffer);
	
	// set up the buttons
	for(i=1; i <= num_buttons; i++)
	{
	    if (optmenuchoice == i)
	    {
	        SetButtonHilight(MenuId, i, TRUE);
	        //print_text_centered(button_x + button_w/2 - 1,
	        //                    button_y + button_h/2,
	        //                    buffer, BTN_LABEL_HILITE_COLOR);
	    }
	    else
	    {
	        SetButtonHilight(MenuId, i, FALSE);
	        //print_text_centered(button_x + button_w/2,
	        //                    button_y + button_h/2 + 1,
	        //                    buffer, BTN_LABEL_COLOR);
	    }
	}

    init_gfont(FONT_SANS_8PT);
	
    del_region(OptAdjLevel, 0);
	
	
	switch(optmenuchoice)
	{
	case 4:
		gprint_text(menu_x+164, menu_y+81, STRMGR_GetStr(STR_OPT_HDR_GAME), 31);
	    
	    strcpy(buffer, STRMGR_GetStr(STR_OPT_DIF_EASY + (LONG) game_difficulty));
#ifdef _WINDOWS
		if ( IsMultiPlayer() )
			print_textf(menu_x+164, menu_y+110, 13, "%s", STRMGR_GetStr(STR_OPT_GAME_DIF));
		else
#endif	
			print_textf(menu_x+164, menu_y+110, 173, "%s", STRMGR_GetStr(STR_OPT_GAME_DIF));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+110, 173, "%s", buffer);
		
		sprintf(buffer, "%d)", 300 + (LONG) game_difficulty * 100);
		print_textf(menu_x+164, menu_y+130, 173, "(%s", STRMGR_GetStr(STR_OPT_GAME_PTS));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+130, 173, "%s", buffer);
		
	    strcpy(buffer, STRMGR_GetStr(STR_OPT_DESC_ADND + (LONG) new_mundane));
		print_textf(menu_x+164, menu_y+150, 173, "%s", STRMGR_GetStr(STR_OPT_GAME_DESC));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+150, 173, "%s", buffer);
		
	    strcpy(buffer, STRMGR_GetStr(STR_OPT_CTRL_MODE + (LONG) newControlMode));
#ifdef _WINDOWS
		if ( IsMultiPlayer() )
			print_textf(menu_x+164, menu_y+170, 13, "%s", STRMGR_GetStr(STR_OPT_GAME_CTRL));
		else
#endif
		print_textf(menu_x+164, menu_y+170, 173, "%s", STRMGR_GetStr(STR_OPT_GAME_CTRL));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+170, 173, "%s", buffer);
		
#ifdef _WINDOWS
		if ( !IsMultiPlayer() )
#endif
			PaintOptionAdj(menu_x, menu_y, 0, OPT_ADJ_GAME_DIF);
		
		PaintOptionAdj(menu_x, menu_y, 2, OPT_ADJ_DESCRIPTIONS);
		
#ifdef _WINDOWS
		if ( !IsMultiPlayer() )
#endif
			PaintOptionAdj(menu_x, menu_y, 3, OPT_ADJ_CONTROLMODE);
		
		break;
	
	case 5: /* battle settings */
		gprint_text(menu_x+164, menu_y+81, STRMGR_GetStr(STR_OPT_HDR_BATTLE), 31);
		
#ifdef _WINDOWS
		if ( IsMultiPlayer() )
			print_textf(menu_x+164, menu_y+110, 13, "%s", STRMGR_GetStr(STR_OPT_BAT_DIF));
		else
#endif
		print_textf(menu_x+164, menu_y+110, 173, "%s", STRMGR_GetStr(STR_OPT_BAT_DIF));
		strcpy(buffer, STRMGR_GetStr(STR_OPT_DIF_EASY + (LONG) battle_difficulty));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+110, 173, "%s", buffer);
		
#ifdef _WINDOWS
		if ( IsMultiPlayer() )
			print_textf(menu_x+164, menu_y+130, 13, "%s", STRMGR_GetStr(STR_OPT_BAT_SPD));
		else
#endif
		print_textf(menu_x+164, menu_y+130, 173, "%s", STRMGR_GetStr(STR_OPT_BAT_SPD));
		strcpy(buffer, STRMGR_GetStr(STR_OPT_SPD_SLOW + (LONG) battle_speed));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+130, 173, "%s", buffer);
		
#ifdef _WINDOWS
		if ( !IsMultiPlayer() )
#endif
			PaintOptionAdj(menu_x, menu_y, 0, OPT_ADJ_BATTLE_DIF);
		
#ifdef _WINDOWS
		if ( !IsMultiPlayer() )
#endif
			PaintOptionAdj(menu_x, menu_y, 1, OPT_ADJ_BATTLE_SPEED);
		break;
	
	case 6: /* adventure settings */
		gprint_text(menu_x+164, menu_y+81, STRMGR_GetStr(STR_OPT_HDR_ADVENTURE), 31);
		
		print_textf(menu_x+164, menu_y+110, 173, "%s", STRMGR_GetStr(STR_OPT_ADV_DIF));
		strcpy(buffer, STRMGR_GetStr(STR_OPT_DIF_EASY + adventure_difficulty));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+110, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+130, 173, "%s", STRMGR_GetStr(STR_OPT_ADV_MODE));
		strcpy(buffer, STRMGR_GetStr(twitch ? STR_OPT_ADV_ARCADE : STR_OPT_ADV_RPG));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+130, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+150, 173, "%s", STRMGR_GetStr(STR_OPT_ADV_SPD));
		sprintf(buffer, "%d", combat_speed);
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+150, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+170, 173, "%s", STRMGR_GetStr(STR_OPT_ADV_VIEW));
		strcpy(buffer, STRMGR_GetStr(combat_firstperson_view ?
			STR_OPT_ADV_VIEW_FIRST : STR_OPT_ADV_VIEW_AUTO));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+170, 173, "%s", buffer);
		
		PaintOptionAdj(menu_x, menu_y, 0, OPT_ADJ_ADVENTURE_DIF);
		PaintOptionAdj(menu_x, menu_y, 1, OPT_ADJ_ADVENTURE_MODE);
		PaintOptionAdj(menu_x, menu_y, 2, OPT_ADJ_ADVENTURE_SPEED);
		PaintOptionAdj(menu_x, menu_y, 3, OPT_ADJ_ADVENTURE_VIEW);
		
		break;
	
	case 7: /* music & sound settings */
		gprint_text(menu_x+164, menu_y+81, STRMGR_GetStr(STR_OPT_HDR_SOUND), 31);
		
		print_textf(menu_x+164, menu_y+110, 173, "%s", STRMGR_GetStr(STR_OPT_SOUND_CHANNELS));
		sprintf(buffer, "%d", sfxchan);
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+110, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+130, 173, "%s", STRMGR_GetStr(STR_OPT_SOUND_MUSVOL));
		if (musvol == 0)
		    strcpy(buffer, STRMGR_GetStr(STR_OPT_OFF2));
		else
		    sprintf(buffer, "%d", musvol);
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+130, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+150, 173, "%s", STRMGR_GetStr(STR_OPT_SOUND_SFXVOL));
		if (sfxvol == 0)
		    strcpy(buffer, STRMGR_GetStr(STR_OPT_OFF2));
		else
		    sprintf(buffer, "%d", sfxvol);
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+150, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+170, 173, "%s", STRMGR_GetStr(STR_OPT_SOUND_ENV));
		switch(sfxenv)
		{
		case ENV_OFF:
		    strcpy(buffer, STRMGR_GetStr(STR_OPT_SOUND_ENV_OFF));
		    break;
		case ENV_ON:
		    strcpy(buffer, STRMGR_GetStr(STR_OPT_SOUND_ENV_ON));
		    break;
		default:
		    strcpy(buffer, "ERROR!");
		}
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+170, 173, "%s", buffer);
		
		PaintOptionAdj(menu_x, menu_y, 0, OPT_ADJ_SOUND_CHANNELS);
		PaintOptionAdj(menu_x, menu_y, 1, OPT_ADJ_SOUND_MUSVOL);
		PaintOptionAdj(menu_x, menu_y, 2, OPT_ADJ_SOUND_SFXVOL);
		PaintOptionAdj(menu_x, menu_y, 3, OPT_ADJ_SOUND_ENV);
	
		break;
		
	case 8:  /* screen */
		gprint_text(menu_x+164, menu_y+81, STRMGR_GetStr(STR_OPT_HDR_SCREEN), 31);

		print_textf(menu_x+164, menu_y+110, 173, "Resolution Mode");
		if (resolution_mode_setting == RESOLUTION_MODE_MODERN)
			strcpy(buffer, "Modern");
		else
			strcpy(buffer, "OG");
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+110, 173, "%s", buffer);

		print_textf(menu_x+164, menu_y+130, 173, "Resolution Preset");
		switch (resolution_preset_setting)
		{
		case RESOLUTION_PRESET_800X600:
			strcpy(buffer, "800x600");
			break;
		case RESOLUTION_PRESET_1024X768:
			strcpy(buffer, "1024x768");
			break;
		case RESOLUTION_PRESET_1280X960:
			strcpy(buffer, "1280x960");
			break;
		case RESOLUTION_PRESET_1400X1050:
			strcpy(buffer, "1400x1050");
			break;
		case RESOLUTION_PRESET_1600X1200:
			strcpy(buffer, "1600x1200");
			break;
		case RESOLUTION_PRESET_1920X1440:
			strcpy(buffer, "1920x1440");
			break;
		case RESOLUTION_PRESET_640X480:
		default:
			strcpy(buffer, "640x480");
			break;
		}
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+130, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+150, 173, STRMGR_GetStr(STR_OPT_SCREEN_SIZE));
		strcpy(buffer, STRMGR_GetStr(STR_OPT_SCREEN_SIZE_0 + selected_screen_size));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+150, 173, "%s", buffer);
		
#ifdef _WINDOWS
#endif
		
		PaintOptionAdj(menu_x, menu_y, 0, OPT_ADJ_SCREEN_RESMODE);
		PaintOptionAdj(menu_x, menu_y, 1, OPT_ADJ_SCREEN_PRESET);
		PaintOptionAdj(menu_x, menu_y, 2, OPT_ADJ_SCREEN_SIZE);
		
	    break;
	
	case 9:  /* speed */
		gprint_text(menu_x+164, menu_y+81, STRMGR_GetStr(STR_OPT_HDR_SPEED), 31);
		
		print_textf(menu_x+164, menu_y+110, 173, "%s", STRMGR_GetStr(STR_OPT_SOUND_CHANNELS));
		sprintf(buffer, "%d", sfxchan);
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+110, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+130, 173, "%s", STRMGR_GetStr(STR_OPT_SOUND_ENV));
		switch(sfxenv)
		{
		case ENV_OFF:
		    strcpy(buffer, STRMGR_GetStr(STR_OPT_SOUND_ENV_OFF));
		    break;
		case ENV_ON:
		    strcpy(buffer, STRMGR_GetStr(STR_OPT_SOUND_ENV_ON));
		    break;
		default:
		    strcpy(buffer, "ERROR!");
		}
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+130, 173, "%s", buffer);
		
		print_textf(menu_x+164, menu_y+150, 173, STRMGR_GetStr(STR_OPT_SCREEN_SIZE));
		strcpy(buffer, STRMGR_GetStr(STR_OPT_SCREEN_SIZE_0 + selected_screen_size));
		print_textf(menu_x+324 - gtext_width(buffer), menu_y+150, 173, "%s", buffer);
		
		PaintOptionAdj(menu_x, menu_y, 0, OPT_ADJ_SOUND_CHANNELS);
		PaintOptionAdj(menu_x, menu_y, 1, OPT_ADJ_SOUND_ENV);
		PaintOptionAdj(menu_x, menu_y, 2, OPT_ADJ_SCREEN_SIZE);
	
	default:
	    break;
	}
}
