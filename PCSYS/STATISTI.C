/* =®RM250¯======================================================================
   Copyright (c) 1990,1995   Synergistic Software
   All Rights Reserved.
   =======================================================================
   Filename: STATISTI.C  -Handles runtime stats
   Author: Chris Phillips
   ========================================================================
   Contains the following internal functions:

   Contains the following general functions:
   init_statistics       -initializes the statistical variables
   close_statistics      -prints statistics
   ======================================================================== */
/* ------------------------------------------------------------------------
   Includes
   ------------------------------------------------------------------------ */
#include <stdio.h>
#include <stdlib.h>
#include <dos.h>
#include <conio.h>
#include <i86.h>
#include <bios.h>

#include "system.h"
#include "engine.h"
#include "machine.h"


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
LONG before_time;

extern LONG		frames;

extern USHORT	cNumBlkHeads;
extern USHORT	iMaxBlkHeadUsed;


/* =======================================================================
   Function    - init_statistics
   Description - initializes variables to keep track of stats
   Returns     - void
   ======================================================================== */
void init_statistics()
{
	before_time=get_time();
}

/* =======================================================================
   Function    - close_statistics
   Description - reads before stats, generates after stats & prints them all
   Returns     - void
   ======================================================================== */
void close_statistics()
{
	LONG tot_time,tt;
	// ULONG after_memory;

	tt=(LONG)get_time();
	tot_time=(LONG)((LONG)tt-(LONG)before_time);

	if (frames == 0)
	{
		// Just don't blow up printing the statistics.
		frames = 1;
	}

	logInfo("STATISTICS------------------------------------------------------");
	logInfo("TIMER:%ld  FRAMES:%ld   TICK PER:%ld   FPS:%f",tot_time,frames,(LONG)((LONG)tot_time)/((LONG)frames),(float)frames/((float)tot_time/18));
//	logInfo("CAMERA: X:%d Y:%d Z:%d PH:%d A:%d",camera.x,camera.y,camera.z,player.h,camera.a);
	logInfo("MEM HANDLES USED:%d/%d  RES HANDLES USED:%d/%d", iMaxBlkHeadUsed, cNumBlkHeads, iMaxResSlotsUsed, iMaxResSlots);
	logInfo("----------------------------------------------------------------");

}

/* ======================================================================= */
