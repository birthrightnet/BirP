<#
    HarnessCore.psm1 - core primitives for the BirP automated test harness (issue #58).

    Drives the deployed Windows build (WINBR.EXE) as an external user would: launch
    it, find its window, capture the client area, inject clicks/keys, compare frames
    against references, and watch the log for errors/crashes.

    Design notes (see bugs-and-enhancement-requests/docs-58-*.md):
      - The patched Windows build runs windowed in GDI mode, window class "Birthright".
      - It reads the mouse by polling GetCursorPos + GetAsyncKeyState, so a click needs
        a real cursor move + real button press (not window messages).
      - Startup is slow (~40 s); wait generously for the window.
      - Capture works even when the window is not foreground (PrintWindow).
      - Isolation-agnostic: today this runs on the normal desktop (a run commandeers the
        mouse); a VM guest is the planned unobtrusive mode.

    Windows PowerShell 5.1 compatible. No external dependencies.
#>

Set-StrictMode -Version Latest

# The Open Watcom build environment leaks LIB/INCLUDE into the C# compiler that
# Add-Type uses, and its invalid paths become warnings-as-errors. Neutralize for
# this process before compiling inline C#.
$env:LIB = ''
$env:INCLUDE = ''

if (-not ([System.Management.Automation.PSTypeName]'BirpHarness').Type) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public static class BirpHarness {
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int max);
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    public const uint LEFTDOWN = 0x0002, LEFTUP = 0x0004, RIGHTDOWN = 0x0008, RIGHTUP = 0x0010;
    public const uint WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101;

    public static string ClassOf(IntPtr h) { var sb = new StringBuilder(256); GetClassName(h, sb, sb.Capacity); return sb.ToString(); }

    // Find the game's main window for a PID: prefer class "Birthright", else the
    // largest visible top-level window. Returns IntPtr.Zero if none yet.
    public static IntPtr FindGameWindow(uint pid) {
        IntPtr birp = IntPtr.Zero, best = IntPtr.Zero; long bestArea = -1;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            uint wpid; GetWindowThreadProcessId(h, out wpid);
            if (wpid != pid || !IsWindowVisible(h)) return true;
            if (ClassOf(h) == "Birthright") { birp = h; }
            RECT rc; GetClientRect(h, out rc);
            long area = (long)(rc.Right - rc.Left) * (rc.Bottom - rc.Top);
            if (area > bestArea) { bestArea = area; best = h; }
            return true;
        }, IntPtr.Zero);
        return birp != IntPtr.Zero ? birp : best;
    }

    // First top-level window with this class name, or IntPtr.Zero.
    // FindWindow does not reliably see the game's own registered classes from
    // another process here, but walking the top-level list does.
    public static IntPtr FindTopLevelByClass(string cls) {
        IntPtr hit = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            if (ClassOf(h) == cls) { hit = h; return false; }
            return true;
        }, IntPtr.Zero);
        return hit;
    }

    public static int ClientWidth(IntPtr h) { RECT rc; GetClientRect(h, out rc); return rc.Right - rc.Left; }
    public static int ClientHeight(IntPtr h) { RECT rc; GetClientRect(h, out rc); return rc.Bottom - rc.Top; }

    // Capture the window's client area to a PNG. Returns false if the client is empty.
    public static bool CaptureClientToFile(IntPtr h, string path) {
        RECT rc; GetClientRect(h, out rc);
        int w = rc.Right - rc.Left, ht = rc.Bottom - rc.Top;
        if (w <= 0 || ht <= 0) return false;
        using (Bitmap bmp = new Bitmap(w, ht, PixelFormat.Format24bppRgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                PrintWindow(h, hdc, 3); // PW_RENDERFULLCONTENT | PW_CLIENTONLY
                g.ReleaseHdc(hdc);
            }
            bmp.Save(path, ImageFormat.Png);
        }
        return true;
    }

    // Fraction (0..1) of sampled pixels that differ beyond a small threshold.
    public static double DiffFractionFiles(string a, string b) {
        return DiffFractionFilesRegion(a, b, 0.0, 0.0, 1.0, 1.0);
    }

    // As DiffFractionFiles, but only over a sub-rectangle given as fractions of the
    // image (fx,fy = top-left; fw,fh = width/height; each 0..1). Use this to ignore
    // animated regions - e.g. the scrolling map behind a static menu.
    public static double DiffFractionFilesRegion(string a, string b, double fx, double fy, double fw, double fh) {
        using (Bitmap ba = new Bitmap(a)) using (Bitmap bb = new Bitmap(b)) {
            int w = Math.Min(ba.Width, bb.Width), h = Math.Min(ba.Height, bb.Height);
            int x0 = (int)(fx * w), y0 = (int)(fy * h);
            int x1 = (int)((fx + fw) * w), y1 = (int)((fy + fh) * h);
            if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0;
            if (x1 > w) x1 = w; if (y1 > h) y1 = h;
            if (x1 <= x0 || y1 <= y0) return 0.0;
            int sx = Math.Max(1, (x1 - x0) / 160), sy = Math.Max(1, (y1 - y0) / 160);
            int total = 0, diff = 0;
            for (int y = y0; y < y1; y += sy) for (int x = x0; x < x1; x += sx) {
                Color ca = ba.GetPixel(x, y), cb = bb.GetPixel(x, y);
                int d = Math.Abs(ca.R - cb.R) + Math.Abs(ca.G - cb.G) + Math.Abs(ca.B - cb.B);
                total++; if (d > 40) diff++;
            }
            return total == 0 ? 0.0 : (double)diff / total;
        }
    }

    // Click at a client-space point: bring the window forward, move the real cursor,
    // press and release the left button (the game polls cursor + async button state).
    public static void ClickClient(IntPtr h, int cx, int cy) {
        POINT p; p.X = cx; p.Y = cy; ClientToScreen(h, ref p);
        SetForegroundWindow(h);
        System.Threading.Thread.Sleep(250);
        SetCursorPos(p.X, p.Y);
        System.Threading.Thread.Sleep(120);
        mouse_event(LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        mouse_event(LEFTUP, 0, 0, 0, IntPtr.Zero);
    }

    // Press and release a key on the game window. The game keeps its own key table
    // and fills it from WM_KEYDOWN/WM_KEYUP in its own window procedure, so a posted
    // message is read exactly like a typed key. Post rather than synthesize with
    // keybd_event: that route needs the window to hold real keyboard focus, which a
    // test cannot rely on getting, and a dropped key looks like a broken hot key.
    public static void SendKey(IntPtr h, int vk) {
        uint sc = MapVirtualKey((uint)vk, 0);
        IntPtr down = (IntPtr)(1 | (int)(sc << 16));
        IntPtr up   = (IntPtr)(1 | (int)(sc << 16) | (1 << 30) | (1 << 31));
        PostMessage(h, WM_KEYDOWN, (IntPtr)vk, down);
        System.Threading.Thread.Sleep(120);
        PostMessage(h, WM_KEYUP, (IntPtr)vk, up);
    }

    public static bool IsForeground(IntPtr h) { return GetForegroundWindow() == h; }
}
'@
}

