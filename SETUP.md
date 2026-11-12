# BreakBuddy setup guide (for the AI assistant)

You are helping a person install BreakBuddy, a small Windows app that pops up gentle reminders
while they use their computer: drink water, eat, take breaks, stretch, and go to bed.
Follow these steps in order. Talk to the person in plain, friendly language. Ask one question at a
time and wait for the answer. Never invent their answers.

## 1. Check what you can do

- BreakBuddy runs on **Windows 10 or 11 only** (it uses Windows PowerShell 5.1, which Windows ships with).
  If the person is on macOS or Linux, tell them it will not run there and stop.
- If you can read and write files and run commands on their computer (for example Claude Code,
  Codex, Cursor, or another coding agent), do every step yourself.
- If you are a chat assistant with no file or command access, do the interview anyway, then give the
  person the finished `config.json` text and the exact commands from step 4 to paste themselves.
  Tell them where the folder is: wherever they unzipped or cloned BreakBuddy.

## 2. Explain the default

Tell the person, in one or two sentences:
"Out of the box BreakBuddy only reminds you to drink water once an hour while you are at the computer.
Everything else is optional. I will ask about meals and sleep, then a few extras."

Reminders only appear while the computer is in use (keyboard or mouse in the last few minutes).
Nothing pops up when they are away.

## 3. Interview

Ask these one at a time. Accept natural answers ("noon", "half seven", "around 11pm") and convert
them to 24-hour `HH:mm` yourself. Read each converted time back so they can correct it.

1. **Water.** "Water every 60 minutes is on. Keep it, change the interval, or turn it off?"
2. **Meals.** "Which meals would you like reminders for, and roughly when do you eat each one?"
   For each meal get a name and a window: when the reminder may start (`from`) and when it should give
   up for that day (`to`). If they give a single time, suggest a window starting at that time and
   lasting about 2 hours, and confirm it. A window must start and end on the same day. Any number of
   meals is fine, including none.
3. **Sleep.** "Would you like a bedtime reminder? If so, what time do you want to be in bed, and what
   time do you usually get up?" If yes, also ask how many minutes of warning they want before bed
   (default 30) and how often to repeat the bedtime reminder if they keep using the computer
   (default 15 minutes). Day sleepers and night-shift workers are fine: any bedtime and wake time work.
   While sleep is on, water, stretch, break, and meal reminders stay silent from the wind-down until wake time.
4. **Extras.** Ask together, as one short list they can say yes or no to:
   - Break reminders after a long stretch of computer use (default after 60 minutes; offers 15 or 25 minute breaks).
   - Stretch reminders (default every 30 minutes).
   - Rest days: days of the week when it gently suggests not working.

Then summarise the whole schedule back in a short list and ask "Does this look right?" Change anything
they correct before writing.

## 4. Write the config and install

Write `config.json` in the BreakBuddy folder, next to `buddy.ps1`. Use exactly this shape. Keys you
leave out keep their defaults, but write all of them so the person can see and edit everything later.

```json
{
  "water":    { "enabled": true,  "everyMinutes": 60 },
  "stretch":  { "enabled": false, "everyMinutes": 30 },
  "breaks":   { "enabled": false, "afterMinutes": 60, "snoozeMinutes": 10, "maxSnoozes": 3 },
  "meals":    [
    { "name": "Breakfast", "from": "08:00", "to": "10:00" },
    { "name": "Lunch",     "from": "12:30", "to": "14:30" }
  ],
  "sleep":    { "enabled": true, "bedtime": "23:30", "wake": "07:30", "windDownMinutes": 30, "repeatMinutes": 15 },
  "restDays": ["Sunday"]
}
```

Rules:
- Times are 24-hour `HH:mm` strings ("07:05", not "7:05am").
- `restDays` uses full English day names: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday.
- `meals` and `restDays` are lists; use `[]` for none.
- A meal's `to` must be later than its `from`.
- `notes` is an optional list of free-text reminders, for example
  `{ "title": "Tooth care", "text": "Take your meds when a dose is due.", "date": "2026-11-12", "everyMinutes": 90 }`.
  Leave out `date` for every day and `everyMinutes` for hourly. No double quotes inside `text` or `title`.

Then run these from the BreakBuddy folder in PowerShell. `-ExecutionPolicy Bypass` is needed because
Windows blocks downloaded scripts by default; it applies only to that one command.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test.ps1
```

Expect the last line `ALL PASS`. If anything says FAIL, stop and show the person the output.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

This registers a Windows scheduled task named `BreakBuddy` that starts at login, and starts it now.
It needs no administrator rights.

## 5. Verify

- Check that `buddy.log` in the folder exists and its newest lines include `started` and `config loaded`.
  If it shows `config error`, fix `config.json` using the message and save it again; BreakBuddy
  reloads the file by itself within about 15 seconds.
- Optionally show the person what a reminder looks like:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\buddy.ps1 -Popup -Title "water" -Msg "Drink some water." -Buttons "Done" -Timeout 20
```

## 6. Optional: count AI chat time as computer time

BreakBuddy already watches keyboard and mouse. If the person mostly talks to an AI tool and that tool
supports a hook that runs a command on every prompt, the hook can append a line to `ping.txt` in the
BreakBuddy folder; each change marks activity. For Claude Code, add this to `~/.claude/settings.json`
under `hooks.UserPromptSubmit` (replace the path with the real folder, using forward slashes):

```json
{ "hooks": [ { "type": "command", "command": "echo >> \"C:/path/to/BreakBuddy/ping.txt\"" } ] }
```

Only do this if the person asks for it or agrees when you offer. Most people do not need it.

## 7. Tell them how to live with it

- Change settings any time by editing `config.json` (or asking their AI to). No restart needed.
- Every reminder has buttons; ignoring one just means it asks again a bit later.
- To turn BreakBuddy off for good:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```
