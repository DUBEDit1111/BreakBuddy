# BreakBuddy settings window: edits config.json with buttons instead of a text editor.
# Run: powershell -NoProfile -STA -ExecutionPolicy Bypass -File settings.ps1   (install.ps1 adds a Start menu shortcut)
# Saving validates through the same Set-Config the engine uses, so a bad value never reaches config.json.
# -ConfigPath, -Tab, -Snap and -AutoSave exist for tests and screenshots.
param([string]$ConfigPath, [int]$Tab = 0, [string]$Snap, [switch]$AutoSave)
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root 'engine.ps1')
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$configFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $Root 'config.json' }
$stateFile = Join-Path $Root 'state.xml'

# What the person wrote (kept so unknown keys survive a save) and the merged, validated settings shown in the form.
$User = @{}
$loadError = $null
if (Test-Path $configFile) {
    try { $User = ConvertTo-Hash (Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json); if (-not $User) { $User = @{} } }
    catch { $loadError = "config.json could not be read, showing defaults: $($_.Exception.Message)"; $User = @{} }
}
try { Set-Config $User } catch { $loadError = "config.json has a problem, showing defaults: $($_.Exception.Message)"; $User = @{}; Set-Config $null }
$c = $script:Cfg

$Dark = [Drawing.Color]::FromArgb(255, 22, 20, 44)
$Panel = [Drawing.Color]::FromArgb(255, 30, 27, 58)
$Gold = [Drawing.Color]::FromArgb(255, 232, 200, 120)
$Ink = [Drawing.Color]::FromArgb(255, 235, 232, 250)
$Dim = [Drawing.Color]::FromArgb(255, 170, 165, 200)
$Font = New-Object Drawing.Font('Segoe UI', 10)
$FontB = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)

function Add-Label($parent, [string]$text, [int]$x, [int]$y, [int]$w = 540, [int]$h = 24, $color = $Ink, $font = $Font) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object Drawing.Point($x, $y); $l.Size = New-Object Drawing.Size($w, $h)
    $l.ForeColor = $color; $l.BackColor = [Drawing.Color]::Transparent; $l.Font = $font
    $parent.Controls.Add($l); $l
}
function Add-Check($parent, [string]$text, [int]$x, [int]$y, [bool]$on, [int]$w = 400) {
    $k = New-Object Windows.Forms.CheckBox
    $k.Text = $text; $k.Location = New-Object Drawing.Point($x, $y); $k.Size = New-Object Drawing.Size($w, 26)
    $k.ForeColor = $Ink; $k.BackColor = [Drawing.Color]::Transparent; $k.Font = $Font; $k.Checked = $on
    $parent.Controls.Add($k); $k
}
function Add-Radio($parent, [string]$text, [int]$x, [int]$y, [int]$w = 400) {
    $r = New-Object Windows.Forms.RadioButton
    $r.Text = $text; $r.Location = New-Object Drawing.Point($x, $y); $r.Size = New-Object Drawing.Size($w, 26)
    $r.ForeColor = $Ink; $r.BackColor = [Drawing.Color]::Transparent; $r.Font = $Font
    $parent.Controls.Add($r); $r
}
function Add-Num($parent, [int]$x, [int]$y, [int]$min, [int]$max, $value) {
    $n = New-Object Windows.Forms.NumericUpDown
    $n.Minimum = $min; $n.Maximum = $max
    $n.Value = [math]::Min($max, [math]::Max($min, [int]$value))
    $n.Location = New-Object Drawing.Point($x, $y); $n.Size = New-Object Drawing.Size(64, 26); $n.Font = $Font
    $parent.Controls.Add($n); $n
}
function Add-Box($parent, [string]$text, [int]$x, [int]$y, [int]$w = 70) {
    $b = New-Object Windows.Forms.TextBox
    $b.Text = $text; $b.Location = New-Object Drawing.Point($x, $y); $b.Size = New-Object Drawing.Size($w, 26); $b.Font = $Font
    $parent.Controls.Add($b); $b
}
function Add-Grid($parent, [int]$y, [int]$h, $columns) {
    $g = New-Object Windows.Forms.DataGridView
    $g.Location = New-Object Drawing.Point(14, $y); $g.Size = New-Object Drawing.Size(564, $h)
    $g.AllowUserToAddRows = $true; $g.AllowUserToDeleteRows = $true; $g.RowHeadersWidth = 28
    $g.AutoSizeColumnsMode = 'Fill'; $g.ForeColor = [Drawing.Color]::Black; $g.DefaultCellStyle.ForeColor = [Drawing.Color]::Black; $g.BackgroundColor = $Panel; $g.BorderStyle = 'None'; $g.Font = $Font
    foreach ($col in $columns) {
        $dc = New-Object Windows.Forms.DataGridViewTextBoxColumn
        $dc.HeaderText = $col.Head; $dc.Name = $col.Name; $dc.FillWeight = $col.Weight
        [void]$g.Columns.Add($dc)
    }
    $parent.Controls.Add($g); $g
}
function Add-Page([string]$title) {
    $p = New-Object Windows.Forms.TabPage
    $p.Text = $title; $p.BackColor = $Panel; $p.UseVisualStyleBackColor = $false
    $tabs.TabPages.Add($p); $p
}

