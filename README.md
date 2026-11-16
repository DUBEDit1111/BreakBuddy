# BreakBuddy

Gentle reminders for people who forget to look after themselves at the computer.
BreakBuddy watches whether you are using your Windows PC and, only while you are, pops up a small
friendly reminder to drink water, eat, take a break, stretch, or go to bed.

![A BreakBuddy reminder: a turning Metatron's Cube beside a speech bubble saying "Drink some water."](docs/popup.png)

**Out of the box it does one thing: a water reminder every hour while you are at the computer.**
Meals, bedtime, breaks, stretching, and rest days are all optional and set up by asking you a few questions.

## Set it up with your AI (easiest)

1. Download this repository (green **Code** button, then **Download ZIP**) and unzip it somewhere you will keep it,
   for example `Documents\BreakBuddy`. Or `git clone` it.
2. Open the folder in your AI coding assistant (Claude Code, Codex, Cursor, and similar), or drag the folder
   or [SETUP.md](SETUP.md) into your AI chat.
3. Say: **"Set up BreakBuddy for me."**

The AI follows [SETUP.md](SETUP.md): it asks when you eat, when you sleep, and which extras you want,
writes your `config.json`, runs the tests, and installs it. A chat-only AI that cannot run commands will
give you the file and the commands to paste instead.

## Set it up by hand

From the BreakBuddy folder, in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

This creates `config.json` from [config.example.json](config.example.json) (hourly water only) and starts
BreakBuddy at every login. Edit `config.json` to add meals, sleep, and extras; the format is described in
[SETUP.md](SETUP.md#4-write-the-config-and-install). Changes apply within about 15 seconds, no restart.

## What it does

| Reminder | Default | When it appears |
|---|---|---|
| Water | **On**, every 60 min | While you are using the computer |
| Meals | Off | Inside each meal window you set, until you press Ate |
| Walks | Off | Inside each walk window you set (for example 10:00 to 11:00 and 15:00 to 17:00): get outside for 15 to 20 minutes |
| Morning sunlight | Off | Once, in the first hour after your wake time: 5 to 10 minutes of outdoor light |
| Bedtime | Off | A wind-down warning before bed, then bedtime reminders while you are still on the computer |
| Breaks | Off | After a long unbroken stretch of use; offers a 15 or 25 minute break |
| Stretch | Off | Every 30 min of use |
| Rest days | Off | One gentle nudge on the days you choose |
| Session timer | Off | A work block, then a rest: 60 min then 15, 90 min then 30, or your own numbers |

While sleep is on, daytime reminders stay quiet from your wind-down until your wake time.
Stepping away for 10 minutes resets the work clock. Every popup has buttons; ignoring one only means it asks again later.

## Session timer

Turn it on in the settings window. A session starts either as soon as you use the computer or, if you
work with an AI tool, the moment you send it a prompt (see the prompt hook in [SETUP.md](SETUP.md)).
When the work block is over BreakBuddy asks you to rest; press **Resting** and it stays quiet until the
rest is done, then the next trigger starts a new session. Stepping away for as long as the rest counts
as the rest. While the session timer is on it replaces the plain break reminder.

## Settings window

Open **BreakBuddy Settings** from the Start menu (added by `install.ps1`), or run:

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\settings.ps1
```

Every setting is there: session timer, water, stretch, breaks, meals, sleep, rest days, and your own notes.
Save checks the values and BreakBuddy picks them up within about 15 seconds.

## Why these timings

- **Water every hour.** Dr. Andrew Huberman recommends a baseline of about 8 ounces (240 mL) of fluid per
  hour during the first 10 hours of your day while sitting or working at a desk.
- **Morning sunlight.** Andrew Huberman recommends 5 to 10 minutes of outdoor morning sunlight (15 to 30
  minutes on cloudy or overcast days) within the first 30 to 60 minutes of waking, to optimise your
  circadian rhythm, mood, focus, and sleep.
- **Walks.** A mid-morning walk (around 10 to 11 am) and an afternoon walk (around 3 to 5 pm): get outside
  for 15 to 20 minutes.
- **90 minute sessions.** The brain naturally works in high-focus cycles of about 90 minutes (ultradian
  rhythms), then tires and needs to clear a trough in its basic rest-activity cycle (BRAC).
  [Charlotte Observer](https://www.charlotteobserver.com/living/article315897497.html)
- **Rest is 20 to 25% of work time.** Productivity research puts the best rest at roughly a fifth to a
  quarter of work time: a 15 to 30 minute break after a 90 minute push, or 15 minutes after 60.
  [Chris Bailey](https://chrisbailey.com/for-optimal-productivity-be-on-break-for-20-25-of-the-workday/),
  [Mission Leather Co.](https://missionleatherco.com/blogs/news/the-90-minute-work-block-method-how-to-get-more-done-in-less-time)
- **Sleep**, after Dr. Matthew Walker's four pillars
  ([talk](https://www.youtube.com/watch?v=Hf_NTmu2uvg&t=59),
  [regularity](https://www.youtube.com/watch?v=hvPGfcAgk9Y&t=11),
  [MasterClass](https://www.masterclass.com/classes/matthew-walker-teaches-the-science-of-better-sleep/chapters/sleep-to-thrive)):
  - *Quantity:* adults need 7 to 9 hours a night. Time in bed is not time asleep: 7 hours of real sleep
    usually takes about 8 hours 15 minutes in bed.
  - *Quality:* sleep efficiency, the share of time in bed spent asleep, should be 85% or higher.
  - *Regularity:* the same bedtime and wake time every day, weekends included, anchors your 24-hour body clock.
  - *Timing:* fit your sleep window to your chronotype, morning lark or night owl.

### Sleep hygiene rules (Dr. Matthew Walker)

The wind-down popup has a **Sleep tips** button that opens this list in the settings window.

- **Cool room.** Set the bedroom to about 65 to 68°F (18 to 20°C). Your core temperature has to drop by
  2 to 3°F to fall asleep and stay asleep.
  [1](https://www.youtube.com/watch?v=Jydi-XT2D4c), [2](https://somneesleep.com/blogs/post/matt-walker-sleep-tips)
- **Darkness at night.** Dim the house lights by half or more in the last hour, put screens away 30 to 60
  minutes before bed, and use blackout curtains or an eye mask so melatonin can rise.
  [1](https://www.gq.com/story/matthew-walker-sleep-expert-habits), [2](https://www.youtube.com/watch?v=hvPGfcAgk9Y&t=11)
- **Morning sunlight.** Get outside into daylight within 60 minutes of waking. It anchors your body clock
  and brings a healthy morning cortisol rise.
- **Stimulants and depressants.** No caffeine after 12:00 noon (its half-life is about 6 hours) and no
  alcohol before bed. Both break up sleep and block deep and REM stages.
  [1](https://erictopol.substack.com/p/matthew-walker-promoting-our-sleep), [2](https://www.youtube.com/watch?v=5MuIMqhT8DM&t=12)
- **The 25 minute rule.** Awake and cannot drift back after 25 to 30 minutes? Get up, go to a dimly lit
  room, and read or listen to a quiet podcast until sleepy. No phone, no food.
- **Warm bath effect.** A hot bath or shower before bed draws blood to the skin, which sheds core heat,
  so your core temperature falls right as you get into bed.

These are general wellbeing guidelines, not medical advice. Change any number to suit you.

## Requirements

- Windows 10 or 11 (uses the built-in Windows PowerShell 5.1; nothing to install)
- No administrator rights, no internet, no accounts. Nothing leaves your computer.

## Files

| File | Purpose |
|---|---|
| `buddy.ps1` | Background loop and the popup window |
| `engine.ps1` | All reminder logic (no UI, fully tested) |
| `settings.ps1` | Settings window that edits `config.json` |
| `test.ps1` | Simulated-day tests: `powershell -ExecutionPolicy Bypass -File .\test.ps1` |
| `config.example.json` | Default settings |
| `install.ps1` / `uninstall.ps1` | Start at login / remove |
| `SETUP.md` | Step-by-step guide your AI follows |

Your own `config.json`, `state.xml`, and `buddy.log` stay on your machine and are ignored by git.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Then delete the folder.

## License

[MIT](LICENSE)
