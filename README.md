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
| Pig, merm and bunnyman drop chance | 0.1%, 0.5%, 1% | 0.5% |
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

The world model (`anim/chokeobon.zip`) is a static one-frame animation generated from the same artwork by `tools/build_anim.py` (needs `ktech` and ImageMagick). The source drawing is `art/source/chokeobon.svg`. To resize the item on the ground, change `WORLD_SCALE` in `scripts/prefabs/chokeobon.lua`.

## Status

Early version, tested in game: the mod loads, world generation works, and eating a Choke-o-Bon (stats, emotes) works. Not yet confirmed: the Pig King bonus, the loot drops, the map scatter count, the break sound, and the colours and size of the world model.
