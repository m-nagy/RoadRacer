<p align="center">
  <img src="icon.png" alt="Road Racer icon" width="180">
</p>

<h1 align="center">Road Racer</h1>

<p align="center">
  A colourful top-down arcade racer made for a 3-year-old: hold <b>one button</b> and the car drives itself.<br>
  Built with Godot 4.7 (GDScript). Two-player side-by-side split screen, keyboard and gamepad.
</p>

> New here? Read [GAME_FEATURES.md](GAME_FEATURES.md) for what the game does and how it plays.

## Play

Download the latest `RoadRacer-windows.zip` from the **Releases** page, unzip it and run `RoadRacer.exe`.
No installer is needed.

## Build it yourself

You need two things from [godotengine.org/download](https://godotengine.org/download):

1. **Godot 4.7.2 (Standard version, not .NET)** - the editor. On Windows it is a single portable `.exe`, there is nothing to install.
2. **The matching export templates (4.7.2)** - only needed to produce a `.exe`; not needed to just run the game from the editor.
   * In the editor: **Editor -> Manage Export Templates -> Download and Install**, or
   * Download `Godot_v4.7.2-stable_export_templates.tpz` from the Godot download page and use
     **Editor -> Manage Export Templates -> Install From File**.

The templates must be the same version as the editor (4.7.2), otherwise the export is refused.

### Run from the editor
1. Clone this repository.
2. Start Godot, click **Import**, choose `project.godot` in the cloned folder, then press **F5** (Play).
   The first open takes a moment while Godot imports the images and sounds.

Or from a terminal: `godot --path .`

### Export a Windows executable
* In the editor: **Project -> Export...**, choose the **Windows Desktop** preset, **Export Project**
  (the preset is already set up to write `build/RoadRacer.exe`, with the data embedded in the exe).
* Or from a terminal (run `godot --headless --path . --import` once first on a fresh clone):

  ```
  godot --headless --path . --export-release "Windows Desktop" build/RoadRacer.exe
  ```

The exe gets the game icon and name from the export preset; Godot does this itself, so you do not need rcedit or Wine.
The `build/` folder is git-ignored.

### Automatic builds (GitHub Actions)
`.github/workflows/build.yml` builds the Windows exe on every push and pull request (download it from the run's
**Artifacts**). Pushing a version tag such as `v1.0.0` also creates a GitHub Release with `RoadRacer-windows.zip` attached:

```
git tag v1.0.0
git push origin v1.0.0
```

## Menus

Home -> (Stage Select) -> **Who plays?** -> **Cars** -> race. Home also has **Options** and Full Screen.

| | Keyboard | Gamepad |
|---|---|---|
| Move in menus | arrow keys or W A S D | D-pad or left stick |
| Confirm / choose / continue | Enter (or Space) | A (Cross) |
| Back | Esc | B (Circle) |
| Full screen on / off (anywhere) | F11 or Alt+Enter | |

**Who plays?** - every keyboard and gamepad is an icon in the middle. Move an icon to the left (Player 1) or the right
(Player 2): Keyboard 1 moves with A / D, Keyboard 2 with the arrow keys, a gamepad with its own D-pad / stick. A keyboard
moved left uses Player 1's keyboard keys, moved right uses Player 2's. Enter / A continues (one or two players).

**Cars** - shows one or two panels. Each player changes the car colour (live preview) and the steering mode with their own
keys; the slow key / A = ready, or press Enter to start at once.

## Options
* **Game Settings** - difficulty (Easy / Normal / Hard), music and effects volume, full screen.
* **Controls** - remap every key and gamepad button for Player 1 and Player 2 (select a cell, press the new key / button,
  Esc cancels). Saved immediately; "Reset defaults" per player. A *Controller monitor* shows live what each connected
  pad reports (handy if a pad has a stuck / phantom button; a `*` means "held from before, ignored until released").

Default controls (can be changed in Options):

| | Player 1 keyboard | Player 2 keyboard | Gamepad (both) |
|---|---|---|---|
| Left / Right | A / D | Left / Right arrows | D-pad or left stick |
| Up / Down (brake) | W / S | Up / Down arrows | D-pad or left stick |
| Slow speed (~200 km/h) | G | K | A (Cross) |
| Fast speed (~400 km/h) | H | L | B (Circle) |
| Pause | Esc | Esc | Start / Options |

## Modes
* **Auto-steer** - hold one button (slow or fast). The car looks 3 seconds ahead, simulating every lane and speed
  choice against the predicted movement of all traffic and hazards, steers round them and brakes when needed.
* **Manual** - you steer. The car follows the road exactly; only your own steering moves it across the road. Any corner
  of the car going past the curb is a crash.

## Rules
Timer starts at 100 and counts down. Fuel cans +10, 3 checkpoints per stage add time, a crash costs 5 s and respawns you,
a side bump halves your speed and burns time 1.5x faster for 5 s. Score = distance + overtakes (50) + fuel + checkpoints
(1000) + leftover time x100. Hidden shortcuts skip 600-800 m. Stages unlock in order; clear ones can be replayed. Losing
offers Retry Stage or New Game (progress and best scores are kept in `user://save.json`, which Godot stores in your
user data folder: `%APPDATA%\Road Racer\` on Windows).

### Difficulty
| | Easy | Normal | Hard |
|---|---|---|---|
| Crashes you can afford and still finish | up to 10 | up to 5 | none |
| Fuel cans on the road | most | some | few |
| Attacking rivals (Black Viper / police) | rare | normal | frequent |
| Obstacles | fewer | normal | more |

The checkpoint bonus is computed per stage and difficulty (`data/difficulty.gd`, `v_slow` / `v_fast` in `data/stages.gd`)
so those allowances hold. Easy is calibrated for slow gear throughout; Hard needs fast gear most of the time.

### Obstacles (one per row at most)
* **Rock** - crash.
* **Snowbank** - bursts, halves your speed and flings the car to the far side of the road (not a crash).
* **Cone** - harmless, but calls the police: a police car comes up from just behind the screen, draws level and
  tries to side-swipe you (one at a time; hitting another cone while it chases you keeps it after you for longer).
* **Barrel** - rolls away and stops your car dead; accelerate again.
* **Tire** - bounces you sideways and slows you down.
* **Oil** - skid.

### Rival cars
Taxi / truck never leave their lane, van moves aside, blue pickup changes lanes (blinks first), Black Viper blocks your
lane, police rams you, ambulance comes fast from behind. Only police and ambulance are fast; all other traffic stays at
slow speed, and every car steers round obstacles. Cars keep their distance (they never drive into each other), merge
with the indicator on where a lane ends, and never line up across the whole road: there is always at least one lane
open, even if it means weaving through. Police and ambulance have sirens that get louder as they get closer.
The **rainbow car** makes your car a rainbow **super car for 15 seconds**: obstacles, other cars and the road side
cannot hurt it.

During a race the bottom of each screen shows that player's steering keys and slow / fast buttons, lighting up as they are
pressed. A red label and brake lights tell you why the car is slowing down. F3 shows the exact collision boxes.

## Project layout
| Folder | Contents |
|---|---|
| `autoload/` | Global singletons: game flow, save data, input, audio, sound synthesis, developer bot |
| `scenes/title/` | Home, Who plays?, Cars and Options screens |
| `scenes/race/` | The race: road, world, player car, rivals, obstacles, HUD, weather, auto-pilot |
| `data/` | Stage definitions, difficulty tuning, default controls |
| `assets/` | Car sprites, UI graphics, music and sound effects used by the game |
| `art/` | Source of the game icon (`icon.svg`; ignored by Godot) |

## Developer bot
`godot --path . -- --autotest stage=4 players=2 easy=1 gear=fast seconds=60 shots=5,20 scale=2` drives the real game with the
autopilot, prints crashes/progress and saves screenshots to `user://autotest/`. Run it headless and faster than real time
with `--headless --fixed-fps 30`. Flags: `diff=easy|normal|hard`, `notime`, `crashes=N`, `hit=<obstacle kind|all>`, `super`,
`title screen=0..4 fill flow=kb|pad|remap`, `shortcut`, `jump=0.98`, `pause=5`, `forcecrash=2`, `stat=N`, `padlog`,
`police=6` (call the police on P1 after 6 s and log the chase). The stat line's audit counts rival `overlaps`, `walls`
(rows of cars closing every lane ahead of a player) and `police_near`.

## Credits
* **Cars:** UnLuckY Studio "Awesome Car Pack" (www.unluckystudio.com) - free to use, including in commercial projects.
* **UI graphics:** Kenney "UI Pack - Adventure" (www.kenney.nl), CC0.
* **Impact sound effects:** Kenney impact sounds (www.kenney.nl), CC0.
* **Police and ambulance sirens:** `assets/sfx/police.mp3`, `assets/sfx/ambulance.mp3`.
* **Music:** background tracks in `assets/music/`.
* Engine, jingles and beeps are synthesized by the game at startup.
* Made with the [Godot Engine](https://godotengine.org) (MIT).

## License
The source code is released under the [Prosperity Public License 3.0.0](LICENSE.md): free for noncommercial use, with a
30-day trial for commercial use. The art and audio in `assets/` keep the licenses of their original authors (see Credits).
