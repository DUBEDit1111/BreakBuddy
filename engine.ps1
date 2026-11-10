# BreakBuddy engine: pure decision logic. No UI, no clock, no disk. buddy.ps1 and test.ps1 both dot-source this.
# Flow: Get-Action($State,$Now) -> action or $null; the caller shows it; Apply-Result($State,$Action,$Code,$Now) records the answer.
# Popup exit codes: 0 = ignored/timed out, 1..n = button number.
# Settings come from config.json (see config.example.json). Only hourly water is on by default.

# Built-in defaults. config.json overrides any of these; anything it leaves out keeps the default.
function Get-DefaultConfig {
    @{
        water    = @{ enabled = $true;  everyMinutes = 60 }
        stretch  = @{ enabled = $false; everyMinutes = 30 }
        breaks   = @{ enabled = $false; afterMinutes = 60; snoozeMinutes = 10; maxSnoozes = 3 }
        meals    = @()
        sleep    = @{ enabled = $false; bedtime = '23:00'; wake = '07:00'; windDownMinutes = 30; repeatMinutes = 15 }
        restDays = @()
    }
}

# Fixed tuning, not asked during setup.
$script:Tune = @{
    GapMin = 10            # a pause this long ends a work session
    InUseMin = 15          # "using the computer" = activity within the last 15 minutes
    SnoozeMin = 10; MaxSnooze = 3
    MealRepeatMin = 30     # ignored meal popup asks again after this
    RestRepeatMin = 90     # 'Just a little' on a rest day asks again after this
    BedEndAfterH = 4       # bedtime reminders stop this many hours past bedtime (or at wake, if sooner)
    BreakCycleCount = 3; BreakBackoffMin = 30; BreakPopupSec = 420
}

# "HH:mm" -> minutes after midnight. Throws on bad input so a broken config is caught at load.
function ConvertTo-Minutes([string]$Hm) {
    if ($Hm -notmatch '^\s*(\d{1,2}):(\d{2})\s*$') { throw "Time '$Hm' is not HH:mm (24-hour, e.g. 07:30)" }
    $h = [int]$Matches[1]; $m = [int]$Matches[2]
    if ($h -gt 23 -or $m -gt 59) { throw "Time '$Hm' is out of range" }
    $h * 60 + $m
}

# PowerShell 5.1 ConvertFrom-Json gives PSCustomObject; turn it into nested hashtables/arrays.
function ConvertTo-Hash($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hash $p.Value }; return $h
    }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) { return ,@(foreach ($x in $o) { ConvertTo-Hash $x }) }
    $o
}

# Merge user settings over defaults, validate, and precompute minute values. Sets $script:Cfg.
function Set-Config($User) {
    $c = Get-DefaultConfig
    if ($User) {
        foreach ($k in @($User.Keys)) {
            if ($c[$k] -is [hashtable] -and $User[$k] -is [hashtable]) {
                foreach ($kk in @($User[$k].Keys)) { $c[$k][$kk] = $User[$k][$kk] }
            } elseif ($k -in 'meals', 'restDays') { $c[$k] = @($User[$k] | Where-Object { $null -ne $_ }) }
        }
    }
    $days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    foreach ($d in $c.restDays) { if ($days -notcontains $d) { throw "Rest day '$d' must be a full English day name, e.g. Saturday" } }
    $c.mealList = @(foreach ($m in $c.meals) {
        $s = ConvertTo-Minutes $m.from; $e = ConvertTo-Minutes $m.to
        if ($e -le $s) { throw "Meal '$($m.name)': 'to' must be later than 'from' on the same day" }
        @{ Key = ($m.name -replace '\W', '').ToLower(); Name = $m.name; S = $s; E = $e; To = $m.to }
    })
    $c.bedMin = ConvertTo-Minutes $c.sleep.bedtime
    $c.wakeMin = ConvertTo-Minutes $c.sleep.wake
    $script:Cfg = $c
}

function Import-Config([string]$Path) {
    $u = if (Test-Path $Path) { ConvertTo-Hash (Get-Content $Path -Raw | ConvertFrom-Json) } else { $null }
    Set-Config $u
}

