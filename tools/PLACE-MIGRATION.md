# Place migration: `old-v3.rbxl` → `current-baseplate-build.rbxl`

What the code in `src/` expects to find in the DataModel, and how the old place maps onto it.

Re-run the checker any time after editing the place:

```bash
lune run tools/verify-assets.luau current-baseplate-build.rbxl
```

It resolves every path the code indexes and reports what's missing, split into **hard**
(code indexes it directly and will error) and **soft** (guarded, degrades gracefully).

---

## Headline: do not bulk-copy the old Workspace

Running the checker against both places:

| Place | Paths present | Missing (hard) |
|---|---|---|
| `current-baseplate-build.rbxl` | **62 / 64** | **2** |
| `old-v3.rbxl` | 20 / 64 | 39 |

**The baseplate is already the correct structure; the old place is not.** V3 uses entirely
different folder names (`KitchenFolder`, `SpillsFolder`, `OrderingSystemFolder`,
`TipJarsFolder`, …) and none of the `Assets/*` or `Networking` layout the new code reads.

Pasting old-v3's Workspace in wholesale would give you a second, parallel hierarchy under
the wrong names — the scripts would still find nothing, and you'd have duplicate geometry.

**Do this instead:** keep the baseplate's folders as the destination and move the *contents*
(geometry, models) from the old folders into them, per the table below.

---

## Workspace mapping

| `old-v3.rbxl` | → `current-baseplate-build.rbxl` | Status |
|---|---|---|
| `OrderingSystemFolder` | `Ordering System` | **Already done.** Same 12 `Register` parts, `Status Screens/Model`, `Staff Screens/Model`. The baseplate additionally has `Pick Up`, which V3 lacked. |
| `OrderingSystemFolder/Computers` | `Ordering System/Computers` | Done |
| `OrderingSystemFolder/Status Screens` | `Ordering System/Status Screens` | Done |
| `OrderingSystemFolder/Staff Screens` | `Ordering System/Staff Screens` | Done |
| — | `Ordering System/Pick Up` | New in V3 codebase. Children are pickup nodes; each gets a `ProximityPrompt` at runtime. |
| `KitchenFolder/Givers` | `Assets/Kitchen/Givers` | Mostly done — **5 models missing**, see below |
| — | `Assets/Kitchen/Syrups` | New. Holds flat area `Part`s; `KitchenService:_spawnSyrupDispensers` clones a dispenser per syrup across each part's X width at runtime. Do **not** hand-place dispensers. |
| — | `Assets/Kitchen/Modules` | Present in baseplate |
| `SpillsFolder/Planes` + `Tables` | `Assets/Spills/Areas` | Rename/merge — the code reads `Spills.Areas:GetChildren()` and picks one at random |
| `SpillsFolder/Active` | `Assets/Spills/Active` | Runtime parent for spawned spills; must exist and start empty |
| — | `Assets/Spills/Boards` | New in V3 codebase |
| `SpillsFolder/Extra` | *(drop)* | No consumer |
| `LeaderboardsFolder` | `Assets/Leaderboards` | **Copy.** Keep the `Global` / `Monthly` / `Statues` sub-folders exactly. Drop the `Most Tips` board — tipping is cut. |
| `LeaderboardsFolder/Global` | `Assets/Leaderboards/Global` | All-time boards |
| `LeaderboardsFolder/Monthly` | `Assets/Leaderboards/Monthly` | Reset per calendar month automatically (store name is namespaced by month) |
| `LeaderboardsFolder/Statues` | `Assets/Leaderboards/Statues` | Each statue needs `Configuration` with `Leaderboard` (ObjectValue → board), `Pos` (IntValue → rank), `Role` (StringValue), `Animation` |

### Leaderboard board contract

Board Models must be named exactly as in `LeaderboardConfig.Boards`
(`Most Staff Points`, `Most Boba Bucks`, `Most Active`, `Top Donators`) and contain:

```
<Board>
├── Union.SurfaceGui.Frame.ScrollingFrame.Template   invisible row: Rank, Username
│                                                    (with child ImageLabel), Amount
└── Part.SurfaceGui.TimePeriod                       TextLabel caption
```

A board Model whose name has no config entry is skipped silently.

### Out of scope — do not copy

These belong to systems that are cut or not yet ported. Leave them in the old place:

**Permanently cut** — these systems are not being ported at all, so leave the folders behind
and delete them if they were already copied:

`TipJarsFolder` (tipping), `ChestNodesFolder` (chests), `MinigamesFolder` (minigames),
`ZiplineFolder`, `ElevatorFolder`, `Jeep`, `Pika` (vehicles/toys), `NPCFolder` (V3's legacy
NPC system — NPCs come from V4 instead).

**Deferred to the final phase** — copy these when their service lands:

`CelebrityFolder` (+ Island page), `GroupDoorsFolder`, `RestrictedAreasFolder`,
`FountainsFolder`, `SoundFolder` (music), `LoadingCamerasFolder` (loading screen).

**Still unassigned:** `ShopsFolder`, `PlayerPetsStorage`, `WorkspaceStorage`, `Staircase`,
`ThreeDTextParams`.

> `AdvertisementsFolder` is **not** in these lists — it moves to `Assets/Advertisements`.
> See `ADBOARD-SETUP.md`.

Several of these come back in later phases (Celebrity, Minigames, Chests, NPCs,
leaderboards) — copy them then, into whatever folder contract those services define.

**The cafe building, terrain and decoration** aren't in the table because no script
references them. Copy them freely; just keep them out of `Assets/` and `Ordering System/`
so folder scans don't pick up scenery.

---

## Missing kitchen givers

`KitchenService` matches recipe keys in `Recipes.Items` against **model names** inside
`Assets/Kitchen/Givers`. A recipe with no matching model silently gets no prompt.