$f = New-Object Windows.Forms.Form
$f.Text = 'BreakBuddy settings'; $f.BackColor = $Dark; $f.ForeColor = $Ink; $f.Font = $Font
$f.ClientSize = New-Object Drawing.Size(620, 640); $f.StartPosition = 'CenterScreen'
$f.FormBorderStyle = 'FixedSingle'; $f.MaximizeBox = $false
$tabs = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object Drawing.Point(10, 10); $tabs.Size = New-Object Drawing.Size(600, 566); $tabs.Font = $Font
$f.Controls.Add($tabs)

# ---- Session timer ----
$pS = Add-Page 'Session timer'
$se = $c.session
$chkSession = Add-Check $pS 'Run a session timer: a work block, then a rest' 14 12 ([bool]$se.enabled) 540
$null = Add-Label $pS 'Rhythm' 14 46 540 24 $Gold $FontB
$rad60 = Add-Radio $pS '60 minutes of work, then 15 minutes of rest' 24 72
$rad90 = Add-Radio $pS '90 minutes of work, then 30 minutes of rest' 24 100
$radCustom = Add-Radio $pS 'Custom:' 24 128 90
$numWork = Add-Num $pS 118 128 1 600 $se.workMinutes
$null = Add-Label $pS 'min work, then' 188 131 100
$numRest = Add-Num $pS 290 128 1 240 $se.restMinutes
$null = Add-Label $pS 'min rest' 360 131 80
if ($se.workMinutes -eq 60 -and $se.restMinutes -eq 15) { $rad60.Checked = $true }
elseif ($se.workMinutes -eq 90 -and $se.restMinutes -eq 30) { $rad90.Checked = $true }
else { $radCustom.Checked = $true }
$syncCustom = { $numWork.Enabled = $radCustom.Checked; $numRest.Enabled = $radCustom.Checked }
$rad60.Add_CheckedChanged({ if ($rad60.Checked) { $numWork.Value = 60; $numRest.Value = 15 }; & $syncCustom })
$rad90.Add_CheckedChanged({ if ($rad90.Checked) { $numWork.Value = 90; $numRest.Value = 30 }; & $syncCustom })
$radCustom.Add_CheckedChanged($syncCustom)
& $syncCustom

$null = Add-Label $pS 'A session starts' 14 170 540 24 $Gold $FontB
$cmbStart = New-Object Windows.Forms.ComboBox
$cmbStart.DropDownStyle = 'DropDownList'; $cmbStart.Font = $Font
$cmbStart.Location = New-Object Drawing.Point(24, 198); $cmbStart.Size = New-Object Drawing.Size(520, 26)
[void]$cmbStart.Items.Add('When I send my AI a prompt (Claude Code and similar; needs the prompt hook)')
[void]$cmbStart.Items.Add('As soon as I use the computer')
$cmbStart.SelectedIndex = if ($se.startOn -eq 'prompt') { 0 } else { 1 }
$pS.Controls.Add($cmbStart)
$null = Add-Label $pS 'Snooze' 24 237 56
$numSSnooze = Add-Num $pS 82 234 1 120 $se.snoozeMinutes
$null = Add-Label $pS 'minutes, at most' 152 237 112
$numSMax = Add-Num $pS 266 234 0 20 $se.maxSnoozes
$null = Add-Label $pS 'times per session' 336 237 150
$lblStatus = Add-Label $pS '' 14 276 560 26 $Gold $FontB
$null = Add-Label $pS 'Why these timings' 14 316 540 24 $Gold $FontB
$facts = "Ultradian rhythm: the brain naturally works in high-focus cycles of about 90 minutes, then tires and needs to clear " +
    "a trough in its basic rest-activity cycle (BRAC).`r`n`r`n" +
    "Rest balance: productivity research puts the best rest at roughly 20 to 25% of work time. That is a 15 to 30 minute " +
    "break after a 90 minute push, or 15 minutes after 60.`r`n`r`n" +
    "Stepping away for as long as the rest counts as the rest: the session ends quietly and the next one starts fresh. " +
    "While the session timer is on it replaces the plain break reminder."
