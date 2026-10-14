# REVIVAL-001 P0.2 — Map recon memo (read-only)

Date: 2026-10-12. Source state: repo HEAD + Studio place "jacks project" (placeId 89999123284040), Edit mode.
Method: `execute_luau` probes + `screen_capture` (IDs below). No place edits made.

## Confirmed layout

| Area | Coords (approx) | Evidence |
|---|---|---|
| Spawn (4x, exterior tropical) | x -238..-186, y -4, z 434..519 | probe + `Recon_spawn_approach` |
| Entrance (BOBA tower, ad boards) | (-100, 0, 360) area | `Recon_spawn_approach`, `Recon_main_hall` |
| Main hall (circular bar, stools, registers row, menu boards) | floor y≈-10/-12; registers x -110..0, z ~330 | `Recon_counter_hall2`, `Recon_kitchen5` |
| Menu boards ("Current Orders", "Loading...") | back wall z~270-280, x -30..0 | `Recon_kitchen5` |
| Back doors → outside desert (NOT kitchen) | z < 265 at x -13 | `Recon_kitchen6` |
| Rooftop BOBA sign + pool | (14..31, 19..21, 343..350) | `Recon_kitchen2/3` |
| Basement level (`Celebrity` model, furniture) | y -50..-14, e.g. (-58,-50,393) | boards probe, density cells |
| Outside (desert, palms, Sakura Island, pool/slide, canoes) | footprint X -996..555, Z -396..1140 | footprint probe, name survey |

Map totals: ~2,169 top-level children, 243 seats, 4 spawns, 11 SurfaceGuis (ad boards),
2 ProximityPrompts + 2 ClickDetectors pre-existing (unrelated props). Almost all map
instances are generic (`Model`/`Part`) or mesh-import names — no kitchen equipment names.

## NOT found: kitchen station geometry

The kitchen from Jack's screenshots (topping bar, machines, pastry/ice-cream displays)
was not located after 8 captures + cylinder/ball/density/name probes. Suspects eliminated:
back hallway (pendant lamps, `Recon_kitchen4`), rooftop (sign + pool), back exterior
(desert). Remaining hypothesis: east wing past registers (x > 30, y -10 level).

## Wiring strategy (avoids renaming map geometry)

`KitchenService:_getMatchingModels` matches ANY descendant Model of `workspace.Assets.Kitchen`
by name, and `PromptBuilder.Attach` creates its own anchor part + PrimaryPart. So stations
are **proxy Models** (invisible anchored part in a Model named per `Recipes.Items` key)
placed at station positions — no map renames needed. Same pattern for ordering nodes.
Only station POSITIONS are needed → blocked on one kitchen anchor from Jack.

## Contract gaps found (to fix in wiring / P0.3)

- `SharedStorage.Tools.Kitchen` missing (have flat `ToolsStorage` — restructure by cloning).
- `SharedStorage.Animations.Kitchen` missing (anims exist flat in `Animations` — clone into subfolder; check Spill refs first).
- `SelectorModels.Kitchen.SyrupDispenser` missing (needs `Liquid` + `Rim` parts).
- `SharedStorage.Effects.PickupBeam` missing; `ReplicatedStorage.ModelStorage` missing.
- `Networking` missing `ClaimRank`, `RedeemCode`, `GetPurchases` (all RemoteFunctions; serverWatchers hang).
- Spill template mismatch: `Spill.luau` expects `SharedStorage.Spills.Spills.Boba` with
  `Liquid`, `MoppingAnim`, `TripRegion`, `SignStartPosition/EndPosition`, plus
  `Storage.Tools.{Mop,MopBucket,SprayBottle,DishTowel}` and `Storage.Sparkles` — place has
  only `{OldTemplate, Mop, Template, Sponge}`. Template contents unverified. Also references
  non-existent `Knit.Services.PromptService` and `Knit.Shared.ItemFader`.
- `Spills.luau` config missing `SpawnInterval` (busy-loop), `BoostMultiplier`, `BoostDuration`;
  `Min_Distance` keyed by region name (only `Floor` exists).
- `TableUtil.Random/Shuffle` used by SpillService — verify against installed fork.
