# Road Racer - Game Features

Road Racer is a top-down arcade racing game made for a **3-year-old child**. It is designed so that a toddler can play it
alone, using **one button**, while an older brother, sister or parent can join in with the full manual controls on the
same screen.

## Made for a 3-year-old: one-button play

The default way to play is **Auto-steer**:

* The child only holds **one button** - there is a *slow* button and a *fast* button, and holding either one is all it takes.
  The car drives forward while the button is held and rolls to a stop when it is released.
* There is **no steering and no braking to learn**. The car looks about 3 seconds ahead, works out where the traffic and
  obstacles will be, and steers into a free lane by itself. It slows down on its own when the road is full.
* The on-screen hints at the bottom of the screen show the buttons and light up when they are pressed, so a child can
  find the right one. A red label and brake lights explain why the car is slowing down.
* Any key or any gamepad button can be chosen for the one button in **Options -> Controls** (big arcade buttons, a
  space bar or a gamepad work well for small hands).
* **Easy difficulty** forgives up to 10 crashes per stage and still lets the stage be finished, and a crash only costs a few
  seconds before the car is put straight back on the road. If time runs out, the
  game simply offers to retry the stage.
* The game is bright, colourful and friendly: cartoon cars, sound effects, music and changing weather.

A grown-up sets up the game (the menus use the keyboard or a gamepad), then the child just holds the button.

## Play together

* **One or two players** on the same screen (side-by-side split screen).
* **Who plays?** screen: every keyboard and gamepad is shown as an icon that you move to the Player 1 or Player 2 side,
  so two people can share one keyboard or use two gamepads.
* Each player picks their own **car colour** and chooses their own mode, so a toddler can use **Auto-steer** while a
  parent plays in **Manual** mode at the same time.

## Game play

### Six stages
Stages unlock in order and can be replayed:

| # | Stage | Weather / mood |
|---|---|---|
| 1 | City Centre | clear day, taxis and vans |
| 2 | Countryside | falling leaves |
| 3 | Seaside Bridge | wind |
| 4 | Desert Run | sand storm |
| 5 | Snowy Mountains | snow, slippery road |
| 6 | Rainy Night City | rain at night, slippery road |

Roads change from 2 to 4 lanes, wind left and right, and get longer and busier from stage to stage.

### Six challenges
After clearing a stage, a shorter **challenge** version of it opens up (Stage Select -> Challenges), with another weather and
sometimes another time of day: City Downpour (rain), Misty Fields (fog), Bridge Gale (strong crosswind), Desert Storm (storm at
night), Blizzard Pass (snow storm) and Midnight Run (the night city, dry). The weather changes the driving too: slippery roads,
and gusts that push the car sideways. On two-lane roads there is less traffic, so a car at full speed can pass.

### Race against the clock
* A **timer** starts at 100 seconds. Collect **fuel cans** (+10 s) and pass **3 checkpoints** per stage to gain more time.
* **Hidden shortcuts** skip a few hundred metres if you find them.
* Score comes from distance, overtaking cars, fuel, checkpoints and leftover time. Progress and best scores are saved.

### Two speeds
**Slow** and **fast** gear. Slow is calm and easy; fast gets through the stage quicker and is needed for the Hard difficulty.

### Traffic and rivals
Every kind of car behaves differently:

* **Taxi** and **truck** stay in their lane.
* **Van** moves out of the way.
* **Blue pickup** blinks and changes lanes.
* **Black Viper** blocks your lane.
* **Police** car chases and tries to bump you - and it is called by hitting a cone.
* **Ambulance** races up from behind. Police and ambulance have **sirens** that get louder as they get close.

Traffic cars keep their distance from each other and there is always at least one free lane.

### Obstacles on the road
Each one does something different: **rock** (crash), **snowbank** (bursts and flings the car aside), **cone** (harmless, but
calls the police), **barrel** (rolls away and stops the car), **tyre** (bounces the car) and **oil** (skid).

### Rainbow super car
Find the rare **rainbow car** and your car turns into a **super car for 15 seconds** - nothing can hurt it.

### Three difficulty levels
**Easy** (up to 10 crashes allowed, fewer obstacles, rare attackers), **Normal** (up to 5 crashes) and **Hard** (clean race
in fast gear, many obstacles, frequent attackers). Each stage's time bonus is tuned for each level.

## Controls and options

* Everything can be played with a **keyboard** or a **gamepad** (Xbox and PlayStation style pads are recognised).
* **Manual mode** for older players: steer with left/right, brake with down, choose slow or fast speed.
* **Remap every key and button** for both players in *Options -> Controls*; settings are saved.
* A **controller monitor** shows what each connected gamepad reports, for finding stuck buttons.
* **Music and effects volume** sliders, **full screen** (F11 or Alt+Enter), **pause** with Esc or the gamepad Start button.
* Menus use the same keys everywhere: arrows / D-pad to move, Enter / A to confirm, Esc / B to go back.

## Technical features

* Built with **Godot 4.7** and GDScript, using the lightweight GL Compatibility renderer, so it runs on modest PCs.
* Engine, jingles and many sound effects are **synthesized at startup**.
* Includes a **developer bot** that plays the real game and prints statistics and screenshots (see the README).
* Open source - see the [README](README.md) for how to build it.