$null = Add-Label $pS $facts 14 342 560 180 $Dim

# ---- Reminders: water, stretch, breaks ----
$pR = Add-Page 'Reminders'
$null = Add-Label $pR 'Water' 14 14 540 24 $Gold $FontB
$chkWater = Add-Check $pR 'Remind me to drink water every' 24 40 ([bool]$c.water.enabled) 230
$numWater = Add-Num $pR 256 40 1 600 $c.water.everyMinutes
$null = Add-Label $pR 'minutes' 326 43 80
$null = Add-Label $pR ("Why hourly: Dr. Andrew Huberman recommends a baseline of about 8 ounces (240 mL) of fluid per hour " +
    "during the first 10 hours of your day while sitting or working at a desk.") 24 72 550 44 $Dim
$null = Add-Label $pR 'Stretch' 14 130 540 24 $Gold $FontB
$chkStretch = Add-Check $pR 'Remind me to stretch every' 24 156 ([bool]$c.stretch.enabled) 230
$numStretch = Add-Num $pR 256 156 1 600 $c.stretch.everyMinutes
$null = Add-Label $pR 'minutes' 326 159 80
$null = Add-Label $pR 'Breaks' 14 204 540 24 $Gold $FontB
$chkBreaks = Add-Check $pR 'Suggest a break after' 24 230 ([bool]$c.breaks.enabled) 230
$numBreakAfter = Add-Num $pR 256 230 1 600 $c.breaks.afterMinutes
$null = Add-Label $pR 'minutes of unbroken use' 326 233 200
$null = Add-Label $pR 'Snooze' 44 267 56
$numBSnooze = Add-Num $pR 102 264 1 120 $c.breaks.snoozeMinutes
$null = Add-Label $pR 'minutes, at most' 172 267 112
$numBMax = Add-Num $pR 286 264 0 20 $c.breaks.maxSnoozes
$null = Add-Label $pR 'times' 356 267 60
$null = Add-Label $pR 'The plain break reminder offers a 15 or 25 minute break. It stays silent while the session timer is on.' 24 302 550 44 $Dim
$null = Add-Label $pR 'Reminders only appear while you are using the computer.' 24 356 550 24 $Dim

# ---- Meals ----
$pM = Add-Page 'Meals and walks'
$null = Add-Label $pM 'Meals' 14 10 540 24 $Gold $FontB
$null = Add-Label $pM 'One row per meal. Times are 24-hour HH:mm, for example 12:30. Select a row and press Delete to remove it.' 14 34 564 40 $Dim
$gridMeals = Add-Grid $pM 78 170 @(@{ Head = 'Meal'; Name = 'name'; Weight = 50 }, @{ Head = 'Remind from'; Name = 'from'; Weight = 25 }, @{ Head = 'Give up at'; Name = 'to'; Weight = 25 })
foreach ($m in $c.meals) { [void]$gridMeals.Rows.Add("$($m.name)", "$($m.from)", "$($m.to)") }
$null = Add-Label $pM 'Walks' 14 262 540 24 $Gold $FontB
$null = Add-Label $pM 'Get outside for 15 to 20 minutes. A mid-morning walk (10:00 to 11:00) and an afternoon walk (15:00 to 17:00) work well.' 14 286 564 40 $Dim
$gridWalks = Add-Grid $pM 330 170 @(@{ Head = 'Walk'; Name = 'name'; Weight = 50 }, @{ Head = 'Remind from'; Name = 'from'; Weight = 25 }, @{ Head = 'Give up at'; Name = 'to'; Weight = 25 })
foreach ($m in $c.walks) { [void]$gridWalks.Rows.Add("$($m.name)", "$($m.from)", "$($m.to)") }