Copy these 5 from `old-v3 KitchenFolder/Givers`:

| Model | Why |
|---|---|
| `Fruits Freezer` | Smoothie chain — without it smoothies cannot be started at all |
| `Oolong Tea Powder` | Oolong Tea is on the menu with no way to make it |
| `Salted Hot Chocolate Powder` | Salted Hot Chocolate is on the menu with no way to make it |
| `Restocking` | Restock boxes; the station is not implemented yet, so this is optional for now |
| `Peppermint Hot Chocolate Powder` | Seasonal; not on the current menu. Optional |

Everything else already matches. Note the baseplate has a `Sink` giver that V3 didn't.

### Naming rules that bite

- Model name must equal the recipe key **exactly**. The lid station is `Lid`, not `Lids`
  (this was a live bug — the recipe said `Lids`, found zero models, and no lid prompt ever
  appeared).
- Each giver needs a `PrimaryPart`; `KitchenService` uses it for the distance check and to
  parent interaction sounds.
- Tapioca and syrup stations are **generated in code** from `Recipes.Tapioca` / `Recipes.Syrups`.
  The 10 `* Tapioca` giver models are needed, but syrup dispensers are not — they're cloned
  from `SelectorModels/Kitchen/SyrupDispenser`.

---

## Named parts inside models

Some models need specifically named children:

| Path | Child | Used by |
|---|---|---|
| `Assets/Kitchen/Givers/Milk` | `Meshes/milk` | Milk pour effect — **present**, works |
| `Assets/Kitchen/Givers/Blender` | `BlenderLid` | Blender lid fade — **MISSING**. The blender models only have unnamed `MeshPart` children, so the effect is skipped with a one-time warning. Rename the lid mesh to `BlenderLid` to enable it. |
| Cup tools | `Bottom`, `Liquid`, `Slice` | `AddFruit` welds fruit to `Bottom`; `SmoothieLiquid` recolours `Liquid` and welds the garnish to `Slice` |

---

## NPC customers — copy the rig from `boba-v4.rbxl`

NPCs are ported from **V4**, not V3, so this asset comes from `boba-v4.rbxl` rather than
`old-v3.rbxl`. Do **not** copy V3's `NPCFolder`.

`ReplicatedStorage/SharedStorage/NPC` already has `Characters` (10 HumanoidDescriptions),
`InUse` and `Overhead`. It is missing the body:

| Copy from `boba-v4.rbxl` | To |
|---|---|
| `ReplicatedStorage/SharedStorage/NPCStorage/Rig` | `ReplicatedStorage/SharedStorage/NPC/Rig` |

`Rig` is an R15 Model containing `Humanoid`, `HumanoidRootPart`, the R15 MeshParts, a
`PathfindingModifier`, and an `Animate` script. Keep the `PathfindingModifier` — the
customer pathing depends on it.

Note V4 kept its Karen description under `NPCStorage/Special/Karen`, whereas this place
has Karen inside `NPC/Characters`. `CustomerConfig` follows the layout here, so no move
is needed.

## Missing sounds

`SoundService/SFX/Trip_01` and `Trip_02` are the only hard failures in the baseplate — and
they are **not in `old-v3.rbxl` either**, so there is nothing to copy. `SpillController:_Trip`
indexes them directly and will error when a player slips.

Either add two sounds under `SoundService/SFX` with those names, or guard the calls in
`src/client/Modules/SpillController.luau`.

The kitchen sound set is complete: `SFX/Kitchen/{Pour, Pop, Powder, Blender, Machine,
IceCubes, Sink}`, `SFX/UI/{Pop1, Pop2}`, `Music/Background`.

---

## ReplicatedStorage — already correct, don't touch

The baseplate has all of these and the old place has almost none of them. **Do not copy
ReplicatedStorage from old-v3.**

```
ReplicatedStorage
├── Networking            InventoryEvent, GetPurchases, RedeemCode, ClaimRank
├── Packages              wally — rebuilt by `wally install`, never hand-edit
├── Shared                rojo-synced from src/shared — never hand-edit
├── SelectorModels        Kitchen/SyrupDispenser, Fruits Cups, Fruits Slices,
│                         Cup, Mochi, Macaron, Pastry, IceCream, Pool
├── SharedStorage
│   ├── Tools/Kitchen     Cups/, Mop Whack, food tools
│   ├── Animations        ScoopAnimation_01, BlenderAnimation_01, MilkAnimation_01,
│   │                     Kitchen/GrabAnimation_01,
│   │                     TemporaryItems/{Spoon_01, BlenderLid_01, Milk_01, Lid_01}
│   ├── Effects/PickupBeam
│   ├── Spills            Tools/{Mop, MopBucket, SprayBottle, DishTowel}, Sparkles, Spills/
│   ├── Pets              PetModel source for InventoryItemDefinitions.Pets
│   └── Nametags, NPC, UIModules
└── ModelStorage
```

`ServerScriptService/Server`, `ReplicatedStorage/Shared` and
`StarterPlayerScripts/Client` are all Rojo-managed — edits there are overwritten on sync.

---

## Leftovers to delete from the baseplate

Confirmed dead, nothing references them:

- `ServerScriptService/Modules` — 5 stale services (`KitchenService`, `OrderService`,
  `PlayerAddedService`, `RankService`, `SpillService`) that predate `src/`
- `ServerScriptService/Server Scripts`
- `StarterGui/MainUILegacy`
- `StarterGui/MainUI/{Tipping, ConfigureTips, SetupTips, StaffIntern}` and
  `Popups/PriorityHolder/TipOptions` — tipping is cut

Keep the rest of `StarterGui/MainUI` and `Popups/PriorityHolder`: those frames are art
reference for the React rebuild, not live UI.
