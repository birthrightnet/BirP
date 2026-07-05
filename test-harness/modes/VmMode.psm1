<#
    VmMode.psm1 - VM run mode for the BirP test harness (issue #58).

    Runs the whole smoke test inside a throwaway Windows guest so the developer's
    desktop is never touched. This is the unobtrusive mode; Desktop mode is the
    same test running directly on the host.

    STATUS: scaffolded, not yet enabled. Deferred on host disk space (docs-58 Q11 -
    a Windows guest needs ~50-65 GB free). The installer is now scriptable via
    BIRTHRT_CD_PATH (docs-58 Q14), so the install step is no longer a blocker. This
    module documents the intended pipeline and fails with a clear message until the
    disk space and guest exist.

    Intended pipeline (VBoxManage on the host):
      1. Resolve BIRTHRT_WIN_ISO (Windows OS image) and BIRTHRT_CD_ISO (game CD).
      2. Ensure a guest exists (create + unattended Windows install from the OS ISO
         the first time; otherwise reset to a clean snapshot).
      3. Attach the game CD ISO as the guest's virtual optical drive.
      4. Copy the harness + the built patch installer into the guest (guestcontrol
         copyto or a shared folder).
      5. In the guest, run our installer non-interactively to lay down the official
         game content (from the attached CD) plus the patch.
      6. In the guest, run this harness in Desktop mode against the fresh install.
      7. Copy the guest's run artifacts (screenshots, report) back to the host.
      8. Reset the guest to the clean snapshot.
#>

Set-StrictMode -Version Latest

function Invoke-BirpVmMode {
    param(
        [string]$Scenario = 'boot-and-menus',
        [string]$CdIso,
        [string]$WinIso,
        [Parameter(Mandatory)][string]$HarnessDir
    )

    Write-Host "VM mode is not yet enabled." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "It is deferred on two things (see bugs-and-enhancement-requests/docs-58):"
    Write-Host "  1. Host disk space - a Windows guest needs ~50-65 GB free (Q11)."
    Write-Host "  2. A non-interactive installer - our installer currently asks for the"
    Write-Host "     CD path in a wizard page, so it cannot be scripted yet (Q14)."
    Write-Host ""

    # Report what is and is not configured so the path to enabling it is clear.
    $status = [ordered]@{}
    try { $status['BIRTHRT_WIN_ISO'] = (Get-BirpWinIso -WinIso $WinIso) } catch { $status['BIRTHRT_WIN_ISO'] = "NOT SET ($($_.Exception.Message))" }
    try { $status['BIRTHRT_CD_ISO']  = (Get-BirpCdIso  -CdIso  $CdIso)  } catch { $status['BIRTHRT_CD_ISO']  = "NOT SET ($($_.Exception.Message))" }
    $vbox = Get-Command VBoxManage -ErrorAction SilentlyContinue
    $status['VBoxManage'] = if ($vbox) { $vbox.Source } else { 'NOT installed' }
    $free = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
    $status['C: free GB'] = [math]::Round($free / 1GB, 1)

    Write-Host "Current VM-mode prerequisites:"
    foreach ($k in $status.Keys) { Write-Host ("  {0,-16} : {1}" -f $k, $status[$k]) }
    Write-Host ""
    Write-Host "When those are ready, this module will provision the guest and run"
    Write-Host "'$Scenario' inside it. For now, use: -Mode Desktop." -ForegroundColor Cyan

    throw "VM mode not yet enabled (see the prerequisites above and docs-58)."
}

Export-ModuleMember -Function Invoke-BirpVmMode
