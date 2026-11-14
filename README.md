# Choke-o-Bons

A [Don't Starve Together](https://www.klei.com/games/dont-starve-together) mod that adds a rare bag of chocolate bonbons with a secret number of uses. It is a treat until it runs dry, then it bites back.

## The item

- Each Choke-o-Bon has a random number of uses between 1 and 8. The number is rolled the first time the item is picked up, saved with the item, and never shown to the player.
- Use it from the inventory (right-click, "Use"). Each use gives:
  - -1 health
  - +1 hunger
  - +20 sanity
  - a happy emote
- Using an empty Choke-o-Bon costs 100 sanity, plays a very sad emote with the character's voice, and destroys the bag with a break sound.
- The health loss can kill the player.

## Where to find it

- On the map: sparsely placed in grass, forest, deciduous, savanna, rocky and marsh background rooms at world generation. Existing worlds are not affected.
- Random drops: a small chance on anything that drops loot (mobs, mined rocks, chopped trees, ...).
- The Pig King: a very small chance of a bonus when you trade with him.

For testing, `c_give("chokeobon")` gives one, and `c_spawn("chokeobon")` drops one at your feet.

## Configuration

| Option | Choices | Default |
|---|---|---|
| Map density | 0.05%, 0.1%, 0.3% | 0.1% |
| Random drop chance | 0.1%, 0.5%, 1% | 0.5% |
| Pig King chance | Off, 0.5%, 1%, 3% | 0.5% |

## Install

Copy this folder into your DST mods directory and enable it from the Mods screen. On macOS that is usually `~/Documents/Klei/DoNotStarveTogether/mods/`. Create a new world to get the map placement.

## Layout

```
modinfo.lua                    Mod metadata and config options
modmain.lua                    Worldgen placement, loot drops, Pig King hook
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

The world model (`anim/chokeobon.zip`) is a static one-frame animation generated from the same artwork by `tools/build_anim.py` (needs `ktech` and ImageMagick). The source drawing is `art/source/chokeobon.svg`. To resize the item on the ground, change `WORLD_HEIGHT` in the script and rebuild.

## Status

Early version. The Lua passes a syntax check, but the mod has not been run in the game yet. The emotes, the break sound, the Pig King hook, the world generation placement and the hand-built world model were written without access to the game's files and may need adjustments.
