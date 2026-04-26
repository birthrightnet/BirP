Birthright: The Gorgons Alliance Preservation Patch
Version: 1.4.0.4
Date: 2026-04-25

TABLE OF CONTENTS

[1] HOW TO INSTALL THE PATCH
[2] WHAT THE PATCH FIXES / CHANGES
[3] ADDITIONAL INFORMATION
[4] IF YOU STILL EXPERIENCE PROBLEMS

[1] HOW TO INSTALL THE PATCH
============================
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

[Unreleased]

Added

- Added "modern mode" in-game resolution options with support for `800x600`, `1024x768`, `1280x960`, `1400x1050`, `1600x1200`, and `1920x1440`. The original "OG mode" remains available.

Removed

- Removed DirectDraw as a supported display mode and removed related options and hotkeys; GDI is now the only supported rendering path.
- Removed the deprecated `Auto Resolution` graphics option.

Fixed

- Fixed game window position resetting after restart by persisting last moved coordinates between sessions.

1.4.0.4 - 2025-11-02

Changed

- Allow calling all files from game directory instead of CD; the CD is no longer required in this mode (all files must first be copied from the CD to the game directory). (#2)

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
 * http://www.birthright.net/forums/showthread.php?29331-Birthright-The-Gorgon-s-Alliance-Preservation-Patch