# ---- Sleep and rest days ----
$pZ = Add-Page 'Sleep and rest days'
$null = Add-Label $pZ 'Sleep' 14 14 540 24 $Gold $FontB
$chkSleep = Add-Check $pZ 'Remind me to go to bed' 24 40 ([bool]$c.sleep.enabled)
$null = Add-Label $pZ 'Bedtime' 44 77 70
$txtBed = Add-Box $pZ "$($c.sleep.bedtime)" 116 74
$null = Add-Label $pZ 'Wake' 216 77 50
$txtWake = Add-Box $pZ "$($c.sleep.wake)" 268 74
$null = Add-Label $pZ '24-hour HH:mm' 350 77 150 24 $Dim
$null = Add-Label $pZ 'Wind-down warning' 44 113 140
$numWind = Add-Num $pZ 186 110 0 240 $c.sleep.windDownMinutes
$null = Add-Label $pZ 'minutes before bed' 256 113 160
$null = Add-Label $pZ 'Repeat the bedtime reminder every' 44 149 240
$numRepeat = Add-Num $pZ 286 146 1 240 $c.sleep.repeatMinutes
$null = Add-Label $pZ 'minutes' 356 149 80
$null = Add-Label $pZ 'While sleep is on, daytime reminders stay quiet from the wind-down until wake time.' 24 184 550 24 $Dim
$chkSun = Add-Check $pZ 'Morning sunlight reminder in the first' 24 212 ([bool]$c.morningSun.enabled) 280
$numSun = Add-Num $pZ 306 212 1 600 $c.morningSun.withinMinutes
$null = Add-Label $pZ 'minutes after wake' 376 215 160
$null = Add-Label $pZ 'Rest days' 14 250 540 24 $Gold $FontB
$null = Add-Label $pZ 'One gentle nudge on these days that rest is part of the plan.' 24 276 550 24 $Dim
$dayNames = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
$chkDays = @{}
for ($i = 0; $i -lt 7; $i++) {
    $chkDays[$dayNames[$i]] = Add-Check $pZ $dayNames[$i] (24 + 140 * ($i % 4)) (304 + 28 * [math]::Floor($i / 4)) ($c.restDays -contains $dayNames[$i]) 130
}
$null = Add-Label $pZ 'Why sleep matters (Dr. Matthew Walker)' 14 368 540 24 $Gold $FontB
$sleepFacts = "Quantity: adults need 7 to 9 hours a night. Time in bed is not time asleep: 7 hours of real sleep usually takes " +
    "about 8 hours 15 minutes in bed.`r`n" +
    "Quality: sleep efficiency (share of time in bed spent asleep) should be 85% or higher.`r`n" +
    "Regularity: the same bedtime and wake time every day, weekends too, anchors your 24-hour body clock.`r`n" +
    "Timing: fit your sleep window to your chronotype, morning lark or night owl."
$null = Add-Label $pZ $sleepFacts 24 394 552 136 $Dim

# ---- Notes ----
$pN = Add-Page 'Notes'
$null = Add-Label $pN 'Your own reminders. Leave Date empty for every day (or use yyyy-MM-dd for one day). Leave Every empty for hourly. No double quotes.' 14 12 564 44 $Dim
$gridNotes = Add-Grid $pN 60 440 @(@{ Head = 'Title'; Name = 'title'; Weight = 22 }, @{ Head = 'Text'; Name = 'text'; Weight = 48 }, @{ Head = 'Date'; Name = 'date'; Weight = 16 }, @{ Head = 'Every (min)'; Name = 'everyMinutes'; Weight = 14 })
foreach ($n in $c.notes) { [void]$gridNotes.Rows.Add("$($n.title)", "$($n.text)", "$($n.date)", "$($n.everyMinutes)") }

