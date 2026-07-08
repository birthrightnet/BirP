// common.iss - pure helper functions shared by installer.iss and selftests.iss.
//
// Everything in this file must stay side-effect free: no wizard state, no
// globals, no registry or file writes. That is what lets selftests.iss unit
// test these functions without a VM or a real disc (see the CI plan in
// bugs-and-enhancement-requests/docs-89-*.md).
//
// This file is #include'd inside an existing [Code] section, so it contains
// bare Pascal Script functions with no section header of its own.

// A folder holds the game when either Birthright executable is present.
function DirHasGame(Dir: String): Boolean;
begin
  Result := FileExists(AddBackslash(Dir) + 'WINBR.EXE') or
            FileExists(AddBackslash(Dir) + 'NOVA.EXE');
end;

// Scan every drive letter for WINBR.EXE at the root and return the first root
// found. Drive-type-blind on purpose: the source may be a USB drive, not only a
// CD-ROM. Returns '' when nothing matches.
function DetectCD(): String;
var
  i: Integer;
  Root: String;
begin
  Result := '';
  for i := 0 to 25 do
  begin
    Root := Chr(Ord('A') + i) + ':\';
    if FileExists(Root + 'WINBR.EXE') then
    begin
      Result := Root;
      Exit;
    end;
  end;
end;

// Probe a short curated list of likely install folders. Each check is a single
// filesystem hit, so the whole list is effectively instant.
function DetectExistingInstallDir(): String;
var
  Candidates: array of String;
  i: Integer;
begin
  Result := '';
  SetArrayLength(Candidates, 6);
  Candidates[0] := ExpandConstant('{sd}\SIERRA\BIRTHRT');
  Candidates[1] := 'C:\SIERRA\BIRTHRT';
  Candidates[2] := ExpandConstant('{commonpf}\Sierra\BIRTHRT');
  Candidates[3] := ExpandConstant('{commonpf32}\Sierra\BIRTHRT');
  Candidates[4] := ExpandConstant('{commonpf}\Sierra\Birthright');
  Candidates[5] := ExpandConstant('{commonpf32}\Sierra\Birthright');
  for i := 0 to GetArrayLength(Candidates) - 1 do
  begin
    if DirHasGame(Candidates[i]) then
    begin
      Result := Candidates[i];
      Exit;
    end;
  end;
end;

// True for a target no tree delete should ever run against: a blank path, a
// drive root, the Windows tree, or a Program Files root. Guards the destructive
// uninstall steps.
function IsDangerousPath(Dir: String): Boolean;
var
  D, WinDir: String;
begin
  Result := True;
  D := Trim(Dir);
  if D = '' then
    Exit;
  D := RemoveBackslash(D);
  // Drive root such as "C:" (after the trailing backslash is stripped).
  if (Length(D) <= 2) then
    Exit;
  WinDir := RemoveBackslash(ExpandConstant('{win}'));
  if (CompareText(D, WinDir) = 0) or
     (CompareText(Copy(D, 1, Length(WinDir) + 1), WinDir + '\') = 0) then
    Exit;
  if (CompareText(D, RemoveBackslash(ExpandConstant('{sys}'))) = 0) or
     (CompareText(D, RemoveBackslash(ExpandConstant('{commonpf}'))) = 0) or
     (CompareText(D, RemoveBackslash(ExpandConstant('{commonpf32}'))) = 0) then
    Exit;
  Result := False;
end;

function GetCommandlineParam(const Prefix: String): String;
var
  i: Integer;
  P: String;
begin
  Result := '';
  for i := 1 to ParamCount do
  begin
    P := ParamStr(i);
    if CompareText(Copy(P, 1, Length(Prefix)), Prefix) = 0 then
    begin
      Result := Copy(P, Length(Prefix) + 1, MaxInt);
      Exit;
    end;
  end;
end;

// True when the exact flag (for example '/VERYSILENT') appears on the command
// line. Case-insensitive, whole-argument match.
function CmdLineParamExists(const Value: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if CompareText(ParamStr(i), Value) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

// Non-interactive CD path from the BIRTHRT_CD_PATH environment variable, used by
// the game test harness (issue #58). Empty when the variable is unset, in which
// case the /CDPATH= override or the picker is used.
function EnvCdPath(): String;
begin
  Result := Trim(GetEnv('BIRTHRT_CD_PATH'));
end;

// Non-interactive mode from the BIRTHRT_MODE environment variable. Returns
// 'INSTALL', 'PATCH', or '' when unset or unrecognized.
function EnvMode(): String;
var
  M: String;
begin
  M := Uppercase(Trim(GetEnv('BIRTHRT_MODE')));
  if (M = 'INSTALL') or (M = 'PATCH') then
    Result := M
  else
    Result := '';
end;
