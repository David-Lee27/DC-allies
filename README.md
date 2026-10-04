# ALLIES: Hero Clash (DC-allies)

A Roblox **6v6 team hero shooter** in the style of Marvel Rivals, with a roster of **original** superheroes inspired by classic comic archetypes. It uses no licensed names, logos or assets.

Everything is built in code: the map, hero costumes, VFX and UI. The place needs **no uploaded assets**, so you can open it and press Play.

## Quick start

1. Open **`DC-Allies.rbxlx`** in Roblox Studio.
2. Press **Play** (F5). Bots fill both teams, so you can play solo.
3. Pick a hero, lock in, and fight for the point.

To publish it, use **File → Publish to Roblox**. Under **Game Settings → Avatar**, set the avatar type to **R15**.
To test multiplayer locally, go to **Test → Clients and Servers** and start 2+ players.

### Rebuilding after editing code
- **No tools needed:** run `python tools/build_place.py` to regenerate `DC-Allies.rbxlx` from `src/`.
- **With [Rojo](https://rojo.space):** run `rojo serve` and connect from the Studio plugin. `rojo build -o DC-Allies.rbxlx` also works.

## Game mode: Domination (best of 3)
1. **Hero Select** (25s): pick from 9 heroes. Each hero can only be picked once per team.
2. **Preparing** (10s): you're locked in your spawn room behind a barrier.
3. **Fight:** capture the center point by standing on it alone. While your team holds it, your score climbs. The first team to 100% wins the round. Score can't finish while the enemy contests the point, which means **overtime**.
4. The first team to win **2 rounds** wins the match, and a new match starts automatically.

Your spawn room heals you and hurts enemies. You respawn 6s after death. Ultimate charge comes from dealing damage, healing allies, and a slow passive gain.

## Controls
| Key | Action |
|---|---|
| Mouse | Aim (over-the-shoulder camera) |
| LMB (hold) | Primary fire |
| Shift | Ability 1 |
| E | Ability 2 |
| Q | Ultimate (at 100%) |
| H | Swap hero (while dead or in your spawn room) |
| Tab (hold) | Scoreboard |
| Alt (hold) | Free the mouse cursor |

Gamepad and touch buttons are bound too.

## Heroes

| Hero | Role | Primary | Shift | E | Ultimate (Q) |
|---|---|---|---|---|---|
| **Titan Prime**: invulnerable star-born powerhouse | Vanguard | Heat Vision (beam) | Sky Charge (knockback dash) | Frost Breath (slowing cone) | Solar Slam (leap + AoE) |
| **Valkyra**: warrior princess | Vanguard | Blade Sweep (melee) | Shield Bash (stun dash) | Binding Lasso (pull + stun) | Aegis Rally (team damage reduction + heal) |
| **Ironclad**: half-man, half-machine | Vanguard | Arm Cannon (explosive shells) | Rocket Leap | Barrier Wall | Orbital Barrage |
| **Nightwarden**: masked night detective | Duelist | Wing Blades | Grapple Line | Smoke Bomb (slow zone) | Night Raid (big dive slam) |
| **Volt**: fastest hero alive | Duelist | Rapid Jabs (melee) | Speed Burst | Static Shock (AoE stun) | Lightning Storm |
| **Tidecaller**: monarch of the seas | Duelist | Trident Bolt | Riptide Blink | Wave Surge (knockback cone) | Maelstrom (pull-in vortex) |
| **Emerald Sentinel**: willpower ring bearer | Strategist | Construct Bolts (damages foes, heals allies) | Light Barrier | Healing Glow | Willpower Dome (healing zone) |
| **Arcanist**: stage magician with real sorcery | Strategist | Arcane Orb (damages foes, heals allies) | Mystic Blink | Mending Rune (heal zone) | Ankh of Renewal (huge team heal) |
| **Circuit**: teen tech genius | Strategist | Sonic Blaster (damages foes, heals allies) | Rocket Boost | Repair Pulse | Overclock (team speed + damage boost) |

## Project layout
```
src/shared/      (ReplicatedStorage.Shared)
  Config.lua       match timings, team size, capture/score speed, ult rates
  Heroes.lua       the whole roster: stats, colors, costumes, abilities (data-driven)
  Util.lua
src/server/      (ServerScriptService.Server)
  Main.server.lua  bootstrap: teams, remotes, map, match
  Match.lua        hero select -> rounds -> domination point -> match end, joins/leaves
  Abilities.lua    generic ability handlers (hitscan, projectile, dash, zone, barrage, ...)
  Combat.lua       damage/heal, status effects, knockback, projectiles
  Combatants.lua   registry for players + bots (stats, cooldowns, ult) replicated via attributes
  Spawner.lua      spawning hero bodies, deaths, kill credit
  HeroOutfits.lua  procedural costumes (capes, cowls, emblems, weapons)
  Bots.lua         bot AI (pathfinding, targeting, ability usage)
  MapBuilder.lua   procedural "Neon Harbor" arena + lighting
src/client/      (StarterPlayerScripts.Client)
  Main.client.lua  wiring
  HeroSelect.lua   hero select / swap screen
  HUD.lua          objective bar, health, ability cooldowns, kill feed, death screen, scoreboard
  Controls.lua     over-the-shoulder camera, aiming, input
  Effects.lua      beams, projectiles, explosions, damage numbers, screen shake
  Nameplates.lua   health bars over heroes
tools/build_place.py   builds DC-Allies.rbxlx from src/ (no Rojo required)
```

## Adding or changing a hero
Add an entry to `Heroes.List` in `src/shared/Heroes.lua`. Each ability picks a `kind` (documented at the top of that file) plus numbers such as damage, cooldown, radius and color. No new code is needed unless you want a brand-new ability kind, which you'd add as a function in `src/server/Abilities.lua`.

Balance knobs such as team size, timers, capture speed and ult gain are in `src/shared/Config.lua`.

## A note on IP
All heroes, names and visuals here are original. Before publishing publicly, consider dropping "DC" from the game's public title (the in-game title is already "ALLIES: Hero Clash"), since "DC" is a registered trademark.
