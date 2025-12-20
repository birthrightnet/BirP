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
OutputDir=..\build-artifacts\binaries\Installer
OutputBaseFilename={#MyAppSetupFile}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
AlwaysShowComponentsList=yes
SetupIconFile=..\source\RES\BR4.ICO
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={cm:MyAppName}
RestartIfNeededByRun=false
ShowLanguageDialog=yes

[Languages]
// You can override individual messages using the [Messages] and [CustomMessages] sections,
// but this should all be done in the .isl files in the CustomMessages folder to ensure they're localized.
Name: "en"; MessagesFile: "compiler:Default.isl,.\CustomMessages\Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl,.\CustomMessages\German.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl,.\CustomMessages\French.isl"

; Options displayed during setup (component selection)
[Types]
Name: "patch";   Description: "{cm:InstallationTypePatch}";
Name: "game";    Description: "{cm:InstallationTypeGame}";
Name: "full";    Description: "{cm:InstallationTypeFull}";
Name: "custom";  Description: "{cm:InstallationTypeCustom}"; Flags: iscustom

; The compotent definition
[Components]
Name: "game";                 Description: "{cm:SelectionGame}";           Types: full game custom
Name: "oldpatch";             Description: "{cm:SelectionOldPatch}";       Types: full game patch custom
Name: "oldpatch\patch";       Description: "{cm:SelectionBirp}";           Types: full patch custom
Name: "shortcuts";            Description: "{cm:SelectionShortcuts}";      Types: full patch game
Name: "shortcuts\start_menu"; Description: "{cm:SelectionStartMenuIcons}"; Types: full patch game
Name: "shortcuts\desktop";    Description: "{cm:SelectionDesktopIcons}";   Types: full patch game

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
Source: "{code:GetCDPath}\GRAPHICS\*"; DestDir: "{app}\GRAPHICS"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\INTRO\*"; DestDir: "{app}\INTRO"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\MUSIC\*"; DestDir: "{app}\MUSIC"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\RESFILES\*"; DestDir: "{app}\RESFILES"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\SAVEGAME\*"; DestDir: "{app}\SAVEGAME"; Flags: external ignoreversion recursesubdirs uninsneveruninstall onlyifdoesntexist; Components: game
Source: "{code:GetCDPath}\SCENES\*"; DestDir: "{app}\SCENES"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\TEXT\*"; DestDir: "{app}\TEXT"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WADS\*"; DestDir: "{app}\WADS"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WAVE00\*"; DestDir: "{app}\WAVE00"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WAVE10\*"; DestDir: "{app}\WAVE10"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WAVE20\*"; DestDir: "{app}\WAVE20"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WAVE30\*"; DestDir: "{app}\WAVE30"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WAVE384\*"; DestDir: "{app}\WAVE384"; Flags: external ignoreversion recursesubdirs; Components: game
Source: "{code:GetCDPath}\WAVELOOP\*"; DestDir: "{app}\WAVELOOP"; Flags: external ignoreversion recursesubdirs; Components: game

Source: "{code:GetCDPath}\BIRTHRT.ICO"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\birth.url"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\BR.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\BTLSCN.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\CONTEXT.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\*.DRV"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\DOS4GW.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\DOSHELP.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\GAMEOPT.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\HAVEVESA.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\LICENSE.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\MP.CFG"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\NOVA.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\QKEYSHLP.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\README"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\README.BAT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\README.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\README.WRI"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\README2.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\RESOURCE.CFG"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\RLMSTART.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\RULES.TXT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\SIERRA.INF"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\SIERRANW.DLL"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\SNWVALID.DLL"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\STRDAT.DAT"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\TUTORADV.SAV"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\TUTOREXP.SAV"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\TUTORIAL.SAV"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\VERSION"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\VESATEST.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Components: game
Source: "{code:GetCDPath}\WINBR.EXE"; DestDir: "{app}"; Flags: external ignoreversion; Components: game

Source: ..\..\birp-dependencies\Patch1004\*; DestDir: "{app}"; Flags: ignoreversion; Components: oldpatch

Source: "..\build-artifacts\binaries\Installer\CHARED.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: oldpatch\patch
Source: "..\build-artifacts\binaries\Installer\NOVA.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: oldpatch\patch
Source: "..\build-artifacts\binaries\Installer\WINBR.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: oldpatch\patch
Source: "..\README.TXT"; DestDir: "{app}"; Flags: ignoreversion; Components: oldpatch\patch

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:RunProgram,{cm:MyAppNameClean}}"; Flags: postinstall nowait skipifsilent
Filename: "{app}\README.TXT";      Description: "{cm:ViewReadme}";                 Flags: postinstall shellexec skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\*.log"

