# Simulated-day tests for engine.ps1. Run: powershell -ExecutionPolicy Bypass -File test.ps1
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Here 'engine.ps1')
$fail = 0
function Check($name, $ok) { if ($ok) { Write-Host "PASS $name" } else { Write-Host "FAIL $name"; $script:fail++ } }

# Drives minute ticks. $promptEvery: minutes between prompts while 'typing'. $answer: scriptblock(action,now) -> code.
function Sim($State, [datetime]$from, [datetime]$to, $typeWhen, $answer) {
    $log = @(); $t = $from
    while ($t -le $to) {
        if (& $typeWhen $t) { $State.Prompts = @($State.Prompts) + $t }
        $a = Get-Action $State $t
        if ($a) {
            $code = & $answer $a $t
            $log += [pscustomobject]@{ At = $t.ToString('HH:mm'); Type = $a.Type; Code = $code; Title = $a.Title }
            Apply-Result $State $a $code $t
        }
        $t = $t.AddMinutes(1)
    }
    $log
}
$d = [datetime]'2026-10-30'
$typeAll = { param($t) $t.Minute % 5 -eq 0 }
$done = { param($a, $t) 1 }

# Tests 1-16 use a full schedule with every reminder on (the original author's).
$Full = @{
    stretch  = @{ enabled = $true; everyMinutes = 30 }
    breaks   = @{ enabled = $true; afterMinutes = 60 }
    meals    = @(
        @{ name = 'Breakfast'; from = '07:30'; to = '10:00' },
        @{ name = 'Lunch';     from = '11:30'; to = '15:00' },
        @{ name = 'Dinner';    from = '17:30'; to = '20:00' })
    sleep    = @{ enabled = $true; bedtime = '00:00'; wake = '08:00' }
    restDays = @('Saturday', 'Sunday')
}
Set-Config $Full

# 1. steady work from 10:00: stretch 10:30, break 11:00, hourly water right after (break wins the 11:00 tick)
$s = New-State
$log = Sim $s $d.AddHours(10) $d.AddHours(11).AddMinutes(5) $typeAll { param($a, $t) if ($a.Type -eq 'break') { 0 } else { 1 } }
Check 'stretch at 10:30' ($log | Where-Object { $_.At -eq '10:30' -and $_.Title -eq 'stretch' })
Check 'no water before 11:00' (-not ($log | Where-Object { $_.Title -match 'water' -and $_.At -lt '11:00' }))
Check 'water just after the 11:00 break' ($log | Where-Object { $_.Title -match 'water' -and $_.At -ge '11:00' -and $_.At -le '11:05' })
Check 'no break before 11:00' (-not ($log | Where-Object { $_.Type -eq 'break' -and $_.At -lt '11:00' }))
Check 'break at 11:00' ($log | Where-Object { $_.At -eq '11:00' -and $_.Type -eq 'break' })

# 2. ignored break: 3 popups, then 30 min backoff, snooze button hidden after 3 snoozes
$s = New-State
$null = Sim $s $d.AddHours(10) $d.AddHours(11) $typeAll { param($a, $t) if ($a.Type -eq 'break') { 0 } else { 1 } }
Check 'ignored once counted' ($s.BreakCount -eq 1)
$s.Prompts = @($s.Prompts) + $d.AddHours(11).AddMinutes(5) + $d.AddHours(11).AddMinutes(10)
$a1 = Get-Action $s $d.AddHours(11).AddMinutes(7)
$null = Apply-Result $s $a1 0 $d.AddHours(11).AddMinutes(7)
$a2 = Get-Action $s $d.AddHours(11).AddMinutes(14); Apply-Result $s $a2 0 $d.AddHours(11).AddMinutes(14)
Check 'third ignore starts backoff' ($s.BreakNext -eq $d.AddHours(11).AddMinutes(44))

# 3. pressing Taking 15 resets the clock; next break not before 60 min of new work
$s = New-State
$log = Sim $s $d.AddHours(10) $d.AddHours(13) $typeAll { param($a, $t) if ($a.Type -eq 'break') { 1 } else { 1 } }
$breaks = @($log | Where-Object { $_.Type -eq 'break' })
Check 'second break >= 60 min of work after first' ($breaks.Count -ge 2 -and ([datetime]::ParseExact($breaks[1].At, 'HH:mm', $null) - [datetime]::ParseExact($breaks[0].At, 'HH:mm', $null)).TotalMinutes -ge 75)
Check 'breakover popup fires' ($log | Where-Object { $_.Type -eq 'breakover' })