Set-Config $null

function New-State {
    @{
        Prompts = @(); LastPing = [datetime]'2000-01-01'; ResetAt = [datetime]'2000-01-01'
        BreakUntil = $null; BreakCount = 0; BreakSnoozes = 0; BreakNext = $null
        LastWater = $null; LastStretch = $null; Meals = @{}; Nights = @{}; Rest = @{}
    }
}

# Records one activity mark (keyboard/mouse, or an AI prompt ping), at most one per minute.
# Cap 1500 marks = 25 hours of continuous use.
function Add-Activity($State, [datetime]$At) {
    $ps = @($State.Prompts)
    if ($ps.Count -gt 0) {
        $last = ($ps | Sort-Object)[-1]
        if ($At -le $last -or ($At - $last).TotalSeconds -lt 60) { return }
    }
    $State.Prompts = @($ps + $At | Select-Object -Last 1500)
}

# Older state.xml files may lack keys; add them so the engine never indexes a missing key.
function Repair-State($State) {
    foreach ($k in 'Nights', 'Rest', 'Meals') { if (-not $State.ContainsKey($k)) { $State[$k] = @{} } }
    $State
}

# True when the computer was used within the last InUseMin minutes.
function Test-InUse($State, $Now) {
    $ps = @($State.Prompts | Sort-Object)
    if ($ps.Count -eq 0) { return $false }
    $last = $ps[$ps.Count - 1]
    ($Now - $last).TotalMinutes -lt $script:Tune.InUseMin -and $last -le $Now
}

# The bedtime whose reminder window (wind-down start .. end) contains $Now, or $null.
# Works for any bedtime, including after midnight or during the day (shift work).
function Get-Night($Now) {
    $c = $script:Cfg
    foreach ($off in -1, 0, 1) {
        $bed = $Now.Date.AddDays($off).AddMinutes($c.bedMin)
        $wakeAfter = $bed.Date.AddMinutes($c.wakeMin); if ($wakeAfter -le $bed) { $wakeAfter = $wakeAfter.AddDays(1) }
        $end = $bed.AddHours($script:Tune.BedEndAfterH); if ($wakeAfter -lt $end) { $end = $wakeAfter }
        $wind = $bed.AddMinutes(-$c.sleep.windDownMinutes)
        if ($Now -ge $wind -and $Now -lt $end) { return @{ Key = $bed.ToString('yyyy-MM-dd HH:mm'); Bed = $bed } }
    }
    $null
}

# Sleep window: from wind-down start until wake. Daytime reminders stay silent inside it.
function Test-Quiet($Now) {
    $c = $script:Cfg
    if (-not $c.sleep.enabled) { return $false }
    $start = ($c.bedMin - $c.sleep.windDownMinutes + 1440) % 1440
    $m = $Now.Hour * 60 + $Now.Minute
    if ($start -le $c.wakeMin) { return $m -ge $start -and $m -lt $c.wakeMin }
    $m -ge $start -or $m -lt $c.wakeMin
}

function Get-NightAction($State, $Now) {
    $c = $script:Cfg
    if (-not $c.sleep.enabled) { return $null }
    if (-not (Test-InUse $State $Now)) { return $null }
    $n = Get-Night $Now
    if (-not $n) { return $null }
    if (-not $State.Nights.ContainsKey($n.Key)) { $State.Nights[$n.Key] = @{ Wind = $false; Done = $false; Next = $null } }
    $ns = $State.Nights[$n.Key]
    if ($ns.Done) { return $null }
    if ($Now -lt $n.Bed) {
        if ($ns.Wind) { return $null }
        return @{ Type = 'winddown'; Key = $n.Key; Title = 'Wind down'
                  Msg = "Bed in $($c.sleep.windDownMinutes) minutes. Good moment to save, wrap up, and let the day land."
                  Buttons = @('Winding down'); Timeout = 300 }
    }
    if ($ns.Next -and $Now -lt $ns.Next) { return $null }
    return @{ Type = 'bedtime'; Key = $n.Key; Title = 'Bedtime'
              Msg = 'Time for sleep. Everything will still be here tomorrow.'
              Buttons = @('Going to bed', "$($c.sleep.repeatMinutes) more min"); Timeout = 300 }
}