# ---------------------------------------------------------------------------
# PowerShell wrappers
# ---------------------------------------------------------------------------

function Get-BirpInstallDir {
    <# Resolve the install dir: explicit arg, else BIRTHRT_INSTALL_DIR, else default. #>
    param([string]$InstallDir)
    if ($InstallDir) { return $InstallDir }
    $env = [Environment]::GetEnvironmentVariable('BIRTHRT_INSTALL_DIR', 'User')
    if ($env) { return $env }
    return 'C:\Sierra\BIRTHRT'
}

function Get-BirpCdIso {
    <#
      Resolve the Birthright game CD image: explicit arg, else BIRTHRT_CD_ISO env
      var. Used by both Desktop and VM modes to install the official game content.
      Throws if not set or missing.
    #>
    param([string]$CdIso)
    if (-not $CdIso) { $CdIso = [Environment]::GetEnvironmentVariable('BIRTHRT_CD_ISO', 'User') }
    if (-not $CdIso) { throw "Birthright CD image not configured. Set BIRTHRT_CD_ISO (or pass -CdIso) to the path of your Birthright CD .iso." }
    if (-not (Test-Path -LiteralPath $CdIso -PathType Leaf)) { throw "Birthright CD image not found: $CdIso" }
    return (Resolve-Path -LiteralPath $CdIso).Path
}

