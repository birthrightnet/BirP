#include "system.h"
#include "sysint.h"
#include "engine.h"
#include "engint.h"
#include "machine.h"
#include "machint.h"
#include "Main.hxx"
#include "light.h"
#include "sincos.h"
#include "soundfx.hxx"
#include "sound.hxx"

void SpinOutBitmap (SHORT x, SHORT y, SHORT iBitm, SHORT bx, SHORT by, SHORT w, SHORT h,SHORT hDest, POINT start, POINT bck, SHORT bckw, SHORT bckh)
{
	if (iBitm==fERROR)
		return;

	BITMPTR pBitm=(BITMPTR)BLKPTR(iBitm);
	long CenterX=x+pBitm->w/2;
	long Width=pBitm->w;
	 
	
	// [issue #102] Use the short menu-zoom whoosh, matching every other menu
	// (see MENU.C SND_UI_MENU_ZOOM_OUT). The old SND_INTRO_VOX1 was a leftover
	// intro-voiceover clip ("renamed sound.... gotta fix it") that was far too
	// long for a menu open/close.
	AddSndObj(SND_UI_MENU_ZOOM_OUT,0,VOLUME_EIGHTY);

	// spin out a menu
	for (LONG i=0;i<63;i+=6)
	{
		double Scale=((double)1024.0)/cos_table[i];

		SHORT ScaledWidth=Width/Scale;
		SHORT TopLeftX=CenterX-ScaledWidth/2;

		if(hDest != fERROR)
			DrawBitmap (bck.x, bck.y, hDest, 0, 0, bckw, bckh);
		
		ScaleBitmapX(TopLeftX,y,iBitm, bx, by, w, h, (SHORT)(FULL_SCALE*Scale));
  	
		update_screen();
		DirectDrawPreFrame();
		run_timers();
	}
	if(hDest != fERROR)
		DrawBitmap (bck.x, bck.y, hDest, 0, 0, bckw, bckh);

	update_screen();
	DirectDrawPreFrame();
}	


void SpinInBitmap (SHORT x, SHORT y, SHORT iBitm, SHORT bx, SHORT by, SHORT w, SHORT h,SHORT hDest, POINT start, POINT bck, SHORT bckw, SHORT bckh)
{
 
	if (iBitm==fERROR)
		return;

	BITMPTR pBitm=(BITMPTR)BLKPTR(iBitm);
	long CenterX=x+pBitm->w/2;
	long Width=pBitm->w;


	// spin in a menu
	for (LONG i=63;i>=0;i-=6)
	{
		double Scale=((double)1024.0)/cos_table[i];
		SHORT ScaledWidth=Width/Scale;
		SHORT TopLeftX;

		if (ScaledWidth>Width)
		{
			//we don't want it to be bigger than the actual art!
			Scale=1;
			ScaledWidth=Width;
		}

		TopLeftX=CenterX-ScaledWidth/2;

		if(hDest != fERROR)
			DrawBitmap (bck.x, bck.y, hDest, 0, 0, bckw, bckh);
		
		ScaleBitmapX(TopLeftX,y,iBitm, bx, by, w, h, (SHORT)(FULL_SCALE*Scale));
  	
		update_screen();
		DirectDrawPreFrame();
		run_timers();
	}
	// [issue #102] Do NOT kill all sounds here. SpinInBitmap runs only for the
	// D_SPIN menus (the avatar status and inventory screens), so this blanket
	// KillSoundsNoFade() was stopping the background (adventure/realm) music every
	// time the player opened a character sheet, and nothing restarted it until the
	// next combat. Removing it lets the streamed music keep playing during the
	// spin-in animation. (The spin loop above calls run_timers(), which services
	// the audio timer, so the music is not starved.)
	// KillSoundsNoFade();
	// [issue #102] Use the short menu-zoom whoosh, matching every other menu
	// (see MENU.C SND_UI_MENU_ZOOM_IN). The old SND_INTRO_VOX2 was a leftover
	// intro-voiceover clip ("renamed sound.... gotta fix it") that was far too
	// long for a menu open.
	AddSndObj(SND_UI_MENU_ZOOM_IN,0,VOLUME_EIGHTY);

}


void ScrollOpenBitmap (SHORT x, SHORT y, SHORT iBitm, SHORT bx, SHORT by, SHORT w, SHORT h,SHORT hDest, POINT start, POINT bck, SHORT bckw, SHORT bckh)
{
 
	if (iBitm==fERROR)
		return;

	BITMPTR pBitm=(BITMPTR)BLKPTR(iBitm);
	long Height=pBitm->h;
	long CenterY=y+Height/2;
	
	LONG HalfHeight=Height/2;
	LONG i=HalfHeight;
	
	while(i)
	{
		DrawBitmap (x,y+i,hDest,0,i,1000,HalfHeight-i);
		update_screen();
		i--;
	}
}

void ScrollClosedBitmap (SHORT x, SHORT y, SHORT iBitm, SHORT bx, SHORT by, SHORT w, SHORT h,SHORT hDest, POINT start, POINT bck, SHORT bckw, SHORT bckh)
{
}