# Contiguous work: activity marks since the last break, chained by gaps under GapMin.
function Get-Session($State, $Now) {
    $gap = $script:Tune.GapMin
    $ps = @($State.Prompts | Where-Object { $_ -gt $State.ResetAt } | Sort-Object)
    if ($ps.Count -eq 0) { return @{ Active = $false; WorkMin = 0 } }
    $last = $ps[$ps.Count - 1]
    if (($Now - $last).TotalMinutes -ge $gap) { return @{ Active = $false; WorkMin = 0 } }
    $start = $last
    for ($i = $ps.Count - 2; $i -ge 0; $i--) {
        if (($ps[$i + 1] - $ps[$i]).TotalMinutes -lt $gap) { $start = $ps[$i] } else { break }
    }
    @{ Active = $true; WorkMin = ($Now - $start).TotalMinutes }
}

function Get-Action($State, $Now) {
    $c = $script:Cfg; $t = $script:Tune
    $null = Repair-State $State
    $night = Get-NightAction $State $Now
    if ($night) { return $night }
    if (Test-Quiet $Now) { return $null }

    $dayKey = $Now.ToString('yyyy-MM-dd')
    if ($c.restDays -contains $Now.DayOfWeek.ToString() -and (Test-InUse $State $Now)) {
        if (-not $State.Rest.ContainsKey($dayKey)) { $State.Rest[$dayKey] = @{ Done = $false; Next = $null } }
        $rs = $State.Rest[$dayKey]
        if (-not $rs.Done -and (-not $rs.Next -or $Now -ge $rs.Next)) {
            return @{ Type = 'restday'; Key = $dayKey; Title = 'Rest day'
                      Msg = "It's $($Now.DayOfWeek), one of your rest days. Rest is part of the plan, not a break from it."
                      Buttons = @('Resting now', 'Just a little'); Timeout = 300 }
        }
    }

    if ($State.BreakUntil) {
        if ($Now -ge $State.BreakUntil) {
            return @{ Type = 'breakover'; Title = 'Break over'; Msg = 'Welcome back. Water in hand?'; Buttons = @('Back to it'); Timeout = 300 }
        }
        return $null
    }

    $s = Get-Session $State $Now
    if (-not $s.Active) {
        # Idle: break cycle forgets itself, water/stretch clocks start fresh when work resumes.
        $State.BreakCount = 0; $State.BreakSnoozes = 0; $State.BreakNext = $null
        $State.LastWater = $Now; $State.LastStretch = $Now
    } else {
        if (-not $State.LastWater)   { $State.LastWater = $Now }
        if (-not $State.LastStretch) { $State.LastStretch = $Now }
    }

    $b = $c.breaks
    if ($b.enabled -and $s.Active -and $s.WorkMin -ge $b.afterMinutes -and (-not $State.BreakNext -or $Now -ge $State.BreakNext)) {
        $btn = @('Taking 15', 'Taking 25')
        if ($State.BreakSnoozes -lt $b.maxSnoozes) { $btn += "Snooze $($b.snoozeMinutes)" }
        return @{ Type = 'break'; Title = 'Break time'
                  Msg = "You have been at the computer $([int]$s.WorkMin) minutes. Stand up, drink water, look away from the screen. Press Taking when you step away."
                  Buttons = $btn; Timeout = $t.BreakPopupSec }
    }

    if (Test-InUse $State $Now) {
        $nowMin = $Now.Hour * 60 + $Now.Minute
        foreach ($m in $c.mealList) {
            $k = $dayKey + '-' + $m.Key
            if (-not $State.Meals.ContainsKey($k)) { $State.Meals[$k] = @{ Done = $false; Next = $null; Snooze = 0 } }
            $ms = $State.Meals[$k]
            if ($ms.Done) { continue }
            if ($nowMin -lt $m.S -or $nowMin -ge $m.E) { continue }
            if ($ms.Next -and $Now -lt $ms.Next) { continue }
            $second = if ($ms.Snooze -lt $t.MaxSnooze) { "Snooze $($t.SnoozeMin)" } else { 'Skipping this meal' }
            return @{ Type = 'meal'; Key = $k; Title = "$($m.Name) time"
                      Msg = "$($m.Name) window is open until $($m.To). Eat something real."
                      Buttons = @('Ate', $second); Timeout = 300 }
        }
    }

    if ($s.Active) {
        $due = @()
        if ($c.water.enabled -and ($Now - $State.LastWater).TotalMinutes -ge $c.water.everyMinutes) { $due += 'water' }
        if ($c.stretch.enabled -and ($Now - $State.LastStretch).TotalMinutes -ge $c.stretch.everyMinutes) { $due += 'stretch' }
        if ($due.Count -gt 0) {
            $txt = @{ water = 'Drink some water.'; stretch = 'Stand up and stretch for a minute.' }
            return @{ Type = 'care'; Due = $due; Title = (($due -join ' + ').Substring(0, 1).ToUpper() + ($due -join ' + ').Substring(1))
                      Msg = (($due | ForEach-Object { $txt[$_] }) -join ' '); Buttons = @('Done'); Timeout = 120 }
        }
    }
    $null
}