# ---- Sleep guide (opened by the Sleep tips button on the wind-down popup: keep this the 6th tab, index 5) ----
$pG = Add-Page 'Sleep guide'
$null = Add-Label $pG "Dr. Matthew Walker's rules for sleep hygiene" 14 12 560 24 $Gold $FontB
$guide = "Cool room: set the bedroom to about 65 to 68 F (18 to 20 C). Your core temperature has to drop by 2 to 3 F to fall " +
    "asleep and stay asleep.`r`n`r`n" +
    "Darkness at night: dim the house lights by half or more in the last hour, put screens away 30 to 60 minutes before " +
    "bed, and use blackout curtains or an eye mask so melatonin can rise.`r`n`r`n" +
    "Morning sunlight: get outside into daylight within 60 minutes of waking. It anchors your body clock and brings a " +
    "healthy morning cortisol rise. Dr. Andrew Huberman: 5 to 10 minutes of outdoor morning light (15 to 30 on cloudy days) " +
    "within 30 to 60 minutes of waking, for body clock, mood, focus and sleep.`r`n`r`n" +
    "Stimulants and depressants: no caffeine after 12:00 noon (its half-life is about 6 hours) and no alcohol before bed. " +
    "Both break up sleep and block deep and REM stages.`r`n`r`n" +
    "The 25 minute rule: awake and cannot drift back after 25 to 30 minutes? Get up, go to a dimly lit room, read or listen " +
    "to a quiet podcast until sleepy. No phone, no food.`r`n`r`n" +
    "Warm bath effect: a hot bath or shower before bed draws blood to the skin, which sheds core heat, so your core " +
    "temperature falls right as you get into bed."
$null = Add-Label $pG $guide 14 44 564 440 $Ink
$null = Add-Label $pG 'General wellbeing guidance, not medical advice.' 14 496 564 24 $Dim

# ---- Bottom bar ----
$lblSaved = Add-Label $f '' 14 592 380 40 $Gold
if ($loadError) { $lblSaved.Text = $loadError }
function Add-Button([string]$text, [int]$x) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text; $b.Font = $Font; $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderColor = $Gold
    $b.BackColor = [Drawing.Color]::FromArgb(255, 44, 38, 84); $b.ForeColor = [Drawing.Color]::White
    $b.Size = New-Object Drawing.Size(100, 36); $b.Location = New-Object Drawing.Point($x, 590)
    $f.Controls.Add($b); $b
}
$btnSave = Add-Button 'Save' 400
$btnClose = Add-Button 'Close' 508
$btnClose.Add_Click({ $f.Close() })

function Get-Cell($row, [string]$name) { "$($row.Cells[$name].Value)".Trim() }

# Reads every control into a config hashtable (same shape as config.json). Unknown keys in the old file are kept.
function Read-Form {
    $out = [ordered]@{}
    $out.water = [ordered]@{ enabled = $chkWater.Checked; everyMinutes = [int]$numWater.Value }
    $out.stretch = [ordered]@{ enabled = $chkStretch.Checked; everyMinutes = [int]$numStretch.Value }
    $out.breaks = [ordered]@{ enabled = $chkBreaks.Checked; afterMinutes = [int]$numBreakAfter.Value; snoozeMinutes = [int]$numBSnooze.Value; maxSnoozes = [int]$numBMax.Value }
    $out.session = [ordered]@{
        enabled = $chkSession.Checked; workMinutes = [int]$numWork.Value; restMinutes = [int]$numRest.Value
        startOn = $(if ($cmbStart.SelectedIndex -eq 0) { 'prompt' } else { 'activity' })
        snoozeMinutes = [int]$numSSnooze.Value; maxSnoozes = [int]$numSMax.Value
    }
    $meals = @()
    foreach ($row in $gridMeals.Rows) {
        if ($row.IsNewRow) { continue }
        $name = Get-Cell $row 'name'; $from = Get-Cell $row 'from'; $to = Get-Cell $row 'to'
        if (-not ($name + $from + $to)) { continue }
        if (-not $name) { throw 'A meal row has no name.' }
        $meal = [ordered]@{ name = $name; from = $from; to = $to }
        # A meal's own text is not in the grid; keep it from the loaded config (matched by meal name).
        $old = @($c.meals | Where-Object { "$($_.name)" -eq $name })[0]
        if ($old -and "$($old.text)".Trim()) { $meal.text = "$($old.text)" }
        $meals += $meal
    }
    $out.meals = $meals
    $walks = @()
    foreach ($row in $gridWalks.Rows) {
        if ($row.IsNewRow) { continue }
        $name = Get-Cell $row 'name'; $from = Get-Cell $row 'from'; $to = Get-Cell $row 'to'
        if (-not ($name + $from + $to)) { continue }
        if (-not $name) { throw 'A walk row has no name.' }
        $walks += [ordered]@{ name = $name; from = $from; to = $to }
    }
    $out.walks = $walks
    $out.sleep = [ordered]@{ enabled = $chkSleep.Checked; bedtime = $txtBed.Text.Trim(); wake = $txtWake.Text.Trim(); windDownMinutes = [int]$numWind.Value; repeatMinutes = [int]$numRepeat.Value }
    $out.morningSun = [ordered]@{ enabled = $chkSun.Checked; withinMinutes = [int]$numSun.Value }
    $out.restDays = @($dayNames | Where-Object { $chkDays[$_].Checked })
    $notes = @()
    foreach ($row in $gridNotes.Rows) {
        if ($row.IsNewRow) { continue }
        $title = Get-Cell $row 'title'; $text = Get-Cell $row 'text'; $date = Get-Cell $row 'date'; $every = Get-Cell $row 'everyMinutes'
        if (-not ($title + $text + $date + $every)) { continue }
        $n = [ordered]@{}
        if ($title) { $n.title = $title }
        $n.text = $text
        if ($date) { $n.date = $date }
        if ($every) { if ($every -notmatch '^\d+$') { throw "Note '$text': Every must be a whole number of minutes." }; $n.everyMinutes = [int]$every }
        $notes += $n
    }
    $out.notes = $notes
    foreach ($k in $User.Keys) { if (-not $out.Contains($k)) { $out[$k] = $User[$k] } }
    $out
}

