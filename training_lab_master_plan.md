# FROGHOUSE — CS 1.6 Training Suite — Master Plan
*(formerly "The Modpack" — software/training arm of the broader FROGHOUSE project)*

## Credits

This pack builds on the work of many other people's original plugins, engines, and tools. None of this exists without them — credit belongs here regardless of how much any individual piece got modified along the way.

**Engine core:**
- **ReHLDS team** — reverse-engineered dedicated server engine
- **ReGameDLL team** — reverse-engineered game logic
- **Metamod-R (theAsmodai and contributors)** — plugin loader
- **AMX Mod X Dev Team** — the scripting framework this entire pack is built on
- **ReAPI team** — extended native functions
- **YaPB team** — bot AI

**Plugins (original authors, credited even where modified):**
- **Alghtryer** — AimBotz Training (modified in this pack — see aim_botz.sma header for full change log)
- **Blizzard** — Frags Counter (used within AimBotz Training)
- **Alka** — StopWatch (used within AimBotz Training)
- **ConnorMcLeod** — Unlimited Ammo (used within AimBotz Training); also Ham Register Cz Bots (no longer used after the YaPB conversion)
- **uLLeticaL and Cha** — original AimBotz map port from CS:GO to CS 1.6 (unmodified)
- **Arkashine** — CSBotEnabler (referenced by the original AimBotz pack; no longer required after converting bot-handling to YaPB)
- **bahrmanou** — Teleportation Facilities plugin (saveme/posme checkpoint system)
- **Zenith77** — Syn-Scripts Checkpoint plugin
- **Dores** (or equivalent author of your specific hs_mode build) — HeadShot Only plugin
- **Michael S. Booth, Turtle Rock Studios** — original BotProfile.db / BotChatter.db format (not used in the current YaPB-based build, credited for reference)
- Every other AMXX plugin author whose `.amxx` file is in the plugins folder — check each plugin's own header comment or AlliedModders thread for exact attribution before public release, since not every author is listed here

**When releasing publicly:** GameBanana and ModDB both expect a credits section in the mod page description, not just in file headers — carry this list (or an expanded version of it) into the actual release listing, not just the source code.

## CS2-inspired additions — what maps to what

Going through the CS2 training tools you listed, here's the honest breakdown of what's already covered, what's a real new build, and one thing that isn't portable:

| CS2 tool | Status in this pack |
|---|---|
| Yprac Prefire Practice | New build: prefire/crosshair-placement maps + config, already on the roadmap below |
| lmtlss Prefire Series | Same category as above — build our own prefire route configs using YaPB bot placement, since these are Workshop-specific and can't be imported directly |
| Refrag.gg "Crossfire" mode | **Concept only, not the product** — Refrag is a paid commercial service; we can't clone their platform, but the *idea* (multi-angle simultaneous peek simulation) is buildable as our own YaPB scenario config, same as the retake/site-hold configs already planned |
| Aim Botz sandbox | Already have — this is the exact plugin we just fixed and modernized this session |
| FAST AIM/REFLEX bots-from-ring | Matches `aim_reflex_v2`, already in your map rotation from Phase 4 |
| Recoil Master / "ghosthair" spray visualizer | **New concrete build** — this is the real version of the recoil-visualizer gap identified earlier in this plan, now with CS2's actual weapon spray data as the target pattern |
| Movement Hub (jump-throw lineups, strafe jumps) | Overlaps with the JumpStats suite already installed; jump-throw *lineups* specifically are a checkpoint + grenade-trail combo, already possible with what you have |
| KZ community servers | Already on the recommended map list from earlier in this plan |

## CS2 weapon spray & speed matching

Two separate features, both genuinely buildable without the full SDK project:

1. **Ghosthair recoil visualizer** — a ReAPI plugin that reads real, published CS2 per-weapon spray coordinates (x/y offset per shot) and draws a "ghost" target reticle showing where your crosshair should be pulling to, shot by shot, matched to CS2's actual pattern rather than 1.6's native one. This is the concrete build for the recoil gap flagged earlier — bigger build than a cvar toggle, real next-project scope.
2. **CS2 Parity Mode (speed-matching cvar profile)** — built below as a ready-to-use config. Toggles your server's movement cvars to approximate CS2's numbers instead of GoldSrc defaults, so movement *feel* during CS2-parity drills is closer to the real thing. This is a cvar-only approximation, not a true physics recreation (see the earlier SDK discussion for why exact replication needs engine-level code) — but it's a real, usable training aid today.

## Old-school training gems (recap, still standing)