# 4. idle gap 15 min resets the work clock (no break at 11:00 if she paused 10:31-10:46)
$s = New-State
$typeGap = { param($t) $t.Minute % 5 -eq 0 -and -not ($t -gt $d.AddHours(10).AddMinutes(30) -and $t -lt $d.AddHours(10).AddMinutes(46)) }
$log = Sim $s $d.AddHours(10) $d.AddHours(11).AddMinutes(30) $typeGap $done
Check 'gap prevents 11:00 break' (-not ($log | Where-Object { $_.Type -eq 'break' -and $_.At -le '11:30' }))

# 5. lunch: nothing at 11:29, popup at 11:31 only if computer in use, Ate silences
$s = New-State
$log = Sim $s $d.AddHours(11).AddMinutes(20) $d.AddHours(12) { param($t) $t.Minute % 4 -eq 0 } $done
$meals = @($log | Where-Object { $_.Type -eq 'meal' })
Check 'one lunch popup after Ate' ($meals.Count -eq 1)
Check 'lunch not before 11:30' ($meals[0].At -ge '11:30')

# 6. computer idle, no meal popup
$s = New-State
$log = Sim $s $d.AddHours(11).AddMinutes(20) $d.AddHours(13) { param($t) $false } $done
Check 'no popups while idle' ($log.Count -eq 0)

# 7. late evening: only the wind-down speaks from 23:30 (daytime reminders quiet from wind-down until wake)
$s = New-State
$log = @(Sim $s $d.AddHours(23).AddMinutes(30) $d.AddHours(23).AddMinutes(59) $typeAll $done)
Check 'only wind-down 23:30-23:59' ($log.Count -eq 1 -and $log[0].Type -eq 'winddown' -and $log[0].At -eq '23:30')

# 9. bedtime: '15 more min' repeats every 15 min, 'Going to bed' silences the night
$s = New-State
$n = 0
$log = Sim $s $d.AddHours(23).AddMinutes(25) $d.AddHours(25) $typeAll { param($a, $t) if ($a.Type -eq 'bedtime') { $script:n++; if ($script:n -ge 3) { 1 } else { 2 } } else { 1 } }
$beds = @($log | Where-Object { $_.Type -eq 'bedtime' })
Check 'bedtime at 00:00' ($beds.Count -ge 1 -and $beds[0].At -eq '00:00')
Check 'bedtime repeats 00:15, 00:30' ($beds.Count -eq 3 -and $beds[1].At -eq '00:15' -and $beds[2].At -eq '00:30')
Check 'Going to bed silences night' (-not ($log | Where-Object { $_.Type -eq 'bedtime' -and $_.At -gt '00:30' -and $_.At -lt '12:00' }))
Check 'no water/stretch after midnight' (-not ($log | Where-Object { $_.Type -eq 'care' }))

# 10. computer idle at night, no bedtime popups
$s = New-State
$log = Sim $s $d.AddHours(23) $d.AddHours(27) { param($t) $false } $done
Check 'no bedtime while idle' ($log.Count -eq 0)

# 11. early morning work: nothing before 08:00 once bedtime window ends (old 06:00 water popup)
$s = New-State
$log = Sim $s $d.AddDays(1).AddHours(5) $d.AddDays(1).AddHours(7).AddMinutes(59) $typeAll $done
Check 'quiet 05:00-08:00' ($log.Count -eq 0)

# 12. rest day (Sat 2026-10-31): one gentle popup; 'Just a little' asks again after 90 min; 'Resting now' silences
$sat = [datetime]'2026-10-31'
$s = New-State
$k = 0
$log = Sim $s $sat.AddHours(10) $sat.AddHours(14) $typeAll { param($a, $t) if ($a.Type -eq 'restday') { $script:k++; if ($script:k -ge 2) { 1 } else { 2 } } else { 1 } }
$rests = @($log | Where-Object { $_.Type -eq 'restday' })
Check 'rest popup at 10:00' ($rests.Count -ge 1 -and $rests[0].At -eq '10:00')
Check 'rest re-ask at 11:30, then silent' ($rests.Count -eq 2 -and $rests[1].At -eq '11:30')

# 13. weekday: no rest popup
$s = New-State
$log = Sim $s $d.AddHours(10) $d.AddHours(12) $typeAll $done
Check 'no rest popup on Friday' (-not ($log | Where-Object { $_.Type -eq 'restday' }))