function Get-BirpWinIso {
    <#
      Resolve the Windows OS install image for VM mode: explicit arg, else
      BIRTHRT_WIN_ISO env var. VM mode only - Desktop mode never needs this.
      Throws if not set or missing.
    #>
    param([string]$WinIso)
    if (-not $WinIso) { $WinIso = [Environment]::GetEnvironmentVariable('BIRTHRT_WIN_ISO', 'User') }
    if (-not $WinIso) { throw "Windows OS image not configured. Set BIRTHRT_WIN_ISO (or pass -WinIso) to the path of your Windows install .iso (VM mode only)." }
    if (-not (Test-Path -LiteralPath $WinIso -PathType Leaf)) { throw "Windows OS image not found: $WinIso" }
    return (Resolve-Path -LiteralPath $WinIso).Path
}

function Mount-BirpIso {
    <# Mount an .iso on the host and return its drive letter root (e.g. 'E:\'). #>
    param([Parameter(Mandatory)][string]$IsoPath)
    $img = Mount-DiskImage -ImagePath $IsoPath -PassThru
    Start-Sleep -Milliseconds 500
    $vol = $img | Get-Volume
    if (-not $vol -or -not $vol.DriveLetter) { throw "Mounted $IsoPath but could not resolve a drive letter." }
    return ("{0}:\" -f $vol.DriveLetter)
}

function Dismount-BirpIso {
    <# Dismount a previously mounted .iso (best-effort). #>
    param([Parameter(Mandatory)][string]$IsoPath)
    try { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction Stop | Out-Null } catch {}
}

function Start-BirpGame {
    <# Launch WINBR.EXE from the install dir. Returns the Process object. #>
    param([Parameter(Mandatory)][string]$InstallDir)
    $exe = Join-Path $InstallDir 'WINBR.EXE'
    if (-not (Test-Path $exe)) { throw "WINBR.EXE not found at $exe" }
    return Start-Process -FilePath $exe -WorkingDirectory $InstallDir -PassThru
}

function Wait-BirpWindow {
    <# Wait up to TimeoutSec for the game's Birthright window; return its HWND (IntPtr). #>
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [int]$TimeoutSec = 90,
        [int]$MinClientWidth = 600
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ($Process.HasExited) { throw "Game process exited during startup (code $($Process.ExitCode))." }
        $h = [BirpHarness]::FindGameWindow([uint32]$Process.Id)
        if ($h -ne [IntPtr]::Zero -and [BirpHarness]::ClientWidth($h) -ge $MinClientWidth) { return $h }
        Start-Sleep -Milliseconds 500
    }
    throw "Timed out after ${TimeoutSec}s waiting for the Birthright game window."
}

function Get-BirpClientSize {
    param([Parameter(Mandatory)][IntPtr]$Hwnd)
    return [pscustomobject]@{ Width = [BirpHarness]::ClientWidth($Hwnd); Height = [BirpHarness]::ClientHeight($Hwnd) }
}

function Save-BirpFrame {
    <# Capture the client area to a PNG file. Returns the path. #>
    param([Parameter(Mandatory)][IntPtr]$Hwnd, [Parameter(Mandatory)][string]$Path)
    if (-not [BirpHarness]::CaptureClientToFile($Hwnd, $Path)) { throw "Capture failed (empty client area)." }
    return $Path
}