- QuakeWorld mutual tracking-dance drill (T&T Exercise #3) — sustained live tracking against a human partner, adapted to CS with a low-lethality weapon
- 180-degree turn sensitivity calibration — the companion drill from the same QuakeWorld guide
- CPMA mid-air/instagib air-control — genuine 3D tracking transfer, supplemental not core
- Knife-only bot corridors — reactive flinch-snap training, short warmup use only

## 1. Full feature inventory

### Core engine (built and confirmed working)
ReHLDS, ReGameDLL, Metamod-R, AMX Mod X, ReAPI, YaPB — the whole chain confirmed via `meta list` / `amxx plugins`.

### Training plugins (built and loaded)
- Wallbang/geometry: weapon_laser_tracers, advanced_weapon_tracers, Wallbang_Training
- Grenade/utility: team_grenade_trail, flashbang_trainer, frostnades, enhanced_flashbang_reapi

- Movement/jump: jumpstats (main/bhop/count/ladder/long/weird), uq_jumpstats_tops, enhanced_multijump, aim_trainer
- Position/practice: syn_checkpoint (or Teleportation Facilities — pick one as primary), restmenu (weapon restriction, for knife-only)
- Mode toggles: hs_mode (headshot-only — verify actual cvars via `cvarlist hs_`)
- Stats: csstats, statsx, stats_logging, stats_pug, pimpspug
- Demo review: enhanced_auto_demo, HLTV
- Round management: infinite_round (once moved into plugins folder)

### Maps (recommended set)
- Aim: aim_botz, aim_map, awp_india
- Wallbang: de_dust2, fy_pool_day, de_train
- Movement: bhop_arena, bhop_easy, kz_ maps
- Knife corridor: fy_pool_day or any small fy_ map
- Spray-pattern wall: custom-built, flat wall + grid texture

### Known unresolved items
- `plugin_teleport` — filename still unconfirmed, not yet in plugins.ini
- `hns.amxx` — confirmed cause of the CT-spawn crash, keep permanently disabled
- AimBotz pack's bundled CSBotEnabler plugin — drop it, keep the map, use YaPB instead

### Custom builds — designed but not yet built
1. **Unified practice-mode plugin** — checkpoint + infinite ammo + noclip toggle + instant respawn in one command, replacing several separate tools
2. **Damage-lane + recoil-lane range** (inspired by Rainbow Six Siege's Shooting Range) — dummy targets at selectable distances/stances showing damage-per-hit-location, plus a visual spread/recoil-pattern readout on a flat target
3. **Real recoil-pattern import** — apply published CS2 weapon spray coordinates as viewpunch via ReAPI, for genuinely transferable spray-control muscle memory
4. **Grenade/projectile lead-trainer** — moving target + thrown/arced projectile, trains lead-prediction separately from hitscan tracking
5. **Pop-up target range** — timed target spawn/despawn with score tracking, trains flick speed distinctly from bot tracking
6. **180-degree turn trainer** — the QuakeWorld sensitivity-calibration drill, scored
7. **Sensitivity/crosshair calibration finder** — cycles sens values, runs a timed flick test at each, reports the best-performing value
8. **Unified database-backed stats system** — MySQL module, replaces flat-file stat tracking with real historical queries
9. **Auto weekly report to Discord** — AMXX socket module, posts formatted session summary via webhook
10. **Achievement/milestone system** — cross-plugin framework recognizing streaks and PBs

### Already-have-and-didn't-know-it
- **Hitbox visualizer** — already in your Phase 6 command sandbox: "Toggle Hitbox ESP" → `admin_spec_esp 1`

## 2. What to actually do next, in order

1. **Close out current setup** — confirm `plugin_teleport`'s filename, pick one checkpoint tool as primary (syn_checkpoint or Teleportation Facilities, not both), get aim_botz running clean with YaPB only.
2. **Build the unified practice-mode plugin first.** It's self-contained, solves a real gap, and every technique in it (cvar toggles, bind-driven commands, checkpoint storage) reappears in everything else on this list — it's the right first custom build to learn the patterns on.
3. **Build the damage-lane + recoil-lane range.** This is your best-understood gap with a concrete, proven blueprint (R6 Siege already built the exact feature set) — highest payoff relative to effort right now.
4. **Build the recoil-pattern import plugin** using real CS2 spray data — direct extension of the tracer/wallbang work you already have.
5. **Build the grenade lead-trainer and pop-up target range** — same core "spawn target, measure response, score it" mechanic reused across both, plus the 180-trainer and sens-finder later.
6. **Wire everything into the menu** (below) once the plugins exist — no point building the menu before the commands it triggers are real.
7. **Later phase:** database stats, Discord webhook, achievement system — these are polish/infrastructure, not core training value, so they come after the actual training tools work.
8. **Much later phase:** GameBanana/ModDB packaging and release; the SDK-based original mod project remains its own separate, later effort.

## 3. Wiring it into an in-game menu

Two different menus are in play, and they serve different moments:

- **GameMenu.res** — the pre-join main menu (already customized in Phase 6). Good for one-click map loads before you're even in a server.
- **commandmenu.txt** — the in-game sandbox menu, bound to a key (e.g. `bind "h" "+commandmenu"`). This is the right place for pre-round setup toggles, since you're already live in the server choosing configuration before a training block starts.

Here's the expanded `commandmenu.txt`, building directly on your existing Phase 6 structure with new categories added:

```
"1" "Ultimate Training Suite"
{
	"1" "Spawn/Bot Controls"
	{
		"1" "Add YaPB Bot" "yb add"
		"2" "Freeze All Bots" "yb pause 1"
		"3" "Unfreeze Bots" "yb pause 0"
		"4" "Kick All Bots" "yb kickall"
	}
	"2" "Nade & Trace Visuals"
	{
		"1" "Enable Nade Cam & Trails" "amx_grenadetrail 1; amx_grenade_cam 1"
		"2" "Disable Nade Cam & Trails" "amx_grenadetrail 0; amx_grenade_cam 0"
		"3" "Toggle Bullet Traces" "amx_bullet_traces 1"
		"4" "Toggle Hitbox ESP" "admin_spec_esp 1"
	}
	"3" "Sandbox Physics"
	{
		"1" "Toggle Noclip" "noclip"
		"2" "Toggle Godmode" "god"
		"3" "Save Checkpoint" "say /sp"
		"4" "Teleport to Checkpoint" "say /tp"
	}
	"4" "Mode Restrictions"
	{
		"1" "Knife Only (Restrict All Weapons)" "amx_restmenu"
		"2" "Headshot Only - Both Sides ON" "hsonly_ct 1; hsonly_t 1"
		"3" "Headshot Only - Both Sides OFF" "hsonly_ct 0; hsonly_t 0"
	}
	"5" "Practice Mode"
	{
		"1" "Enable Practice (God+Noclip+Ammo)" "god; noclip; give weapon_ak47"
		"2" "Disable Practice" "god; noclip"
		"3" "Instant Respawn Round" "sv_restart 1"
	}
	"6" "Quick Map Load"
	{
		"1" "Aim Botz" "map aim_botz"
		"2" "Aim Reflex" "map aim_reflex_v2"
		"3" "Wallbang (Dust2)" "map de_dust2"
		"4" "Knife Corridor (Pool Day)" "map fy_pool_day"
		"5" "Bhop Arena" "map bhop_arena"
	}
}
```

## 7. Final round of additions — release packaging, new drills, and the honest capability ceiling

### Prefire maps/routes — confirmed high priority
Explicitly called out as a must-have for teaching players quickly. Since no purpose-built CS 1.6 prefire maps exist the way they do for CS2, the buildable path stays as planned: hand-built angle sets on your existing maps (de_dust2 corners, fy_pool_day box angles) as YaPB bot-hold configs, graded by the practice-mode plugin's timer. This moves up alongside the practice-mode plugin in priority — it's the single fastest way to teach a new player useful angles, which is exactly the "teach players quickly" goal.

### Release packaging (from the CS2-parity research pass)
- **One-click auto-configurator installer** (.bat/PowerShell) — maps directories, writes CS2-parity cvar profiles into autoexec.cfg, links command-menu bindings automatically on extraction. High priority — directly serves the eventual GameBanana/ModDB release.
- **Instant benchmark/metric logger** — same as the database-backed stats system already planned, just confirmed as a release-critical feature, not optional polish.
- **Preset training profiles ("Meta" switch)** — Entry Fragger / Tracking / Spray Control quick-select in commandmenu.txt, switching cvar bundles instantly instead of manual entry.

### New drills confirmed for the roadmap
- **Pure reaction-time isolation test** — isolates raw reaction speed from aim entirely, the cleanest single number for tracking real improvement.
- **Forced weapon-rotation training** — random weapon each life during DM/aim sessions, prevents over-specializing on one or two weapons.
- **Clutch/pressure scenario drills** — scripted 1vX disadvantage scenarios via YaPB, trains composure under pressure rather than mechanics.
- **Predictive feedback loop** — cross-references specific drill scores against actual live-match performance over time. This is the single highest-value addition on the entire list: it's what proves which drills are actually working instead of just producing more numbers.
- **Demo tagging/bookmarking tool** — timestamp key moments (deaths, round losses) in already-recorded demos, finally closing the "underused demo review habit" gap flagged early in this build.

### The honest capability ceiling (confirmed this session)
A few pitched ideas don't hold up against GoldSrc's actual engine limits — worth remembering so nothing gets built on a false premise:
- **No live picture-in-picture viewport** — this engine cannot render two live views on screen simultaneously. The nade-camera feature becomes an auto-switching spectator follow-cam instead, not a floating PIP window.
- **YaPB bots can't hit millisecond-precise scripted exposure windows** — the "peek-a-boo" reaction range needs a custom scripted entity standing in for a bot, not actual bot AI.
- **CS2 movement/speed matching is an approximation, not identical feel** — match the published numbers as closely as GoldSrc cvars and ReAPI allow; don't oversell it as a perfect recreation.

## 9. FROGHOUSE vision — what's actually new here vs. already covered

That blueprint has a lot of high-level framing language ("Hacker-Designer methodology," "Trench Solution," etc.) that's vision/positioning, not build tasks — worth having as your own project narrative, but not something to translate line-by-line into the technical plan. Here's what's genuinely new or meaningfully refines something already on this list:

### Already validated by this document (not new, but confirmed direction)
- **Counter-strafe zero-velocity enforcement** — this is the same idea as the already-planned "counter-strafe velocity lockout" feature. Good sign your own thinking lines up with what's already on the roadmap.
- **Xash3D/Dreamcast engine work** — this is your separate ongoing Half-Life-on-Dreamcast project, now explicitly framed as part of the same larger FROGHOUSE identity. Stays a separate, later effort — doesn't change the CS 1.6 suite's build order.
- **Predictive analytics / fatigue correlation** — same core idea as the already-planned predictive feedback loop, described with a "telemetry" framing.

### Genuinely new additions worth building
- **Asymmetric recoil design philosophy** — when building the recoil-pattern import plugin, don't just import CS2 spray data verbatim; deliberately design distinct, learnable spray *profiles* per weapon archetype (violent vertical snap for AK-style rifles vs. precise horizontal tracking for M4-style platforms). This is a real refinement to how that plugin should be built, not just what data it imports.
- **Adaptive drill recommendation** — a genuine new feature: rather than just logging stats, have the system actively recommend a specific next drill based on recent session data (e.g., "your prefire clear times spiked after your last loss — here's a counter-strafe block to run"). This is a step beyond the predictive feedback loop — it's the feedback loop actually acting on itself, not just reporting.
- **Post-loss/tilt-specific performance tracking** — a more specific version of the fatigue analytics idea: tag sessions or reps that immediately follow a loss/high-stress moment, and track whether mechanics specifically degrade there. Narrower and more actionable than general fatigue tracking.
- **CS2-map-backporting design philosophy** — genuinely useful guidance for the Mirage/Cache from-scratch mapping project (if no existing ports turn up): don't try to recreate every visual detail, ask "how would this layout have been built in the 1.6 era" and strip to pure structural brushes, high-contrast readability, and predictable clip geometry. This is real, practical mapping guidance, not just aesthetic preference — it also happens to be less work than a 1:1 visual recreation, which matters given how large a undertaking that project already is.

### Vision language, not build tasks
The "Trench Solution" narrative (offline deterministic sandbox as an escape from cheaters/inconsistent matchmaking) and the "Developer-Player-Creator Hybrid" trajectory diagram are positioning and personal narrative — useful for how you talk about FROGHOUSE publicly, not something with a corresponding checklist item here.


1. **Confirm the AMXX/gamedata fix is fully stable** — verify the "sv global variable" errors are gone before building anything else on top of this foundation.
2. **Prefire angle-set configs on existing maps** — fastest path to actually teaching new players, explicitly prioritized.
3. **Unified practice-mode plugin** — still the right first custom build; prefire grading and clutch scenarios both depend on its reset/checkpoint functionality.
4. **One-click auto-configurator installer** — moved up given its direct role in the eventual public release.
5. **Recoil-pattern import plugin** (doubles as the Recoil Master/ghosthair equivalent, extended with the burst-multiplier/bloom idea).
6. **Damage-lane + recoil-lane range.**
7. **Multi-angle Crossfire configs + clutch/pressure scenario drills** — built together, same underlying YaPB scenario-config system.
8. **Predictive feedback loop between drills and live performance** — the capstone feature; build once enough drill data exists to actually correlate against.
9. **Everything else** — reaction-time test, weapon rotation, demo tagging, pop-up target range, 180 trainer, sens finder, preset profile switcher, Discord webhook, achievements — all confirmed, all still valid, ordered behind the above based on impact.