# 14. old state.xml without Nights/Rest keys still works
$s = New-State; $s.Remove('Nights'); $s.Remove('Rest')
$log = @(Sim $s $sat.AddHours(10) $sat.AddHours(10).AddMinutes(5) $typeAll $done)
Check 'old state repaired' ($s.ContainsKey('Nights') -and $s.ContainsKey('Rest') -and $log.Count -ge 1)

# 8. meal window closes
$s = New-State
$log = Sim $s $d.AddHours(15) $d.AddHours(15).AddMinutes(30) $typeAll $done
Check 'no lunch popup after 15:00' (-not ($log | Where-Object { $_.Type -eq 'meal' }))

# 15. activity recorder: one mark per minute, ignores older marks, caps at 1500
$s = New-State
$t0 = $d.AddHours(10)
foreach ($sec in 0, 15, 30, 45, 60, 75) { Add-Activity $s $t0.AddSeconds($sec) }
Check 'one mark per minute' (@($s.Prompts).Count -eq 2)
Add-Activity $s $t0.AddMinutes(-5)
Check 'older mark ignored' (@($s.Prompts).Count -eq 2)
$s = New-State
for ($i = 0; $i -lt 1600; $i++) { Add-Activity $s $t0.AddMinutes($i) }
Check 'cap 1500 keeps newest' (@($s.Prompts).Count -eq 1500 -and (@($s.Prompts)[-1] -eq $t0.AddMinutes(1599)))

# 16. 2 hours of steady mouse/keyboard use (mark every minute) still gets the 60-minute break
$s = New-State
$log = @(Sim $s $d.AddHours(13) $d.AddHours(14).AddMinutes(5) { param($t) $true } { param($a, $t) if ($a.Type -eq 'break') { 1 } else { 1 } })
Check 'break after 60 min of computer use' ($log | Where-Object { $_.Type -eq 'break' -and $_.At -eq '14:00' })

# ---- Default config: hourly water only ----
Set-Config $null
$s = New-State
$log = @(Sim $s $d.AddHours(9) $d.AddHours(21) $typeAll $done)
Check 'defaults: only water popups' ($log.Count -gt 0 -and -not ($log | Where-Object { $_.Type -ne 'care' -or $_.Title -ne 'water' }))
Check 'defaults: first water at 10:00' ($log[0].At -eq '10:00')
Check 'defaults: water hourly (12 in 12 h)' ($log.Count -eq 12)
$s = New-State
$log = @(Sim $s $sat.AddHours(23) $sat.AddHours(27) $typeAll $done)
Check 'defaults: no bedtime or rest popups' (-not ($log | Where-Object { $_.Type -ne 'care' }))

# ---- config.json loading (PowerShell 5.1 JSON quirks) ----
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('bb-test-' + [guid]::NewGuid() + '.json')
'{ "meals": [ { "name": "Lunch", "from": "12:00", "to": "13:30" } ], "restDays": ["Sunday"] }' | Set-Content $tmp
Import-Config $tmp
Check 'one-meal JSON stays a list' ($Cfg.mealList.Count -eq 1 -and $Cfg.mealList[0].S -eq 720)
Check 'one rest day JSON stays a list' (@($Cfg.restDays).Count -eq 1 -and $Cfg.restDays[0] -eq 'Sunday')
Check 'unset keys keep defaults' ($Cfg.water.enabled -and $Cfg.water.everyMinutes -eq 60 -and -not $Cfg.sleep.enabled)
$s = New-State
$log = @(Sim $s $d.AddHours(11).AddMinutes(50) $d.AddHours(12).AddMinutes(10) $typeAll $done)
Check 'lunch from JSON fires at 12:00' ($log | Where-Object { $_.Type -eq 'meal' -and $_.At -eq '12:00' })
'{ "meals": [], "restDays": [] }' | Set-Content $tmp
Import-Config $tmp
Check 'empty lists load' ($Cfg.mealList.Count -eq 0 -and @($Cfg.restDays).Count -eq 0)
Import-Config (Join-Path $Here 'config.example.json')
Check 'config.example.json loads as defaults' ($Cfg.water.enabled -and -not $Cfg.breaks.enabled -and $Cfg.mealList.Count -eq 0)
'{ "sleep": { "enabled": true, "bedtime": "25:00" } }' | Set-Content $tmp
$threw = $false; try { Import-Config $tmp } catch { $threw = $true }
Check 'bad time rejected, last good config kept' ($threw -and -not $Cfg.sleep.enabled)
'{ "restDays": ["Sat"] }' | Set-Content $tmp
$threw = $false; try { Import-Config $tmp } catch { $threw = $true }
Check 'bad day name rejected' $threw
'{ "meals": [ { "name": "Dinner", "from": "20:00", "to": "18:00" } ] }' | Set-Content $tmp
$threw = $false; try { Import-Config $tmp } catch { $threw = $true }
Check 'meal ending before it starts rejected' $threw
Remove-Item $tmp

