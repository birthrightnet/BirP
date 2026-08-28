Birthright: The Gorgons Alliance Preservation Patch
Version: 1.4.2.0
Date: 2026-09-06

TABLE OF CONTENTS

[1] HOW TO INSTALL THE PATCH
[2] WHAT THE PATCH FIXES / CHANGES
[3] ADDITIONAL INFORMATION
[4] IF YOU STILL EXPERIENCE PROBLEMS

[1] HOW TO INSTALL THE PATCH
============================
This ZIP archive requires manual installation. It is not recommended for new
players. Instead, please download the latest installer from ModDB for a
simplified installation experience.

If you'd like to continue with a manual installation, follow the instructions
below.

It is recommended to start with a fresh installation to reduce any potential
problems with overwriting files. These instructions focus only on getting the
basic game going. For information on the Character Editor, Scenario Editor, or
multiplayer, please see https://www.kiranwelle.com/birthright/

Things you need:

 * A Birthright: The Gorgon's Alliance CD or an ISO image of the CD.
 * Last official Patch 1.4 to update the game to the latest version.
 * 7-zip to extract the game files from the 1.4 patch. This is necessary for
   operating systems newer than Windows ME.

Steps to install:

1. Insert the CD into the CD-ROM drive or mount the ISO image of the CD by
   double-clicking it.
2. Create a folder named BIRTHRT in the root of the C drive.
3. Copy all the files from the CD to the BIRTHRT folder.
4. Extract the contents of Patch 1.4.
5. patch.exe is an installer file that will not run on Windows 10 or 11.
   Instead, use 7-zip to extract all the files from the executable.
   You'll likely see a warning that the file could not be opened as a [PE]
   archive and was opened as a [zip] archive instead. This is fine and doesn't
   require any action.
6. Move the resulting files from the last two steps to the BIRTHRT folder.
7. Extract the contents of the Preservation Patch into the BIRTHRT folder.
8. Open BRSETUP.CFG in a text editor and add the following lines to the end:

[CD_BYPASS]
1

9. Double-click WINBR.EXE to start the game in Windows or run NOVA.EXE in DOS.
   Run CHARED.EXE to start the Character Editor

[2] WHAT THE PATCH FIXES / CHANGES
==================================

1.4.2 - 2026-09-06

Added

