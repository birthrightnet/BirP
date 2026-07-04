# BirP Issue Report tool

A small, user-runnable tool that collects diagnostic files from a Birthright
install into a single `.zip` that players can send to the BirP developers.
Implements [issue #104](https://github.com/Shiryou/BirP/issues/104).

## Files

- `BirP-Issue-Report.bat` - the launcher. **This is what players double-click.**
  It runs the PowerShell script with `-NoProfile -ExecutionPolicy Bypass`, so the
  player never has to change any PowerShell setting.
- `BirP-Issue-Report.ps1` - the actual logic. Plain text; open it in Notepad to
  see exactly what is collected.

Both ship **into the game install directory** (e.g. `C:\Sierra\BIRTHRT`) so the
script's own folder is the install folder it reports on.

## What it does

1. Shows a consent dialog describing what will be archived, and asks to continue.
2. On accept, into a temporary `birp-issue-report-YYYY-MM-DD-HHMMSS` folder it
   writes `report-summary.txt`:

   ```text
   Date: <date and time>
   Install directory: <folder the tool runs from>
   NOVA.EXE version: <version | UNKNOWN (SHA-256 ...) | NOT FOUND>
   WINBR.EXE version: <version | NOT FOUND>
   Operating System: <WIN11 (caption, version) | ...>
   ```

   and copies whichever of `DOS.LOG`, `winbr.log`, `BRSETUP.CFG`, `STRDAT.DAT`
   exist.
3. Zips that folder next to the tool, deletes the working folder, and shows the
   full path to the `.zip`. The working folder is removed even if an error occurs.

Version notes: `WINBR.EXE` (Windows PE) is read from its file-version resource.
`NOVA.EXE` (DOS4GW, no PE resource) is read by scanning the image for the
compiled-in `1.4.x.x` `BUILD_VERSION` string, falling back to a SHA-256 hash.
`nova95.exe` and `BR.EXE` are intentionally **not** reported (see the working doc,
`bugs-and-enhancement-requests/docs-104-...`).

## Advanced / testing switches

Not needed for normal use:

- `-InstallDir <path>` - collect from / write the archive to another folder
  (default: the script's own folder).
- `-Unattended` - skip the dialogs, print status to the console, and proceed
  without asking. Intended for support/automation.

## Deployment

Both files ship with the BirP patch:

- **Installer:** `installer.iss` `[Files]` installs them into `{app}` as part of
  the `oldpatch\patch` component.
- **Local deploy:** `scripts/deploy-helper.ps1` copies them into
  `BIRTHRT_INSTALL_DIR` on every deploy (alongside the built exe and
  `STRDAT.DAT`), so every `deploy-*.ps1` / `build-and-deploy-*.ps1` mirrors an
  install.
- **Release zip:** `scripts/build-release-package.ps1` includes them in the
  distributable `.zip` so a manual extract matches an install.