# ---- Day-sleeper (night shift): bed 09:00, wake 17:00 ----
Set-Config @{ sleep = @{ enabled = $true; bedtime = '09:00'; wake = '17:00' } }
$s = New-State
$log = @(Sim $s $d.AddHours(8) $d.AddHours(10) $typeAll $done)
Check 'shift: wind-down 08:30, bedtime 09:00' (($log | Where-Object { $_.Type -eq 'winddown' -and $_.At -eq '08:30' }) -and ($log | Where-Object { $_.Type -eq 'bedtime' -and $_.At -eq '09:00' }))
Check 'shift: no water during sleep window' (-not ($log | Where-Object { $_.Type -eq 'care' -and $_.At -ge '08:30' }))
$s = New-State
$log = @(Sim $s $d.AddHours(22) $d.AddHours(23).AddMinutes(30) $typeAll $done)
Check 'shift: water works at night' ($log | Where-Object { $_.Title -eq 'water' })

# ---- Bedtime before midnight with early wake: reminders stop at wake ----
Set-Config @{ sleep = @{ enabled = $true; bedtime = '22:00'; wake = '00:30' } }
$s = New-State
$log = @(Sim $s $d.AddHours(23) $d.AddHours(25) $typeAll { param($a, $t) 2 })
Check 'bedtime reminders run before wake' ($log | Where-Object { $_.Type -eq 'bedtime' -and $_.At -eq '23:00' })
Check 'bedtime stops at wake time' (-not ($log | Where-Object { $_.Type -eq 'bedtime' -and $_.At -ge '00:30' -and $_.At -lt '12:00' }))

# ---- Notes: free-text reminders, dated or daily ----
Set-Config @{ water = @{ enabled = $false }; notes = @(@{ text = 'No sugar today.'; title = 'Tooth'; date = '2026-10-30'; everyMinutes = 90 }) }
$s = New-State
$log = @(Sim $s $d.AddHours(10) $d.AddHours(13).AddMinutes(30) $typeAll $done)
$notes = @($log | Where-Object { $_.Type -eq 'note' })
Check 'note fires at once, then every 90 min' ($notes.Count -eq 3 -and $notes[0].At -eq '10:00' -and $notes[1].At -eq '11:30' -and $notes[2].At -eq '13:00' -and $notes[0].Title -eq 'Tooth')
$s = New-State
$log = @(Sim $s $d.AddHours(10) $d.AddHours(10).AddMinutes(25) $typeAll { param($a, $t) 0 })
Check 'ignored note asks again after 10 min' (@($log | Where-Object { $_.Type -eq 'note' }).Count -eq 3)
$s = New-State
$log = @(Sim $s $sat.AddHours(10) $sat.AddHours(13) $typeAll $done)
Check 'dated note silent on other days' ($log.Count -eq 0)
$s = New-State
$log = @(Sim $s $d.AddHours(10) $d.AddHours(12) { param($t) $false } $done)
Check 'note silent while idle' ($log.Count -eq 0)
Set-Config @{ water = @{ enabled = $false }; notes = @(@{ text = 'Daily note' }) }
$s = New-State; $s.Remove('Notes')
$log = @(Sim $s $sat.AddHours(10) $sat.AddHours(11).AddMinutes(30) $typeAll $done)
Check 'undated note runs every day, hourly by default, old state repaired' (@($log | Where-Object { $_.Type -eq 'note' }).Count -eq 2)
$threw = $false; try { Set-Config @{ notes = @(@{ text = 'x'; date = '12/11/2026' }) } } catch { $threw = $true }
Check 'bad note date rejected' $threw
$threw = $false; try { Set-Config @{ notes = @(@{ title = 'no text' }) } } catch { $threw = $true }
Check 'note without text rejected' $threw

if ($fail) { Write-Host "$fail FAILED"; exit 1 } else { Write-Host 'ALL PASS' }