function Wait-BirpStable {
    <#
      Poll the frame until it stops changing (settles), or TimeoutSec elapses.
      Returns the path to the final stable frame.
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$Hwnd,
        [int]$TimeoutSec = 15,
        [int]$IntervalMs = 500,
        [double]$StableThreshold = 0.003,
        [int]$RequiredStableFrames = 2
    )
    $tmpA = [System.IO.Path]::GetTempFileName() + '.png'
    $tmpB = [System.IO.Path]::GetTempFileName() + '.png'
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    [void][BirpHarness]::CaptureClientToFile($Hwnd, $tmpA)
    $stable = 0
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds $IntervalMs
        [void][BirpHarness]::CaptureClientToFile($Hwnd, $tmpB)
        $frac = [BirpHarness]::DiffFractionFiles($tmpA, $tmpB)
        Copy-Item $tmpB $tmpA -Force
        if ($frac -le $StableThreshold) {
            $stable++
            if ($stable -ge $RequiredStableFrames) { break }
        } else {
            $stable = 0
        }
    }
    Remove-Item $tmpB -ErrorAction SilentlyContinue
    return $tmpA
}

function Invoke-BirpClick {
    <#
      Click the game window. Specify EITHER client pixels (-X/-Y) OR fractions of the
      client area (-Fx/-Fy, 0..1). Fractions are resolution-independent.
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$Hwnd,
        [int]$X = -1, [int]$Y = -1,
        [double]$Fx = -1, [double]$Fy = -1
    )
    if ($Fx -ge 0 -and $Fy -ge 0) {
        $X = [int]([BirpHarness]::ClientWidth($Hwnd) * $Fx)
        $Y = [int]([BirpHarness]::ClientHeight($Hwnd) * $Fy)
    }
    if ($X -lt 0 -or $Y -lt 0) { throw "Invoke-BirpClick: provide -X/-Y or -Fx/-Fy." }
    [BirpHarness]::ClickClient($Hwnd, $X, $Y)
}

function Send-BirpKey {
    <#
      Press and release a key on the game window. Give either a single character
      (-Key 'A') or a virtual-key code (-VirtualKey 0x7A for F11).

      This is how to test a menu's underlined hot key. Injecting the key with the
      usual Windows input functions needs the game window to hold real keyboard
      focus, which is not reliable from a test, so the key is posted to the window
      instead - the game reads it from the same place either way.
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$Hwnd,
        [string]$Key,
        [int]$VirtualKey = -1
    )
    if ($Key) {
        if ($Key.Length -ne 1) { throw "Send-BirpKey: -Key takes a single character." }
        $VirtualKey = [int][char]([string]$Key).ToUpper()
    }
    if ($VirtualKey -lt 0) { throw "Send-BirpKey: provide -Key or -VirtualKey." }
    [BirpHarness]::SendKey($Hwnd, $VirtualKey)
}

function Open-BirpDebugWindow {
    <#
      Open the F11 debug test window and return its handle, or $null.

      DEBUG WIN builds only. F11 is registered against the screen underneath the
      game, and whatever is open on top handles keys instead, so this only works
      where nothing is open over the game - inside a running adventure or battle
      scene, not on a menu or a setup screen.
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$Hwnd,
        [int]$TimeoutSec = 15
    )
    Send-BirpKey -Hwnd $Hwnd -VirtualKey 0x7A          # VK_F11
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $dbg = [BirpHarness]::FindTopLevelByClass('BirpDebugTestWindow')
        if ($dbg -ne [IntPtr]::Zero) { return $dbg }
    }
    return $null
}

function Invoke-BirpDebugAction {
    <#
      Press one of the debug test window's buttons by its control id (the
      DBGWIND_CTL_* values in DBGWIND.CPP). The window closes itself and the
      game runs the action, which reports its result to winbr.log as well as
      on screen. Returns $true if the button was found and pressed.
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$DebugHwnd,
        [Parameter(Mandatory)][int]$ControlId
    )
    $btn = [BirpHarness]::GetDlgItem($DebugHwnd, $ControlId)
    if ($btn -eq [IntPtr]::Zero) { return $false }
    [void][BirpHarness]::SendMessage($btn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)   # BM_CLICK
    return $true
}

