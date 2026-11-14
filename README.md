# Choke-o-Bons

A [Don't Starve Together](https://www.klei.com/games/dont-starve-together) mod that adds a rare bag of chocolate bonbons with a secret number of uses. It is a treat until it runs dry, then it bites back.

## The item

- Each Choke-o-Bon has a random number of uses between 1 and 8. The number is rolled the first time the item is picked up, saved with the item, and never shown to the player.
- Eat it like any food. The bag stays in your inventory and each bite gives:
  - -1 health
  - +1 hunger
  - +20 sanity
  - a happy emote
- Eating an empty Choke-o-Bon costs 100 sanity, plays a very sad emote with the character's voice, says a line specific to the character (a default one for unlisted or modded characters), and destroys the bag with a break sound.
- The health loss can kill the player.

## Where to find it

- On the map: a fixed small number (3 by default) are scattered at random over the surface world the first time it loads with the mod enabled. Existing worlds get them too, once.
- Kills: a 0.5% chance when you kill a pig (including guards), a merm (including guards) or a bunnyman.
- The Pig King: a small chance (1% by default) of a Choke-o-Bon tossed out along with his usual reward when you trade him a trinket.

For testing, `c_give("chokeobon")` gives one, and `c_spawn("chokeobon")` drops one at your feet.

## Configuration

| Option | Choices | Default |
|---|---|---|
| Items on the map | 3, 6, 12 | 3 |
| Mob drop chance | 0.1%, 0.5%, 1% | 0.5% |
| Pig King chance | 1%, 3%, 5% | 1% |

## Install

Copy the `choke-o-bons` folder (from `tools/package.sh` or a release zip) into the `mods` folder of the game's install directory, with `modinfo.lua` directly inside it, and enable it from the Mods screen. On Windows with Steam that is `C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Together\mods\`. Create a new world to get the map placement.

## Layout

```
modinfo.lua                    Mod metadata and config options
modmain.lua                    Loot drops, Pig King hook
scripts/components/            Scatters the map items on first load
scripts/prefabs/chokeobon.lua  The item: uses, stats, emotes
images/inventoryimages/        Inventory icon (.tex + atlas .xml)
modicon.tex / modicon.xml      Mod icon shown in the Mods screen
anim/chokeobon.zip             World model (static one-frame animation)
art/                           Source drawing and PNG sources for the icons
tools/build_anim.py            Generates the world model
```

## Testing

`tools/test.sh` runs every check, and CI runs it on every push and pull request before anything is packaged:

- **Behaviour tests** (`tests/run.lua`): load `modmain.lua` in a strict copy of the game's mod environment (so using `STRINGS`, `TheWorld` or `TUNING` directly is an error, as in the game), then exercise every hook and the item against stub engine objects: map scatter, mob drops, Pig King bonus, eating, emotes, speech.
- **Model test** (`tests/test_anim.py`): pins the exact contents of `anim/chokeobon.zip` to the values confirmed in game.
- **Mutation check** (`tests/mutation_check.py`): puts bugs this mod really had back into a temporary copy and makes sure the tests catch each one. Add a case whenever you fix a new bug.

These tests use stubs, not the game, so they catch wiring mistakes and regressions but not wrong assumptions about the engine. Check those against the game's scripts and in the game.

## Packaging

`tools/package.sh` builds `dist/choke-o-bons/` (only the files the game needs) and copies the Workshop preview image to `dist/preview.png`. Upload the `dist/choke-o-bons` folder, not the whole repository.

A GitHub Actions workflow (`.github/workflows/package.yml`) does this on every push to `main`: it syntax-checks the Lua (5.1, as DST uses) and publishes the `choke-o-bons` and `workshop-preview` artifacts, downloadable from the run's page in the Actions tab. Pushing a tag like `v0.1.0` also creates a GitHub Release with `choke-o-bons.zip` and the preview attached.

`tools/render_preview.sh` regenerates `art/preview.png` from the source drawing (macOS and ImageMagick 6 only; run it when the art changes).

## Art

The icons are converted from PNG to Klei's TEX format with [`ktech`](https://github.com/nsimplex/ktools):

```
ktech art/build/chokeobon.png images/inventoryimages/chokeobon.tex
ktech art/build/modicon.png modicon.tex
```

The world model (`anim/chokeobon.zip`) is a static one-frame animation generated from the same artwork by `tools/build_anim.py` (needs `ktech` and ImageMagick). The source drawing is `art/source/chokeobon.svg`. To resize the item on the ground, change `WORLD_HEIGHT` in `tools/build_anim.py` and rebuild. The size is baked into the model on purpose: scaling it in the item script made only part of it clickable.

## Status

Version 1.0.4. Confirmed in game: the mod loads, the map scatter, eating (stats, the bag staying in your inventory), and the world model with its click box. Not yet confirmed in game: the Pig King bonus, the pig/merm/bunnyman drops, and the updated emotes (tears effect, voices) and break sound.