[Icons]
Name: "{group}\{cm:MyAppNameClean}"; Filename: "{app}\{#MyAppExeName}";                Components: shortcuts\start_menu
Name: "{group}\{cm:ProgramOnTheWeb,{cm:MyAppNameClean}}"; Filename: "{#MyAppURL}";     Components: shortcuts\start_menu
Name: "{group}\{cm:UninstallProgram,{cm:MyAppNameClean}}"; Filename: "{uninstallexe}"; Components: shortcuts\start_menu
Name: "{autodesktop}\{cm:MyAppNameClean}"; Filename: "{app}\{#MyAppExeName}";          Components: shortcuts\desktop

[Code]
var
  InstallerLocationPage: TInputFileWizardPage;
  DeleteSettings: Boolean;

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
  MyAppName: string;
begin
  Result := False;
  MyAppName := ExpandConstant('{cm:MyAppName}');

  Form := CreateCustomForm(ScaleX(400), ScaleY(150), False, False);
  ConfirmTitle := FmtMessage(CustomMessage('UninstallProgram'), [MyAppName]);
  Form.Caption := ConfirmTitle;
  Form.Position := poScreenCenter;

  ConfirmText := FmtMessage(CustomMessage('UninstallConfirm'), [MyAppName]);

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

function InstallerLocation(): String;
begin
  Result := '';
  if Assigned(InstallerLocationPage) then
    Result := ExtractFilePath(InstallerLocationPage.Values[0]);
end;

function GetCDPath(Param: String): String;
begin
  Result := InstallerLocation();
end;

procedure AddToReadyMemo(var Memo: string; Info, NewLine: string);
begin
  if Info <> '' then Memo := Memo + Info + NewLine + NewLine;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  AddToReadyMemo(Result, MemoUserInfoInfo, NewLine);
  AddToReadyMemo(Result, MemoDirInfo, NewLine);
  AddToReadyMemo(Result, MemoTypeInfo, NewLine);
  AddToReadyMemo(Result, MemoComponentsInfo, NewLine);
  AddToReadyMemo(Result, MemoGroupInfo, NewLine);
  AddToReadyMemo(Result, MemoTasksInfo, NewLine);

  if WizardIsComponentSelected('game') then
  begin
    AddToReadyMemo(Result, CustomMessage('ReadyMemoInstallerLocation') + NewLine + Space + InstallerLocation(), NewLine);
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if Assigned(InstallerLocationPage) and (PageID = InstallerLocationPage.ID) then
    Result := not WizardIsComponentSelected('game');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  if Assigned(InstallerLocationPage) and (CurPageID = InstallerLocationPage.ID) and
     (not FileExists(ExpandConstant(InstallerLocationPage.Values[0]))) then
  begin
    if ExpandConstant(InstallerLocationPage.Values[0]) = '' then
      MsgBox(CustomMessage('InstallerLocationErrorEmpty'), mbError, MB_OK)
    else
      MsgBox(FmtMessage(CustomMessage('InstallerLocationErrorInvalid'), [InstallerLocationPage.Values[0]]), mbError, MB_OK);
    Result := False;
    exit;
  end;
end;

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
    UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + ExpandConstant('{#SetupSetting("AppId")}') + '_is1';
    RegWriteStringValue(HKLM, UninstallKey, 'UninstallString', ExpandConstant('"{uninstallexe}" /SILENT'));
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if DeleteSettings then
    begin
      DeleteFile(ExpandConstant('{app}\BRSETUP.CFG'));
      DeleteFile(ExpandConstant('{app}\GAMEOPT.DAT'));
      DeleteFile(ExpandConstant('{app}\RLMSTART.DAT'));
      DeleteFile(ExpandConstant('{app}\MPSTART.DAT'));
      DelTree(ExpandConstant('{app}\SAVEGAME'), True, True, True);
    end;
    
    // Remove {app} if it's empty
    RemoveDir(ExpandConstant('{app}'));
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
var
  i: Integer;
  GameText: String;
  Exists: Boolean;
begin
  if CurPageID = wpSelectComponents then
  begin
    GameText := ExpandConstant('{cm:SelectionGame}');
    Exists := FileExists(ExpandConstant('{app}\WINBR.EXE'));
    for i := 0 to WizardForm.ComponentsList.Items.Count - 1 do
    begin
      if WizardForm.ComponentsList.Items[i] = GameText then
      begin
        WizardForm.ComponentsList.Checked[i] := not Exists;
        Break;
      end;
    end;
  end;
end;

procedure InitializeWizard;
begin
  WizardForm.SelectDirLabel.Caption := CustomMessage('SelectDirLabelCaption');

  InstallerLocationPage := CreateInputFilePage(wpSelectComponents,
    CustomMessage('InstallerLocationTitle'), CustomMessage('InstallerLocationDescription'),
    CustomMessage('InstallerLocationSubDescription'));

  InstallerLocationPage.Add(CustomMessage('InstallerLocationLabel'),
    'INSTALL.EXE|INSTALL.EXE|Executables (*.exe)|*.exe|All files|*.*',
    '.exe');
end;
