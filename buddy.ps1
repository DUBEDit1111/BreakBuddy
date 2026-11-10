# BreakBuddy: background reminder loop (also the popup renderer when called with -Popup).
# Watches keyboard/mouse use (plus optional AI-prompt pings via ping.txt) and reads settings from config.json.
# Popup = a slowly turning Metatron's Cube that "speaks" through a speech bubble, bottom-right of the screen.
param(
    [switch]$Popup, [string]$Title, [string]$Msg, [string]$Buttons, [int]$Timeout = 300, [string]$Snap
)
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Popup) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $script:code = 0
    $script:ang = 0.0

    # Shape: disc (cube) + rounded bubble with a tail pointing at the cube. Same path shapes drive Region and painting.
    $discRect = New-Object Drawing.Rectangle(10, 50, 200, 200)
    $bx = 225; $by = 30; $bw = 325; $bh = 240; $r = 22
    $bubble = New-Object Drawing.Drawing2D.GraphicsPath
    $bubble.AddArc($bx, $by, 2 * $r, 2 * $r, 180, 90)
    $bubble.AddArc($bx + $bw - 2 * $r, $by, 2 * $r, 2 * $r, 270, 90)
    $bubble.AddArc($bx + $bw - 2 * $r, $by + $bh - 2 * $r, 2 * $r, 2 * $r, 0, 90)
    $bubble.AddArc($bx, $by + $bh - 2 * $r, 2 * $r, 2 * $r, 90, 90)
    $bubble.AddLine($bx, 175, 203, 150)
    $bubble.AddLine(203, 150, $bx, 125)
    $bubble.CloseFigure()
    $disc = New-Object Drawing.Drawing2D.GraphicsPath
    $disc.AddEllipse($discRect)
    $region = New-Object Drawing.Region($bubble)
    $region.Union($disc)

    # Metatron's Cube: 13 circles (centre + 6 inner + 6 outer), every centre joined to every other.
    $R = 29.0
    $pts = New-Object 'System.Collections.Generic.List[Drawing.PointF]'
    $pts.Add((New-Object Drawing.PointF(0, 0)))
    foreach ($ring in 1, 2) {
        for ($k = 0; $k -lt 6; $k++) {
            $a = ($k * 60 - 90) * [math]::PI / 180
            $pts.Add((New-Object Drawing.PointF([float]($ring * $R * [math]::Cos($a)), [float]($ring * $R * [math]::Sin($a)))))
        }
    }
    $penLine = New-Object Drawing.Pen([Drawing.Color]::FromArgb(110, 232, 200, 120), 1)
    $penCirc = New-Object Drawing.Pen([Drawing.Color]::FromArgb(170, 150, 130, 255), 1.4)
    $penEdge = New-Object Drawing.Pen([Drawing.Color]::FromArgb(255, 232, 200, 120), 2.5)
    $brDark = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 22, 20, 44))
    $brDisc = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 14, 12, 32))

    $f = New-Object Windows.Forms.Form
    $f.FormBorderStyle = 'None'; $f.ShowInTaskbar = $false; $f.TopMost = $true
    $f.BackColor = [Drawing.Color]::FromArgb(255, 22, 20, 44)
    $f.ClientSize = New-Object Drawing.Size(560, 300)
    $f.Region = $region
    $f.StartPosition = 'Manual'
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $f.Location = New-Object Drawing.Point(($wa.Right - 560 - 10), ($wa.Bottom - 300 - 10))
    $f.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($f, $true)

    $f.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $g.FillPath($brDark, $bubble); $g.DrawPath($penEdge, $bubble)
        $g.FillEllipse($brDisc, $discRect); $g.DrawEllipse($penEdge, $discRect)
        $st = $g.Save()
        $g.TranslateTransform(110, 150); $g.RotateTransform([float]$script:ang)
        for ($i = 0; $i -lt $pts.Count; $i++) { for ($j = $i + 1; $j -lt $pts.Count; $j++) { $g.DrawLine($penLine, $pts[$i], $pts[$j]) } }
        foreach ($p in $pts) { $g.DrawEllipse($penCirc, $p.X - $R, $p.Y - $R, 2 * $R, 2 * $R) }
        $g.Restore($st)
    })

    $tl = New-Object Windows.Forms.Label
    $tl.Text = $Title; $tl.Font = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)
    $tl.ForeColor = [Drawing.Color]::FromArgb(255, 232, 200, 120); $tl.BackColor = [Drawing.Color]::Transparent
    $tl.Location = New-Object Drawing.Point(245, 44); $tl.Size = New-Object Drawing.Size(285, 30)
    $f.Controls.Add($tl)
    $ml = New-Object Windows.Forms.Label
    $ml.Text = $Msg; $ml.Font = New-Object Drawing.Font('Segoe UI', 11)
    $ml.ForeColor = [Drawing.Color]::FromArgb(255, 235, 232, 250); $ml.BackColor = [Drawing.Color]::Transparent
    $ml.Location = New-Object Drawing.Point(245, 80); $ml.Size = New-Object Drawing.Size(285, 110)
    $f.Controls.Add($ml)

    $names = $Buttons -split '\|'
    $w = [int](285 / $names.Count) - 6
    for ($i = 0; $i -lt $names.Count; $i++) {
        $b = New-Object Windows.Forms.Button
        $b.Text = $names[$i]; $b.Tag = $i + 1; $b.Font = New-Object Drawing.Font('Segoe UI', 10)
        $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(255, 232, 200, 120)
        $b.BackColor = [Drawing.Color]::FromArgb(255, 44, 38, 84); $b.ForeColor = [Drawing.Color]::White
        $b.Size = New-Object Drawing.Size($w, 40); $b.Location = New-Object Drawing.Point((245 + $i * ($w + 6)), 205)
        $b.Add_Click({ $script:code = [int]$this.Tag; $this.FindForm().Close() })
        $f.Controls.Add($b)
    }

    $spin = New-Object Windows.Forms.Timer; $spin.Interval = 40
    $spin.Add_Tick({ $script:ang += 0.5; $f.Invalidate($discRect) })
    $bell = New-Object Windows.Forms.Timer; $bell.Interval = 20000
    $bell.Add_Tick({ [System.Media.SystemSounds]::Exclamation.Play() })
    $kill = New-Object Windows.Forms.Timer; $kill.Interval = $Timeout * 1000
    $kill.Add_Tick({ $script:code = 0; $f.Close() })
    $f.Add_Shown({
        [System.Media.SystemSounds]::Exclamation.Play(); $f.Activate()
        $spin.Start(); $bell.Start(); $kill.Start()
        if ($Snap) {
            $script:snapT = New-Object Windows.Forms.Timer; $script:snapT.Interval = 700
            $snapT.Add_Tick({
                $script:snapT.Stop()
                $bmp = New-Object Drawing.Bitmap(560, 300)
                $f.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, 560, 300)))
                $bmp.Save($Snap, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
                $f.Close()
            })
            $script:snapT.Start()
        }
    })
    [void]$f.ShowDialog()
    exit $script:code
}