# Engine validation wants plain hashtables; turn the ordered form data into them without losing arrays.
function ConvertTo-Plain($o) {
    if ($o -is [System.Collections.IDictionary]) { $h = @{}; foreach ($k in $o.Keys) { $h[$k] = ConvertTo-Plain $o[$k] }; return $h }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) { return ,@(foreach ($x in $o) { ConvertTo-Plain $x }) }
    $o
}

function Update-Status {
    try {
        $st = if (Test-Path $stateFile) { Import-Clixml $stateFile } else { New-State }
        $lblStatus.Text = 'Now: ' + (Get-SessionStatus $st (Get-Date))
    } catch { $lblStatus.Text = '' }
}

$btnSave.Add_Click({
    try {
        $out = Read-Form
        Set-Config (ConvertTo-Plain $out)          # throws with a plain-language reason on any bad value
        $json = ($out | ConvertTo-Json -Depth 6) -replace '\\u0027', "'"
        [IO.File]::WriteAllText($configFile, $json + "`r`n", (New-Object Text.UTF8Encoding($false)))
        $script:User = ConvertTo-Plain $out
        $lblSaved.ForeColor = $Gold
        $lblSaved.Text = 'Saved. BreakBuddy picks it up within 15 seconds.'
        Update-Status
    } catch {
        $lblSaved.ForeColor = [Drawing.Color]::FromArgb(255, 255, 140, 130)
        $lblSaved.Text = "Not saved: $($_.Exception.Message)"
        try { Set-Config $User } catch { Set-Config $null }
    }
})

$tick = New-Object Windows.Forms.Timer; $tick.Interval = 5000
$tick.Add_Tick({ Update-Status })
$f.Add_Shown({
    Update-Status; $tick.Start()
    if ($Tab -gt 0 -and $Tab -lt $tabs.TabPages.Count) { $tabs.SelectedIndex = $Tab }
    if ($AutoSave) { $btnSave.PerformClick() }
    if ($Snap -or $AutoSave) {
        $script:snapT = New-Object Windows.Forms.Timer; $script:snapT.Interval = 700
        $script:snapT.Add_Tick({
            $script:snapT.Stop()
            if ($Snap) {
                $bmp = New-Object Drawing.Bitmap($f.Width, $f.Height)
                $f.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0, 0, $f.Width, $f.Height)))
                $bmp.Save($Snap, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
            }
            $f.Close()
        })
        $script:snapT.Start()
    }
})
[void]$f.ShowDialog()
