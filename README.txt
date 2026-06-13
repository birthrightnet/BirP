Birthright: The Gorgons Alliance Preservation Patch
Version: 1.4.2.0
Date: 2026-06-16

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

Unreleased

Added

- Pressing F11 in WIN DEBUG builds shows a pop-up window with a list of testing/cheating functions.
- Added a "Halt" button during adventure combat that sets all party members to defend. (#36)
- Added "awareness" system: characters gain awareness for 30 seconds for any other character they see, and can pathfind to them even if they lose sight of them.
- Added several new pathfinding algorithms that allow characters to path between rooms, around obstacles, etc, which has significantly reduced instances of "unable to engage" and characters stuck in walls. (#36)

Changed

- Player characters start each fight in a sensible default fighting style for their class and remember the fighting style you last chose for the rest of that fight. (#36) (#53)
- Player characters remember their last used fighting style and resume using it against nearby enemies after their current target dies (#36) (#53)
- Assassination reports now include the assassinated unit type. (#33)
- Party members give up a chase after 15 seconds (#36)
- Cancelling a lieutenant realm sub-action no longer cancels the lieutenant action. (#21)
- Lieutenant action realm button now highlights during lieutenant action, and lieutenant action no longer cancels if you cancel  (#21)
- Halved the delay before an adventure returns to exploration after combat ends. (#14)
- Improved adventure combat messages: attacks now name the target and its armor class, and chases show which enemy is being pursued.

Fixed

- Characters can no longer attack through walls; they must have line of sight. Spectres and wraiths still phase through walls by design. (#36)
- Party members no longer chase enemies onto lava, acid, or deep water. (#36)
- Fixed some crashes that could occur during two-part adventures. (#52)
- Hardened an adventure crash point so missing visuals are skipped instead of crashing the game to the desktop. (#4)
- Fixed start-of-round crash for DOS DEBUG builds. (#57)

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