. (Join-Path $Root 'engine.ps1')
$ping = Join-Path $Root 'ping.txt'
$stateFile = Join-Path $Root 'state.xml'
$logFile = Join-Path $Root 'buddy.log'
$configFile = Join-Path $Root 'config.json'
function Log($t) { Add-Content -Path $logFile -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $t) }

# Loads config.json; on a bad file keeps the last good settings and logs why. Re-read whenever the file changes.
$script:configStamp = $null
function Update-Config {
    $stamp = if (Test-Path $configFile) { (Get-Item $configFile).LastWriteTime } else { [datetime]::MinValue }
    if ($stamp -eq $script:configStamp) { return }
    $script:configStamp = $stamp
    try { Import-Config $configFile; Log 'config loaded' } catch { Log "config error (keeping previous settings): $($_.Exception.Message)" }
}

# Seconds since the last keyboard or mouse input anywhere in this login session.
Add-Type -Namespace BB -Name Idle -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
[DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
public static double Seconds() {
    LASTINPUTINFO i = new LASTINPUTINFO(); i.cbSize = (uint)Marshal.SizeOf(i);
    if (!GetLastInputInfo(ref i)) return -1;
    return (unchecked((uint)Environment.TickCount - i.dwTime)) / 1000.0;
}
'@
$ActiveIdleSec = 60   # input within the last minute counts as "at the computer"

$mutex = New-Object Threading.Mutex($false, 'Global\BreakBuddy')
if (-not $mutex.WaitOne(0)) { exit }

$State = if (Test-Path $stateFile) { try { Import-Clixml $stateFile } catch { New-State } } else { New-State }
Log 'started'

while ($true) {
    try {
        Update-Config
        $Now = Get-Date
        if (Test-Path $ping) {
            $mt = (Get-Item $ping).LastWriteTime
            if ($mt -gt $State.LastPing) {
                $State.LastPing = $mt
                Add-Activity $State $mt
            }
        }
        $idle = [BB.Idle]::Seconds()
        if ($idle -ge 0 -and $idle -lt $ActiveIdleSec) { Add-Activity $State $Now.AddSeconds(-$idle) }
        $a = Get-Action $State $Now
        if ($a) {
            Log "popup $($a.Type): $($a.Title)"
            $argLine = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{0}" -Popup -Title "{1}" -Msg "{2}" -Buttons "{3}" -Timeout {4}' -f `
                (Join-Path $Root 'buddy.ps1'), $a.Title, $a.Msg, ($a.Buttons -join '|'), $a.Timeout
            $p = Start-Process powershell.exe -ArgumentList $argLine -PassThru -Wait -WindowStyle Hidden
            Apply-Result $State $a $p.ExitCode (Get-Date)
            Log "  answer code $($p.ExitCode)"
        }
        $State | Export-Clixml $stateFile
    } catch { Log "error: $($_.Exception.Message)" }
    Start-Sleep -Seconds 15
}
