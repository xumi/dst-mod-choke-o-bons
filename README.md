# Choke-o-Bons

A [Don't Starve Together](https://www.klei.com/games/dont-starve-together) mod that adds a rare bag of chocolate bonbons with a secret number of uses. It is a treat until it runs dry, then it bites back.

## The item

- Each Choke-o-Bon has a random number of uses between 1 and 8. The number is rolled the first time the item is picked up, saved with the item, and never shown to the player.
- Use it from the inventory (right-click, "Use"). Each use gives:
  - -1 health
  - +1 hunger
  - +20 sanity
  - a happy emote
- Using an empty Choke-o-Bon costs 100 sanity and plays a very sad emote with the character's voice. The item is not consumed.
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
art/build/                     PNG sources for the icons
```

## Art

The icons are converted from PNG to Klei's TEX format with [`ktech`](https://github.com/nsimplex/ktools):

```
ktech art/build/chokeobon.png images/inventoryimages/chokeobon.tex
ktech art/build/modicon.png modicon.tex
```

The item currently uses a tinted gold nugget model on the ground. A custom world animation (`anim/*.zip`) still needs to be built with Klei's Mod Tools.

## Status

Early version. The Lua passes a syntax check, but the mod has not been run in the game yet. The emotes, the Pig King hook and the world generation placement were written from memory of the game's API and may need adjustments.
