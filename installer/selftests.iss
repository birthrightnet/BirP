; selftests.iss - pure-logic self-tests for the installer helpers in common.iss.
;
; Compiles to a tiny setup exe that never installs anything: InitializeSetup
; runs a table of assertions over fixture folders, writes a results file, and
; returns False so setup always exits before the wizard. Driven by
; scripts\test-installer.ps1 (Layer 3 of the CI plan in docs-89), which sets:
;
;   BIRP_SELFTEST_DIR        fixture root (hasgame-winbr\, hasgame-nova\, hasgame-empty\)
;   BIRP_SELFTEST_OUT        path of the results file to write
;   BIRP_SELFTEST_EXPECT_CD  optional: the drive root DetectCD must return
;                            (the driver substs a drive to a fake CD folder)
;
; Run with /VERYSILENT /SUPPRESSMSGBOXES. The driver parses the results file;
; the process exit code is always nonzero because setup is aborted on purpose.

[Setup]
AppId={{8B1A6E52-3C9D-4F41-9A07-D2E5B0C4A913}
AppName=BirP Installer Self Tests
AppVersion=0.0
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
OutputDir=..\build-artifacts\binaries\Installer
OutputBaseFilename=BirpInstallerSelfTests

[Code]
#include "common.iss"

var
  ResultsText: String;
  TestCount: Integer;
  FailCount: Integer;

procedure Check(const Name: String; Cond: Boolean);
begin
  TestCount := TestCount + 1;
  if Cond then
    ResultsText := ResultsText + 'PASS ' + Name + #13#10
  else
  begin
    FailCount := FailCount + 1;
    ResultsText := ResultsText + 'FAIL ' + Name + #13#10;
  end;
end;

procedure Info(const Line: String);
begin
  ResultsText := ResultsText + 'INFO ' + Line + #13#10;
end;

procedure RunDirHasGameTests(const Fix: String);
begin
  Check('DirHasGame true for folder with WINBR.EXE', DirHasGame(Fix + '\hasgame-winbr'));
  Check('DirHasGame true with trailing backslash', DirHasGame(Fix + '\hasgame-winbr\'));
  Check('DirHasGame true for folder with NOVA.EXE', DirHasGame(Fix + '\hasgame-nova'));
  Check('DirHasGame false for empty folder', not DirHasGame(Fix + '\hasgame-empty'));
  Check('DirHasGame false for missing folder', not DirHasGame(Fix + '\does-not-exist'));
  Check('DirHasGame false for blank path', not DirHasGame(''));
end;

procedure RunDetectCDTests();
var
  Detected, Expected: String;
begin
  Expected := Trim(GetEnv('BIRP_SELFTEST_EXPECT_CD'));
  Detected := DetectCD();
  Info('DetectCD returned "' + Detected + '"');
  if Expected <> '' then
    Check('DetectCD finds the expected drive root', CompareText(Detected, Expected) = 0);
  if Detected <> '' then
    Check('DetectCD result actually holds the game', DirHasGame(Detected));
end;

procedure RunDetectExistingInstallDirTests();
var
  D: String;
begin
  // Property test: the machine may or may not have a real install, but the
  // result must be either empty or a folder that really holds the game.
  D := DetectExistingInstallDir();
  Info('DetectExistingInstallDir returned "' + D + '"');
  Check('DetectExistingInstallDir empty or holds the game', (D = '') or DirHasGame(D));
end;

procedure RunIsDangerousPathTests(const Fix: String);
var
  WinDir, PF, PF32, SysDir: String;
begin
  WinDir := RemoveBackslash(ExpandConstant('{win}'));
  SysDir := RemoveBackslash(ExpandConstant('{sys}'));
  PF := RemoveBackslash(ExpandConstant('{commonpf}'));
  PF32 := RemoveBackslash(ExpandConstant('{commonpf32}'));

  Check('dangerous: blank path', IsDangerousPath(''));
  Check('dangerous: whitespace path', IsDangerousPath('   '));
  Check('dangerous: bare drive letter', IsDangerousPath('C:'));
  Check('dangerous: drive root C:\', IsDangerousPath('C:\'));
  Check('dangerous: drive root D:\', IsDangerousPath('D:\'));
  Check('dangerous: Windows dir', IsDangerousPath(WinDir));
  Check('dangerous: Windows dir with backslash', IsDangerousPath(WinDir + '\'));
  Check('dangerous: folder inside Windows tree', IsDangerousPath(WinDir + '\Temp'));
  Check('dangerous: Windows dir lowercase', IsDangerousPath(Lowercase(WinDir)));
  Check('dangerous: System dir', IsDangerousPath(SysDir));
  Check('dangerous: Program Files root', IsDangerousPath(PF));
  Check('dangerous: Program Files root with backslash', IsDangerousPath(PF + '\'));
  Check('dangerous: Program Files (x86) root', IsDangerousPath(PF32));

  Check('safe: default install dir', not IsDangerousPath('C:\SIERRA\BIRTHRT'));
  Check('safe: default install dir with backslash', not IsDangerousPath('C:\SIERRA\BIRTHRT\'));
  Check('safe: game folder under Program Files', not IsDangerousPath(PF + '\Sierra\BIRTHRT'));
  Check('safe: sibling starting with Windows name', not IsDangerousPath(WinDir + 'Old'));
  Check('safe: fixture folder', not IsDangerousPath(Fix + '\hasgame-winbr'));
end;

procedure RunOverrideTests();
begin
  // The driver passes /SELFTESTPARAM=hello on the command line.
  Check('GetCommandlineParam reads /SELFTESTPARAM=', GetCommandlineParam('/SELFTESTPARAM=') = 'hello');
  Check('GetCommandlineParam empty for absent param', GetCommandlineParam('/NOSUCHPARAM=') = '');
  // The driver runs the self-tests with /VERYSILENT, giving the positive case.
  Check('CmdLineParamExists true for /VERYSILENT', CmdLineParamExists('/VERYSILENT'));
  Check('CmdLineParamExists false for absent flag', not CmdLineParamExists('/NOSUCHFLAG'));
  // The driver sets BIRTHRT_MODE=patch (lowercase) to prove normalization.
  Check('EnvMode normalizes lowercase patch', EnvMode() = 'PATCH');
  // The driver sets BIRTHRT_CD_PATH with surrounding spaces to prove trimming.
  Check('EnvCdPath trims surrounding whitespace',
    (EnvCdPath() <> '') and (EnvCdPath() = Trim(EnvCdPath())));
end;

function InitializeSetup(): Boolean;
var
  Fix, OutFile: String;
begin
  Result := False; // Never proceed past InitializeSetup: this exe only tests.
  ResultsText := '';
  TestCount := 0;
  FailCount := 0;

  Fix := RemoveBackslash(Trim(GetEnv('BIRP_SELFTEST_DIR')));
  OutFile := Trim(GetEnv('BIRP_SELFTEST_OUT'));
  if (Fix = '') or (OutFile = '') then
  begin
    Log('selftests: BIRP_SELFTEST_DIR or BIRP_SELFTEST_OUT is not set.');
    if OutFile <> '' then
      SaveStringToFile(OutFile, 'RESULT FAIL 0 run, missing BIRP_SELFTEST_DIR' + #13#10, False);
    Exit;
  end;

  try
    RunDirHasGameTests(Fix);
    RunDetectCDTests();
    RunDetectExistingInstallDirTests();
    RunIsDangerousPathTests(Fix);
    RunOverrideTests();
  except
    FailCount := FailCount + 1;
    ResultsText := ResultsText + 'FAIL unexpected exception: ' + GetExceptionMessage + #13#10;
  end;

  if FailCount = 0 then
    ResultsText := ResultsText + 'RESULT PASS ' + IntToStr(TestCount) + ' run, 0 failed' + #13#10
  else
    ResultsText := ResultsText + 'RESULT FAIL ' + IntToStr(TestCount) + ' run, ' + IntToStr(FailCount) + ' failed' + #13#10;
  SaveStringToFile(OutFile, ResultsText, False);
end;
