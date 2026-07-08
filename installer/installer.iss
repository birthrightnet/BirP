; Define version and setup filename with iscc.exe /DMyAppVersion=v1.0 /DMyAppSetupFile=BirPSetup_v1.0.iss
#ifndef MyAppVersion
#define MyAppVersion GetStringFileInfo("..\build-artifacts\binaries\Installer\WINBR.EXE", "FILEVERSION")
#endif
#ifndef MyAppSetupFile
#define MyAppSetupFile "BirPSetup"
#endif
#define MyAppPublisher "Kiran Welle"
#define MyAppURL "https://github.com/Shiryou/BirP"
#define MyAppExeName "WinBr.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{450F762A-A08D-4CC0-A089-CBC642716DAD}
AppName={cm:MyAppName}
AppVersion={#MyAppVersion}
AppVerName={cm:NameAndVersion,{cm:MyAppName},{#MyAppVersion}}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName=C:\SIERRA\BIRTHRT
AppendDefaultDirName=no
ChangesAssociations=yes
DefaultGroupName={cm:MyAppNameClean}
AllowNoIcons=yes
PrivilegesRequired=admin
; Lets automated test runs pass /CURRENTUSER to install without elevation.
; No new UI: interactive installs still default to admin with no extra dialog.
PrivilegesRequiredOverridesAllowed=commandline
; Always show the directory page. The Inno default (auto) skips it when a prior
; install is remembered, so a re-run would land in the remembered folder without
; the player ever seeing the choice. The page still prefills the remembered
; directory, so tier 1 of the PATCH detection ladder keeps working.
DisableDirPage=no
OutputDir=..\build-artifacts\binaries\Installer
OutputBaseFilename={#MyAppSetupFile}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\source\RES\BR4.ICO
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={cm:MyAppUninstallName}
RestartIfNeededByRun=false
ShowLanguageDialog=yes

[Languages]
// You can override individual messages using the [Messages] and [CustomMessages] sections,
// but this should all be done in the .isl files in the CustomMessages folder to ensure they're localized.
Name: "en"; MessagesFile: "compiler:Default.isl,.\CustomMessages\Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl,.\CustomMessages\German.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl,.\CustomMessages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
; Game-from-CD entries. Copied only in INSTALL mode (Check: WantGame). PATCH never
; pulls these, so a player's options (GAMEOPT.DAT) and realm start (RLMSTART.DAT)
; are never reset.
Source: "{code:GetCDPath}\GRAPHICS\*"; DestDir: "{app}\GRAPHICS"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\INTRO\*"; DestDir: "{app}\INTRO"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\MUSIC\*"; DestDir: "{app}\MUSIC"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\RESFILES\*"; DestDir: "{app}\RESFILES"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\SAVEGAME\*"; DestDir: "{app}\SAVEGAME"; Flags: external ignoreversion recursesubdirs uninsneveruninstall onlyifdoesntexist; Check: WantGame
Source: "{code:GetCDPath}\SCENES\*"; DestDir: "{app}\SCENES"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\TEXT\*"; DestDir: "{app}\TEXT"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WADS\*"; DestDir: "{app}\WADS"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WAVE00\*"; DestDir: "{app}\WAVE00"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WAVE10\*"; DestDir: "{app}\WAVE10"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WAVE20\*"; DestDir: "{app}\WAVE20"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WAVE30\*"; DestDir: "{app}\WAVE30"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WAVE384\*"; DestDir: "{app}\WAVE384"; Flags: external ignoreversion recursesubdirs; Check: WantGame
Source: "{code:GetCDPath}\WAVELOOP\*"; DestDir: "{app}\WAVELOOP"; Flags: external ignoreversion recursesubdirs; Check: WantGame

Source: "{code:GetCDPath}\BIRTHRT.ICO"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\birth.url"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\BR.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\BTLSCN.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\CONTEXT.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\*.DRV"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\DOS4GW.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\DOSHELP.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\GAMEOPT.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\HAVEVESA.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\LICENSE.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\MP.CFG"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\NOVA.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\QKEYSHLP.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\README"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\README.BAT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\README.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\README.WRI"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\README2.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\RESOURCE.CFG"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\RLMSTART.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\RULES.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\SIERRA.INF"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\SIERRANW.DLL"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\SNWVALID.DLL"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\STRDAT.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\TUTORADV.SAV"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\TUTOREXP.SAV"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\TUTORIAL.SAV"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\VERSION"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\VESATEST.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame
Source: "{code:GetCDPath}\WINBR.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Check: WantGame

; Both patch payloads always install, in both INSTALL and PATCH. The official 1.4
; patch is laid down first so our BirP builds win where filenames overlap.
Source: ..\..\birp-dependencies\Patch1004\*; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

Source: "..\build-artifacts\binaries\Installer\CHARED.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build-artifacts\binaries\Installer\NOVA.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build-artifacts\binaries\Installer\WINBR.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build-artifacts\binaries\Installer\STRDAT.DAT"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.TXT"; DestDir: "{app}"; Flags: ignoreversion

; Issue reporting tool (issue #104). Static scripts shipped from the repo; a player
; double-clicks the .bat to produce a diagnostic .zip. See issue-reporter\.
Source: "..\issue-reporter\BirP-Issue-Report.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\issue-reporter\BirP-Issue-Report.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:RunProgram,{cm:MyAppNameClean}}"; Flags: postinstall nowait skipifsilent
Filename: "{app}\README.TXT";      Description: "{cm:ViewReadme}";                 Flags: postinstall shellexec skipifsilent

[UninstallDelete]
; Diagnostic files the game writes at runtime. The game recreates them as
; needed, so removing them at uninstall leaves no orphans behind.
Type: files; Name: "{app}\*.log"
Type: files; Name: "{app}\Fatal.err"
Type: files; Name: "{app}\memdmp.txt"
Type: files; Name: "{app}\hashcln.txt"
Type: files; Name: "{app}\inuseblk.txt"

[Icons]
Name: "{group}\{cm:MyAppNameClean}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:ProgramOnTheWeb,{cm:MyAppNameClean}}"; Filename: "{#MyAppURL}"
Name: "{group}\{cm:UninstallProgram,{cm:MyAppNameClean}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{cm:MyAppNameClean}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Code]
const
  ModeInstall = 0;
  ModePatch = 1;

var
  ModePage: TInputOptionWizardPage;
  InstallerLocationPage: TInputFileWizardPage;
  DeleteSettings: Boolean;
  CmdMode: String;
  CmdCDPath: String;
  NoCDMessageShown: Boolean;
  NoInstallMessageShown: Boolean;
  ModeDefaultApplied: Boolean;

// Pure helpers (DirHasGame, DetectCD, DetectExistingInstallDir, IsDangerousPath,
// GetCommandlineParam, EnvCdPath, EnvMode) live in common.iss so the self-test
// harness (selftests.iss) can unit test them; see the CI plan in docs-89.
#include "common.iss"

// --- Mode and source resolution (also usable in silent runs) ---

// Effective mode, in order of precedence:
//   1. /MODE= command-line override.
//   2. BIRTHRT_MODE environment override (automated runs).
//   3. A CD path handed in by an automated run implies a fresh install.
//   4. The interactive mode-page selection.
function EffectiveMode(): Integer;
var
  M: String;
begin
  if CompareText(CmdMode, 'PATCH') = 0 then begin Result := ModePatch; Exit; end;
  if CompareText(CmdMode, 'INSTALL') = 0 then begin Result := ModeInstall; Exit; end;

  M := EnvMode();
  if M = 'PATCH' then begin Result := ModePatch; Exit; end;
  if M = 'INSTALL' then begin Result := ModeInstall; Exit; end;

  if EnvCdPath() <> '' then begin Result := ModeInstall; Exit; end;

  if Assigned(ModePage) and (ModePage.SelectedValueIndex = ModePatch) then
    Result := ModePatch
  else
    Result := ModeInstall;
end;

// Check function on every game-from-CD file entry: true only in INSTALL.
function WantGame(): Boolean;
begin
  Result := EffectiveMode() = ModeInstall;
end;

// The located game-files folder, in order of precedence:
//   1. BIRTHRT_CD_PATH environment override (automated runs).
//   2. /CDPATH= command-line override.
//   3. The folder of the picked WINBR.EXE.
// Keeps a trailing backslash to match the original {code:GetCDPath}\... paths.
function InstallerLocation(): String;
begin
  if EnvCdPath() <> '' then
    Result := AddBackslash(EnvCdPath())
  else if CmdCDPath <> '' then
    Result := AddBackslash(CmdCDPath)
  else if Assigned(InstallerLocationPage) then
    Result := ExtractFilePath(InstallerLocationPage.Values[0])
  else
    Result := '';
end;

function GetCDPath(Param: String): String;
begin
  Result := InstallerLocation();
end;

// --- Uninstall confirmation dialog ---

function ShouldDeleteSettings(): Boolean;
begin
  Result := DeleteSettings;
end;

function InitializeUninstall(): Boolean;
var
  Form: TSetupForm;
  ConfirmLabel: TNewStaticText;
  DeleteCheckBox: TCheckBox;
  OKButton, CancelButton: TNewButton;
  ConfirmText: String;
  ConfirmTitle: String;
  UninstallName: string;
begin
  // A /VERYSILENT (automated) uninstall cannot show the custom confirm form;
  // treat the silent flags as consent, and read the settings/saves choice from
  // the BIRTHRT_DELETE_SETTINGS environment variable ('1' deletes them).
  // A plain /SILENT run must still show the form: the UninstallString we
  // register runs the uninstaller with /SILENT (to skip Inno's built-in
  // prompt), so this form is the only confirmation an Add/Remove Programs
  // uninstall ever gets.
  if CmdLineParamExists('/VERYSILENT') then
  begin
    DeleteSettings := Trim(GetEnv('BIRTHRT_DELETE_SETTINGS')) = '1';
    Result := True;
    Exit;
  end;

  Result := False;
  UninstallName := ExpandConstant('{cm:MyAppUninstallName}');

  Form := CreateCustomForm(ScaleX(400), ScaleY(170), False, False);
  ConfirmTitle := FmtMessage(CustomMessage('UninstallProgram'), [UninstallName]);
  Form.Caption := ConfirmTitle;
  Form.Position := poScreenCenter;

  // Show the exact folder that will be removed so the player can confirm it is
  // their game directory before agreeing.
  // The continuation line must not start with '#', or the Inno preprocessor
  // reads it as a directive.
  ConfirmText := FmtMessage(CustomMessage('UninstallConfirm'), [UninstallName]) + #13#10#13#10 +
    ExpandConstant('{app}');

  ConfirmLabel := TNewStaticText.Create(Form);
  ConfirmLabel.Parent := Form;
  ConfirmLabel.Left := ScaleX(15);
  ConfirmLabel.Top := ScaleY(15);
  ConfirmLabel.Width := Form.ClientWidth - ScaleX(30);
  ConfirmLabel.AutoSize := True;
  ConfirmLabel.WordWrap := True;
  ConfirmLabel.Caption := ConfirmText;

  DeleteCheckBox := TCheckBox.Create(Form);
  DeleteCheckBox.Parent := Form;
  DeleteCheckBox.Left := ConfirmLabel.Left;
  DeleteCheckBox.Top := ConfirmLabel.Top + ConfirmLabel.Height + ScaleY(15);
  DeleteCheckBox.Width := Form.ClientWidth - ScaleX(30);
  DeleteCheckBox.Caption := CustomMessage('DeleteSettingsLabel');

  OKButton := TNewButton.Create(Form);
  OKButton.Parent := Form;
  OKButton.Caption := SetupMessage(msgButtonYes);
  OKButton.Default := True;
  OKButton.ModalResult := mrYes;
  OKButton.Left := Form.ClientWidth - ScaleX(175);
  OKButton.Top := Form.ClientHeight - ScaleY(40);

  CancelButton := TNewButton.Create(Form);
  CancelButton.Parent := Form;
  CancelButton.Caption := SetupMessage(msgButtonNo);
  CancelButton.ModalResult := mrNo;
  CancelButton.Left := Form.ClientWidth - ScaleX(90);
  CancelButton.Top := OKButton.Top;

  if Form.ShowModal() = mrYes then
  begin
    DeleteSettings := DeleteCheckBox.Checked;
    Result := True;
  end;
end;

// --- Ready-to-install memo ---

procedure AddToReadyMemo(var Memo: string; Info, NewLine: string);
begin
  if Info <> '' then Memo := Memo + Info + NewLine + NewLine;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  AddToReadyMemo(Result, MemoUserInfoInfo, NewLine);
  AddToReadyMemo(Result, MemoDirInfo, NewLine);
  AddToReadyMemo(Result, MemoTypeInfo, NewLine);
  AddToReadyMemo(Result, MemoGroupInfo, NewLine);
  AddToReadyMemo(Result, MemoTasksInfo, NewLine);

  if WantGame() then
  begin
    AddToReadyMemo(Result, CustomMessage('ReadyMemoInstallerLocation') + NewLine + Space + InstallerLocation(), NewLine);
  end;
end;

// --- Page flow ---

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  // Skip the mode page when the mode is forced from the command line.
  if Assigned(ModePage) and (PageID = ModePage.ID) and (CmdMode <> '') then
    Result := True;
  // The CD location page is only meaningful in INSTALL.
  if Assigned(InstallerLocationPage) and (PageID = InstallerLocationPage.ID) then
    Result := EffectiveMode() <> ModeInstall;
end;

procedure CurPageChanged(CurPageID: Integer);
var
  Detected: String;
begin
  // Default the mode to PATCH when a game is already on disk, else INSTALL.
  // Applied when the mode page first shows: the {app} constant is not yet
  // initialized during InitializeWizard, but WizardDirValue (the prefilled
  // directory, including a remembered prior install) is valid here.
  if Assigned(ModePage) and (CurPageID = ModePage.ID) and not ModeDefaultApplied then
  begin
    ModeDefaultApplied := True;
    if DirHasGame(WizardDirValue) or (DetectExistingInstallDir() <> '') then
      ModePage.SelectedValueIndex := ModePatch;
  end;

  if CurPageID = wpSelectDir then
  begin
    if EffectiveMode() = ModePatch then
    begin
      WizardForm.SelectDirLabel.Caption := CustomMessage('SelectDirCaptionPatch');
      // Prefill assistance is interactive-only, and never replaces a directory
      // that already holds the game. Silent runs traverse the wizard pages too,
      // so without these guards the detection would override an explicit /DIR=.
      if (not WizardSilent) and (not DirHasGame(WizardForm.DirEdit.Text)) then
      begin
        Detected := DetectExistingInstallDir();
        if Detected <> '' then
          WizardForm.DirEdit.Text := Detected
        else if not NoInstallMessageShown then
        begin
          MsgBox(CustomMessage('PatchNoInstallFound'), mbInformation, MB_OK);
          NoInstallMessageShown := True;
        end;
      end;
    end
    else
      WizardForm.SelectDirLabel.Caption := CustomMessage('SelectDirCaptionInstall');
  end
  else if Assigned(InstallerLocationPage) and (CurPageID = InstallerLocationPage.ID) then
  begin
    if InstallerLocationPage.Values[0] = '' then
    begin
      // A BIRTHRT_CD_PATH or /CDPATH= override already resolves the source;
      // mirror it into the page instead of scanning drives.
      if (EnvCdPath() <> '') or (CmdCDPath <> '') then
        InstallerLocationPage.Values[0] := InstallerLocation() + 'WINBR.EXE'
      else
      begin
        Detected := DetectCD();
        if Detected <> '' then
          InstallerLocationPage.Values[0] := AddBackslash(Detected) + 'WINBR.EXE'
        else if (not NoCDMessageShown) and (not WizardSilent) then
        begin
          MsgBox(CustomMessage('NoCDFoundMessage'), mbInformation, MB_OK);
          NoCDMessageShown := True;
        end;
      end;
    end;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  // PATCH must land on a folder that already holds the game. SuppressibleMsgBox
  // keeps silent runs from blocking on the error: /SUPPRESSMSGBOXES only
  // auto-answers boxes shown through it, not plain MsgBox.
  if (CurPageID = wpSelectDir) and (EffectiveMode() = ModePatch) then
  begin
    if not DirHasGame(WizardDirValue) then
    begin
      SuppressibleMsgBox(FmtMessage(CustomMessage('PatchDirNoGame'), [WizardDirValue]), mbError, MB_OK, IDOK);
      Result := False;
      Exit;
    end;
  end;

  if Assigned(InstallerLocationPage) and (CurPageID = InstallerLocationPage.ID) and
     (not FileExists(ExpandConstant(InstallerLocationPage.Values[0]))) then
  begin
    if ExpandConstant(InstallerLocationPage.Values[0]) = '' then
      SuppressibleMsgBox(CustomMessage('InstallerLocationErrorEmpty'), mbError, MB_OK, IDOK)
    else
      SuppressibleMsgBox(FmtMessage(CustomMessage('InstallerLocationErrorInvalid'), [InstallerLocationPage.Values[0]]), mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
end;

// Backstop for silent runs, where page validation never fires: refuse a PATCH
// that targets a folder with no base game.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if (EffectiveMode() = ModePatch) and (not DirHasGame(ExpandConstant('{app}'))) then
    Result := FmtMessage(CustomMessage('PatchDirNoGame'), [ExpandConstant('{app}')]);
end;

// --- BRSETUP.CFG maintenance ---

procedure SetBRSetupConfigValue(const FileName, Section, Value: String);
var
  Lines: TArrayOfString;
  I: Integer;
  Found: Boolean;
begin
  if not FileExists(FileName) then
  begin
    SaveStringToFile(FileName, Section + #13#10 + Value + #13#10, False);
    Exit;
  end;

  if LoadStringsFromFile(FileName, Lines) then
  begin
    Found := False;
    for I := 0 to GetArrayLength(Lines) - 1 do
    begin
      if CompareText(Trim(Lines[I]), Section) = 0 then
      begin
        if I + 1 < GetArrayLength(Lines) then
          Lines[I + 1] := Value
        else
        begin
          SetArrayLength(Lines, GetArrayLength(Lines) + 1);
          Lines[GetArrayLength(Lines) - 1] := Value;
        end;
        Found := True;
        Break;
      end;
    end;

    if not Found then
    begin
      I := GetArrayLength(Lines);
      SetArrayLength(Lines, I + 2);
      Lines[I] := Section;
      Lines[I + 1] := Value;
    end;

    SaveStringsToFile(FileName, Lines, False);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigPath: String;
  UninstallKey: String;
begin
  if CurStep = ssPostInstall then
  begin
    ConfigPath := ExpandConstant('{app}\BRSETUP.CFG');
    if not (InstallerLocation() = '') then
    begin
      SaveStringToFile(ConfigPath,
        '[INSTALL_TYPE]' + #13#10 +
        '3' + #13#10 +
        '[CD]' + #13#10 +
        Copy(InstallerLocation(), 1, 1) + #13#10 +
        '[CD_BYPASS]' + #13#10 +
        '1' + #13#10, False);
    end else
    begin
      SetBRSetupConfigValue(ConfigPath, '[CD_BYPASS]', '1');
    end;

    // Add /SILENT to UninstallString to skip built-in confirmation since we're using our own.
    // HKEY_AUTO follows the install mode: HKLM for the normal admin install,
    // HKCU when a test run passes /CURRENTUSER.
    UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + ExpandConstant('{#SetupSetting("AppId")}') + '_is1';
    RegWriteStringValue(HKEY_AUTO, UninstallKey, 'UninstallString', ExpandConstant('"{uninstallexe}" /SILENT'));
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    AppDir := ExpandConstant('{app}');
    // Never run destructive deletes against a drive root, the Windows tree, a
    // Program Files root, or a blank path.
    if IsDangerousPath(AppDir) then
      Exit;

    if DeleteSettings then
    begin
      DeleteFile(AddBackslash(AppDir) + 'BRSETUP.CFG');
      DeleteFile(AddBackslash(AppDir) + 'GAMEOPT.DAT');
      DeleteFile(AddBackslash(AppDir) + 'RLMSTART.DAT');
      DeleteFile(AddBackslash(AppDir) + 'MPSTART.DAT');
      DelTree(AddBackslash(AppDir) + 'SAVEGAME', True, True, True);
    end;

    // Remove {app} if it's empty.
    RemoveDir(AppDir);
  end;
end;

// --- Setup entry points ---

function InitializeSetup(): Boolean;
var
  M, Cd: String;
begin
  Result := True;
  M := Uppercase(Trim(GetCommandlineParam('/MODE=')));
  if (M = 'INSTALL') or (M = 'PATCH') then
    CmdMode := M
  else
    CmdMode := '';
  CmdCDPath := Trim(GetCommandlineParam('/CDPATH='));

  // Validate the game-files override (BIRTHRT_CD_PATH first, then /CDPATH=)
  // early and echo it to the log so an automated (silent) install fails loudly
  // with a clear reason instead of copying nothing. Does nothing when no
  // override is given (interactive run).
  Cd := EnvCdPath();
  if Cd = '' then
    Cd := CmdCDPath;
  if Cd = '' then
    Exit;
  Log('Game files location override in effect: ' + Cd);
  if not DirExists(Cd) then
  begin
    SuppressibleMsgBox(FmtMessage(CustomMessage('CdPathEnvMissing'), [Cd]), mbError, MB_OK, IDOK);
    Result := False;
  end
  else if not DirHasGame(Cd) then
  begin
    SuppressibleMsgBox(FmtMessage(CustomMessage('CdPathEnvNoGame'), [Cd]), mbError, MB_OK, IDOK);
    Result := False;
  end;
end;

procedure InitializeWizard;
begin
  ModePage := CreateInputOptionPage(wpWelcome,
    CustomMessage('ModePageTitle'), CustomMessage('ModePageDescription'),
    CustomMessage('ModePageSubDescription'), True, False);
  ModePage.Add(CustomMessage('ModeInstallCaption'));
  ModePage.Add(CustomMessage('ModePatchCaption'));
  // Start on INSTALL; CurPageChanged switches the default to PATCH when a game
  // is detected. The detection cannot run here: expanding {app} inside
  // InitializeWizard raises a fatal "constant not initialized" error.
  ModePage.SelectedValueIndex := ModeInstall;

  InstallerLocationPage := CreateInputFilePage(wpSelectDir,
    CustomMessage('InstallerLocationTitle'), CustomMessage('InstallerLocationDescription'),
    CustomMessage('InstallerLocationSubDescription'));

  InstallerLocationPage.Add(CustomMessage('InstallerLocationLabel'),
    'WINBR.EXE|WINBR.EXE|Executables (*.exe)|*.exe|All files|*.*',
    '.exe');
end;