- Added a "Halt" button during adventure combat that sets all party members to defend. (#36)
- Added "awareness" system: characters gain awareness for 30 seconds for any other character they see, and can pathfind to them even if they lose sight of them.
- Added several new pathfinding algorithms that allow characters to path between rooms, around obstacles, etc, which has significantly reduced instances of "unable to engage" and characters stuck in walls. (#36)
- Added an Issue Reporting tool. Double-click BirP-Issue-Report.bat in your game folder to bundle up diagnostic files (your game and Windows versions, install path, and log/config files) into a single .zip you can attach to a bug report. (#104)
- Added mouse wheel support in Windows. Scroll the wheel to zoom the realm map and the battlefield in and out, and to scroll or page the inventory list, the save/load list, and action province lists. (#16)
- Added a "Pause When Inactive" option on the Screen tab of the options screen (Windows). Turn it off to keep the game running while you are in another program. It is on by default, which is how the game has always behaved. (#131)

Changed

- Player characters start each fight in a sensible default fighting style for their class, remember the style you last chose, and resume using it against nearby enemies once their current target dies. (#36) (#53)
- Party members give up a chase after 15 seconds (#36)
- Lieutenant action realm button now highlights during lieutenant action, and cancelling a lieutenant realm sub-action no longer cancels the lieutenant action. (#21)
- Halved the delay before an adventure returns to exploration after combat ends. (#14)
- Improved adventure combat messages: attacks now name the target and its armor class, and chases show which enemy is being pursued.
- The game now remembers your magic users' prepared spells and every party member's hotbar layout between adventures, so you don't have to set them up each time. (#24)
- When you and an ally are both in a province with a shared enemy, your own troops now attack first. (#38)
- Assassination reports now include the assassinated unit type, so you can see what you lost. (#33)
- The installer now offers two clear choices, Install and Patch, and finds things for you. Install searches your drives for the Birthright CD or USB stick and fills in the location, so you don't have to hunt for the path. Patch looks for an existing install in the usual places. Both always apply the official 1.4 patch and the latest Preservation Patch, so either way you end up fully up to date. (#89) (#122)
- Uninstalling is now safer. It always shows exactly which folder it will remove and asks first, and it refuses obviously wrong targets such as a drive root or a system folder. It also clears out the crash dumps and memory reports the game leaves behind, and you still choose whether to keep your saved games and settings. (#89) (#122)
- Each character can now carry 30 different kinds of thing, up from 20. There was never a limit on how many of each you carry, so the old limit only ever showed up as shuffling loot onto party members who were already full. Spells, realm spells, blood abilities and anything with charges still don't count towards it. Your saved games are unaffected. (#60)

Fixed

- Hostile spells can no longer hit your own party. Magic missile and lightning bolt pass through your characters instead of striking them, and a spellcaster can no longer lock on to a friend. Area spells can still catch your own party in the blast. (#36)
- Characters can no longer attack through walls; they must have line of sight. Spectres and wraiths still phase through walls by design. (#36)
- Party members no longer chase enemies onto lava, acid, or deep water. (#36)
- Fixed some crashes that could occur during two-part adventures. (#52)
- Hardened an adventure crash point so missing visuals are skipped instead of crashing the game to the desktop. (#4)
- Fixed a DOS crash caused by an over-long message being written to the log file. (#57)
- Fixed background music cutting out (until the next fight) when you open a character's Status or Inventory screen during an adventure. The music now keeps playing. (#102)
- Fixed rebelling provinces still collecting tax. A province in rebellion now earns no tax or regency until the rebellion is dealt with. (#76)
- Fixed domain actions with a very high chance of success sometimes always failing instead of nearly always succeeding. (#70)
- Fixed a defeated regent or lieutenant with nowhere to retreat getting stuck on the realm map, where it could not be fought and blocked your own troops from leaving the province. Affected saved games are repaired when you load them. (#78) (#90)
- Fixed the battle victory screen listing an enemy regent among the dead when they actually got away. A regent you beat in a manual battle escapes to a neighboring province, so the screen now says they escaped instead of counting them as killed. (#78) (#90)
- Fixed law claims being lost when loading a saved game; the provinces you had law claims against are now restored. (#11)
- Fixed a bug where the music could loop every second once your PC had been running for about 25 days without a restart. (#117)
- Fixed the game crashing when you start a new game from inside an adventure. Choosing Battles Only, a Tutorial, or a Realm Game from the game menu now finishes leaving the adventure before it builds the new game. This also fixes starting an Expert game that way leaving you on the realm map with no window down the left side, so you could click provinces but never see a regent or a way to begin playing. (#12) (#13) (#31)
- Fixed the game crashing when you choose Adventures Only while an Adventures Only game is already running. The adventure site screen now comes back with a readable party. (#9)
- Fixed the battle report in Battles Only naming the wrong enemy. Every lesson congratulated you on beating the forces of Ghoere, whoever you actually fought, so winning the last lesson against the Gorgon credited you with beating Ghoere. Lessons led by a named enemy now name that enemy's realm and fight in its colours. (#55)
- Fixed your Adventures Only progress being read back scrambled. The file that remembers which sites you have seen and which practice adventurers are alive could corrupt itself depending on which characters you rolled, which could leave the site screen pointing at a site that isn't there. Progress that was never affected still loads, and a damaged file is now thrown away and rebuilt instead of used. (#133)
- Fixed pressing A on the Begin New Game menu doing nothing. It now starts Adventures Only, the way every other underlined letter on that menu starts what it sits next to. (#54)

1.4.1

Added

- Added "modern mode" in-game resolution options with support for `800x600`, `1024x768`, `1280x960`, `1400x1050`, `1600x1200`, and `1920x1440`. The original "OG mode" remains available. (#6)

Removed

- Removed DirectDraw as a supported display mode and removed related options and hotkeys; GDI is now the only supported rendering path. (#6)
- Removed the deprecated `Auto Resolution` graphics option. (#6)

Fixed

- Reduced random Adventure Mode crash opportunities by adding defensive validity checks across adventure avatar/team, AI follow/combat, and spell effect handling. (#4)
- Fixed auto-battle resolution so regents and lieutenants on the overwhelmingly stronger side are no longer valid casualties unless they are dueling an opposing regent or lieutenant. (#19)
- Fixed music startup and resume behavior in main menu and adventures so music no longer waits until after first combat and recovers more reliably after suspend/resume. (#10)
- Fixed issue where adventure music would not resume after finding quest item (#35)
- Fixed release startup CD bypass handling so explicit `BRSETUP.CFG` bypass settings are honored.
- Fixed DOS audio driver fallback parsing so invalid or missing `audioDrv` entries no longer force silent output.
- Fixed spell learning from tomes so newly learned adventure spells are inserted in proper level order in Prepare Magic lists instead of being appended at the end. (#25)
- Fixed two inventory quantity corruption paths that could incorrectly add dozens of consumable items. (#27)
- Hardened battle AI enemy/leader handle checks to prevent rare tactical battle crashes caused by stale references. (#4)
- Fixed an uncommon fatal end-of-turn crash (`units[-1]`). (#30)

1.4.0.4 - 2025-11-02

Changed

- Allow calling all files from game directory instead of CD; the CD is no longer required in this mode (all files must first be copied from the CD to the game directory). (#2)
- Auto-battle now duels all regular units first, then lieutenants, then regents. Before it dueled from the bottom of the unit stack, upwards, which could result in lieutenants or regents dueling before regular units. (#19)

Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. (#3)

!!!!!!!!!!!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!

For the patch to work, you must follow the installation instructions carefully!
This applies to both the Windows and DOS versions.

/!\ The instructions have changed since the previous release. /!\
If you have applied the patch in the past, please check step 8 for new
configuration instructions. The previous instructions still work, but
may cause issues using the original Scenario Editor.

[3] ADDITIONAL INFORMATION
==========================
For specific questions on what this patch changes or to get in touch with the
development team, check us out at any of the following places:

 * https://kiranwelle.com/birthright
 * https://github.com/Shiryou/BirP
 * https://moddb.com/mods/birthright-preservation-patch
 * https://forum.birthright.net/t/birthright-the-gorgons-alliance-preservation-patch/24699