function Apply-Result($State, $Action, $Code, $Now) {
    $c = $script:Cfg; $t = $script:Tune
    switch ($Action.Type) {
        'breakover' { $State.BreakUntil = $null }
        'winddown' { $State.Nights[$Action.Key].Wind = $true }
        'bedtime' {
            $ns = $State.Nights[$Action.Key]
            if ($Code -eq 1) { $ns.Done = $true } else { $ns.Next = $Now.AddMinutes($c.sleep.repeatMinutes) }
        }
        'restday' {
            $rs = $State.Rest[$Action.Key]
            if ($Code -eq 1) { $rs.Done = $true } else { $rs.Next = $Now.AddMinutes($t.RestRepeatMin) }
        }
        'break' {
            if ($Code -eq 1 -or $Code -eq 2) {
                $len = if ($Code -eq 1) { 15 } else { 25 }
                $State.BreakUntil = $Now.AddMinutes($len)
                $State.ResetAt = $State.BreakUntil
                $State.BreakCount = 0; $State.BreakSnoozes = 0; $State.BreakNext = $null
                $State.LastWater = $State.BreakUntil; $State.LastStretch = $State.BreakUntil
            } elseif ($Code -eq 3) {
                $State.BreakSnoozes++
                $State.BreakNext = $Now.AddMinutes($c.breaks.snoozeMinutes)
            } else {
                $State.BreakCount++
                if ($State.BreakCount -ge $t.BreakCycleCount) {
                    $State.BreakCount = 0
                    $State.BreakNext = $Now.AddMinutes($t.BreakBackoffMin)
                }
            }
        }
        'meal' {
            $ms = $State.Meals[$Action.Key]
            if ($Code -eq 1) { $ms.Done = $true }
            elseif ($Code -eq 2) {
                if ($ms.Snooze -lt $t.MaxSnooze) { $ms.Snooze++; $ms.Next = $Now.AddMinutes($t.SnoozeMin) }
                else { $ms.Done = $true; $ms.Skipped = $true }
            } else { $ms.Next = $Now.AddMinutes($t.MealRepeatMin) }
        }
        'care' {
            foreach ($d in $Action.Due) {
                if ($Code -eq 1) {
                    if ($d -eq 'water') { $State.LastWater = $Now } else { $State.LastStretch = $Now }
                } else {
                    # ignored: ask again in SnoozeMin minutes
                    if ($d -eq 'water') { $State.LastWater = $Now.AddMinutes($t.SnoozeMin - $c.water.everyMinutes) }
                    else { $State.LastStretch = $Now.AddMinutes($t.SnoozeMin - $c.stretch.everyMinutes) }
                }
            }
        }
    }
}