function Get-BirpLogLines {
    <#
      Return winbr.log lines written at or after SinceTime, optionally only those
      matching -Pattern. Use to read back what a debug action reported.
    #>
    param(
        [Parameter(Mandatory)][string]$InstallDir,
        [datetime]$SinceTime = [datetime]::MinValue,
        [string]$Pattern
    )
    $log = Join-Path $InstallDir 'winbr.log'
    if (-not (Test-Path $log)) { return @() }

    # The game holds the log open, so read it sharing write access.
    $lines = @()
    $fs = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        $sr = New-Object IO.StreamReader($fs)
        try { $lines = $sr.ReadToEnd() -split "`r?`n" } finally { $sr.Close() }
    } finally { $fs.Close() }

    $out = @()
    foreach ($line in $lines) {
        if ($line -notmatch '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') { continue }
        $ts = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
        if ($ts -lt $SinceTime) { continue }
        if ($Pattern -and $line -notmatch $Pattern) { continue }
        $out += $line
    }
    return $out
}

function Compare-BirpFrame {
    <# Fraction of sampled pixels that differ between two PNGs (0..1). #>
    param([Parameter(Mandatory)][string]$PathA, [Parameter(Mandatory)][string]$PathB)
    return [BirpHarness]::DiffFractionFiles($PathA, $PathB)
}

function Compare-BirpFrameRegion {
    <#
      Fraction of sampled pixels that differ between two PNGs, but only within a
      sub-rectangle given as fractions of the image: -Region @(fx, fy, fw, fh).
      Use to compare a static area while ignoring animated ones.
    #>
    param(
        [Parameter(Mandatory)][string]$PathA,
        [Parameter(Mandatory)][string]$PathB,
        [Parameter(Mandatory)][double[]]$Region
    )
    if ($Region.Count -ne 4) { throw "Compare-BirpFrameRegion: -Region must be @(fx, fy, fw, fh)." }
    return [BirpHarness]::DiffFractionFilesRegion($PathA, $PathB, $Region[0], $Region[1], $Region[2], $Region[3])
}

function Invoke-BirpClickUntilChanged {
    <#
      Click a spot repeatedly until the screen settles on something visibly different
      from a baseline frame, then return the path to that stable frame (or $null if it
      never changed within MaxClicks). Robust against animated/attract screens where a
      single click may land mid-animation and not register.

      Specify the click point as fractions of the client area (-Fx/-Fy).
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$Hwnd,
        [Parameter(Mandatory)][double]$Fx,
        [Parameter(Mandatory)][double]$Fy,
        [Parameter(Mandatory)][string]$BaselinePath,
        [int]$MaxClicks = 6,
        [double]$ChangeThreshold = 0.2,
        [int]$SettleTimeoutSec = 8
    )
    for ($i = 1; $i -le $MaxClicks; $i++) {
        Invoke-BirpClick -Hwnd $Hwnd -Fx $Fx -Fy $Fy
        $stable = Wait-BirpStable -Hwnd $Hwnd -TimeoutSec $SettleTimeoutSec
        $d = [BirpHarness]::DiffFractionFiles($BaselinePath, $stable)
        if ($d -gt $ChangeThreshold) { return $stable }
    }
    return $null
}

function Invoke-BirpClickUntilReference {
    <#
      Click a point (client fractions) until a region of the frame matches a reference
      image within MatchThreshold, or MaxClicks is exhausted. The current frame is
      checked BEFORE each click, so it also succeeds if already matched without
      clicking. Returns the path to the matching frame, or $null if it never matched.

      Use this to drive an attract/intro loop to a specific KNOWN screen (e.g. the main
      menu). Unlike Invoke-BirpClickUntilChanged, it stops only when it sees the target
      screen - not on any change - so it will not settle on an intermediate attract
      frame that merely differs from where it started.
    #>
    param(
        [Parameter(Mandatory)][IntPtr]$Hwnd,
        [Parameter(Mandatory)][double]$Fx,
        [Parameter(Mandatory)][double]$Fy,
        [Parameter(Mandatory)][string]$ReferencePath,
        [double[]]$Region,
        [int]$MaxClicks = 12,
        [double]$MatchThreshold = 0.10,
        [int]$SettleTimeoutSec = 8
    )
    if (-not (Test-Path -LiteralPath $ReferencePath)) { return $null }
    $tmp = [System.IO.Path]::GetTempFileName() + '.png'
    try {
        for ($i = 0; $i -le $MaxClicks; $i++) {
            [void][BirpHarness]::CaptureClientToFile($Hwnd, $tmp)
            if ($Region -and $Region.Count -eq 4) {
                $d = [BirpHarness]::DiffFractionFilesRegion($ReferencePath, $tmp, $Region[0], $Region[1], $Region[2], $Region[3])
            } else {
                $d = [BirpHarness]::DiffFractionFiles($ReferencePath, $tmp)
            }
            if ($d -le $MatchThreshold) { return $tmp }
            if ($i -eq $MaxClicks) { break }
            Invoke-BirpClick -Hwnd $Hwnd -Fx $Fx -Fy $Fy
            $null = Wait-BirpStable -Hwnd $Hwnd -TimeoutSec $SettleTimeoutSec
        }
    } catch {}
    return $null
}

function Get-BirpLogIssues {
    <#
      Return ERROR/WARN/FATAL lines from winbr.log written at or after SinceTime.
      The log lines start with a "[YYYY-MM-DD HH:MM:SS]" timestamp.
    #>
    param(
        [Parameter(Mandatory)][string]$InstallDir,
        [datetime]$SinceTime = [datetime]::MinValue
    )
    $log = Join-Path $InstallDir 'winbr.log'
    if (-not (Test-Path $log)) { return @() }
    $issues = @()
    foreach ($line in Get-Content $log) {
        if ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s*(ERROR|WARN|FATAL)') {
            $ts = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
            if ($ts -ge $SinceTime) { $issues += $line }
        }
    }
    return $issues
}

function Test-BirpCrash {
    <#
      Check for a crash since SinceTime: process exited unexpectedly, or a fresh
      Fatal.err appeared/grew. Returns $null if healthy, else a description string.
    #>
    param(
        [Parameter(Mandatory)][string]$InstallDir,
        [System.Diagnostics.Process]$Process,
        [datetime]$SinceTime = [datetime]::MinValue
    )
    if ($Process -and $Process.HasExited) { return "Process exited unexpectedly (code $($Process.ExitCode))." }
    $fatal = Join-Path $InstallDir 'Fatal.err'
    if (Test-Path $fatal) {
        $mt = (Get-Item $fatal).LastWriteTime
        if ($mt -ge $SinceTime) { return "Fatal.err written at $mt (crash dump present)." }
    }
    return $null
}

function Stop-BirpGame {
    <# Terminate the game process if still running. #>
    param([System.Diagnostics.Process]$Process)
    if ($Process -and -not $Process.HasExited) {
        try { $Process | Stop-Process -Force -ErrorAction Stop } catch {}
    }
}

Export-ModuleMember -Function Get-BirpInstallDir, Get-BirpCdIso, Get-BirpWinIso,
    Mount-BirpIso, Dismount-BirpIso, Start-BirpGame, Wait-BirpWindow,
    Get-BirpClientSize, Save-BirpFrame, Wait-BirpStable, Invoke-BirpClick, Send-BirpKey,
    Open-BirpDebugWindow, Invoke-BirpDebugAction, Get-BirpLogLines,
    Compare-BirpFrame, Compare-BirpFrameRegion, Invoke-BirpClickUntilChanged,
    Invoke-BirpClickUntilReference, Get-BirpLogIssues, Test-BirpCrash, Stop-BirpGame
