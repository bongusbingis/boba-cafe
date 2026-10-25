# REVIVAL-001 — Comprehensive handoff (read-only findings + plan + session state)

**Date:** 2026-10-12 · **Author:** Prime (Muse Code, `muse-wonder-1.0`) · **Status:** READ-ONLY review +
planning only. **No product code or place content was edited.** Board: `../board.json`.
Companion evidence: `recon-memo.md` (map recon), captures listed inline.

A second agent should treat this as *claims to verify*, not truth. Sections marked
[VERIFIED] were observed directly (source reads, or live `curl`/`lsof` in that window);
[UNVERIFIED] were inferred or observed in a stale window.

---

## 0. The ask (user context, verbatim intent)

- Roblox cafe simulator, Starbucks-RP structure: customer orders → cashier submits →
  barista claims in kitchen and makes it → customer picks up. Staff access historically
  gated by Roblox group rank + mandatory in-game training sessions.
- A recent Roblox chat update (age-segmented chat) killed engagement/CCU because the
  game is designed around chat. Current CCU ~3, community 2M+ group members.
- Directive: move away from professional RP toward "game, not roleplay." Make money,
  get players back. "Any proposed changes are fully in-scope." Hail-mary.
- Game: https://www.roblox.com/games/718328620/Boba-Cafe · Group 3174578.

## 1. User decisions locked this session

| # | Decision | Source |
|---|---|---|
| D1 | Core loop = **NPC customers + real customers** (hybrid; real customers order via chat-free tap/kiosk UI; NPCs are the baseline) | `request_user_input` answer 2026-10-12 |
| D2 | No new commissioned map — must work with the existing build | user interjection with screenshots |
| D3 | One `KITCHEN` anchor Part now exists roughly center-kitchen (approx (40, -6.4, 263); **verify current CFrame live**) | user interjection |

## 2. Repo architecture findings [VERIFIED via source reads]

- Stack: Rojo + Wally + Knit services/controllers + React UI + ProfileStore. Layout:
  `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`,
  `src/client` → `StarterPlayerScripts.Client`.
- Product invariants (see `docs/CONVENTIONS.md`): server authority; continued play over
  failure screens; Jack-approval-gated: failure/join blocks, publishing, economy numbers,
  promo codes, catalogs, destructive migrations (incl. ProfileStore name), secrets,
  scope widening.
- Live-state truth: `.review/agent-workflow/` started empty (no goal/tasks) — DEC-001
  (2026-10-12) records workflow adoption + baselines: Selene **201 errors / 63 warnings**,
  StyLua flags **99 files**; gate = no *new* findings in touched files.

### 2.1 Gameplay/access findings (all [VERIFIED] in source)

- **Live join lock:** `src/server/init.server.luau:40-47` kicks non-Studio players with
  group rank < 4 ("restricted to staff members only"). On its own explains ~3 CCU.
- **Ordering gate:** `OrderService.CreateOrder` requires `RankUtil:CanUseOrderingSystem`
  (rank ≥ 7); claim + kitchen prompts require `CanEnterKitchen` (rank ≥ 8). Files:
  `src/server/Modules/OrderService.luau`, `src/server/Modules/KitchenService/init.luau`,
  `src/shared/Utility/RankUtil.luau` (group 3174578; Studio simulated rank; fallback Customer).
- Order lifecycle exists in-memory: `Pending Preparation → Being Prepared → Ready for Pick Up`,
  4-digit `orderNum`, 1–4 items, 5s staff debounce, FIFO barista queue w/ `QueueUpdated`.
- Kitchen: recipe-driven proximity interactions from `src/shared/Kitchen/Recipes.luau` +
  `RecipeConstructors.luau`; name-validity checks; hold durations (e.g. Coffee Machine 7s,
  Ice Machine 5s). Deep job-sim, assumes human staff + human customers.
- **No NPC/quest code in `src/`** (grep: no NPC service; `OrderService` only *references*
  a `QuestService` via `pcall(Knit.GetService)` — does not exist).
- Data: `ProfileStore_0006` (server init `PROFILE_STORE_NAME` in
  `src/server/Modules/DataService/init.luau`), `ProfileTemplate` has Currency
  (Points/BobaBucks), Inventory (Pets/Nametags/Particles/Capsules), Statistics,
  HatchingPet, Settings. Wired stats: ItemsOrdered, BobasOrdered, OrdersCreated,
  OrdersPrepared, BobaBucksEarned/Spent. Dead counters: SpillsCleaned,
  TreasureChestsFound, CelebritiesMet.
- Capsules/pets essentially built: weighted tiers (`Tiers.luau`), 15-min active-play pet
  hatch (`CapsuleConfig.PET_HATCH_DURATION = 900`), 23 pets across Basic→Legendary.
- Spills: Points award via `CurrencyService:Modify`; cleanliness replica; **known landmine**
  at 100%: reads `CurrencyService.GlobalMulti` + missing `Config.BoostMultiplier`/
  `BoostDuration` (see `docs/SYSTEMS.md` "Known gap"). SpillService also expects
  `Config.SpawnInterval` (missing) and region-keyed `Min_Distance`.
- `Spill.luau` additionally expects `SharedStorage.Spills.Spills.Boba` (model w/ Liquid,
  MoppingAnim, animations, TripRegion, SignStart/EndPosition), `Storage.Tools.{Mop,MopBucket,
  SprayBottle,DishTowel}`, `Storage.Sparkles`, and references non-existent
  `Knit.Services.PromptService` / `Knit.Shared.ItemFader`. Place only has
  `{OldTemplate, Mop, Template, Sponge}`. [VERIFIED source; template contents UNVERIFIED].

### 2.2 Monetization findings (all [VERIFIED] in source)

- **Entire Shop UI is unwired mock data:** `Pages/Shop/Currency.luau` + `Passes.luau`
  hardcode arrays ("mock data (replace with server-provided data)"), no purchase handlers;
  `Celebrity.luau` `PurchaseButton`s have no `OnClick`; `Featured.luau` renders empty list
  (title copy-paste "Particles"); `Pets`/`RandomCosmeticsPurchase` capsule cards pass
  no `OnClick`. `ShopCategory.OnPurchase` never connected.
- `ProcessReceipt.server.luau`: only product mapped = skip-hatch (`1143554452`).
  **Unmapped ProductId → warns + returns `PurchaseGranted` (consumes, grants nothing).**
  Asset server config only. Fix before any product goes live.
- `RankClaiming.server.luau`: verifies gamepass, returns success, **`TODO` — grants nothing.**
  `RankingService.luau` is a stub. `Gamepasses.luau` defines 11 passes (Barista 6202153→rank 8,
  Kitchen Leader 15243046→rank 10, VIP, Faster Walk Speed, Instant Brew, etc.).
- `PromoCodes.server.luau` + `src/server/Configuration/PromoCodes.luau`: coherent server-only
  design (rate limits, `RedeemedCodes`, optional expiring global claims) — one of the
  healthier pieces. `CurrencyService:Modify` can drive balances negative (callers must guard).

## 3. Studio place findings ("jacks project", placeId `89999123284040`)

### 3.1 Sync state [VERIFIED-AT-TIME, NOW STALE]

In the first healthy window (after an early `rojo serve` on :34872), probes showed the
full repo synced: 13 server services, 4 `Server/Scripts`, `Server/Configuration`,
13 client controllers, 12 `Shared.Configuration`. `Networking` had only `InventoryEvent`
(remotes are authored, not synced — `ClaimRank`, `RedeemCode`, `GetPurchases` absent).

**Do not carry that forward:** Rojo later dropped (see §5), studio face was never
visually confirmed after these checks, and sync state can change. Re-verify live:
server has 13 `Modules`, 4 `Scripts`, `Configuration`, `Tests`; client has 8
`Modules` incl. `OrderController`/`KitchenController`; `Networking` contents re-checked.
Until re-proven, all §3.1 counts are **[UNVERIFIED / stale]**.

### 3.2 Authored-world gaps [VERIFIED-AT-TIME via probes]

- No `workspace.Assets`, no `workspace["Ordering System"]` (code indexes both at
  require/init time → `SpillService`, `Recipes`, `OrderService` fault). Old world archived:
  `Workspace.OldScriptables._Assets.{Spills, OrderingSystem, ...}`, `KitchenFolder`,
  `NPCFolder` (Registers/WanderPlanes/Active/Traversable/Spawn/OrderPickup),
  `ShopsFolder` (Karen, Mysterious Stranger, Bomberman, Lucy, Noodle Man),
  `ChestNodesFolder` + `Chests`, `CelebrityFolder`, `LeaderboardsFolder`, `ZiplineFolder`,
  `ElevatorFolder`, `FuseBox*`, `Fireworks`, `GroupDoors`, `TipJars`, `AdvertisementsFolder`
  (gamepass/product billboards).
- No `SharedStorage.Tools` (→ `Recipes.luau` errors at require), no
  `SharedStorage.Effects.PickupBeam` (→ `OrderController` faults), no `ModelStorage`,
  `SelectorModels` has no `Kitchen` folder. `SharedStorage.Pets` (23+ models),
  `SharedStorage.NPCs` (10 HumanoidDescriptions + Dummy + Overhead), `ToolsStorage`
  (100+ tools) all exist.
- `SharedStorage.Animations` holds flat animation instances; code expects
  `Animations.Kitchen.*` subfolder (clone, don't move, pending Spill refs).

### 3.3 Map recon summary (full memo: `recon-memo.md`)

- Footprint X -996..555, Z -396..1140; 243 seats, 4 spawns (~(-238..-186, -4, 434..519)),
  11 SurfaceGuis (ad boards + a `Celebrity` model at (-58,-50,393)).
- Confirmed [visual captures]: spawn/exterior, BOBA entrance, main hall (registers row,
  menu boards, circular bar, seating — floor y≈-10/-12), back hallway, rooftop BOBA sign +
  pool, basement level, large outside (Sakura Island, pool/slide, canoes).
- **Kitchen located** via Jack's `KITCHEN` anchor (~(40,-6.4,263)) [visual captures]:
  - West→east: topping island bar (double-sided, ~20 colorful wells) + window wall
    (pastry fridge, machines, cup stacks) — matches Jack's screenshot #5.
  - North wall counter: cups, ice/water machine, 8 topping bowls, plate/cup stacks.
  - Center island: milk jugs + cups; east: stockroom shelves, hanging staff screen,
    more counter, south stockroom doorway — matches Jack's screenshot #4.
  - Near-anchor parts (dist ≤ 24): counter `Union 3x7x50 @(34,-12,262)`, counter
    modules `Model kids=24 @(46,1,251)` / `@(38,1,282)`.
- Wiring insight [VERIFIED from `KitchenService/PromptBuilder`]: stations are matched
  **by descendant Model name** under `workspace.Assets.Kitchen`, and `PromptBuilder`
  creates its own anchor + PrimaryPart. So wiring = small proxy Models (invisible
  anchored part in a named Model) at station positions. **Zero map renames required.**

## 4. The plan (approved direction, awaiting `go`-level detail per-phase)

Priorities: revival, engagement, monetization. Phases:

- **P0.1 Rojo sync audit** — re-establish + verify full tree (see §3.1: currently stale).
- **P0.2 Map recon + wiring** — recon done; create `workspace.Assets.Kitchen` proxies
  (all `Recipes.Items` keys + `Kitchen.Syrups` parts + `SyrupDispenser` model),
  `workspace.Assets.Spills` areas, `Ordering System` proxies at registers counter,
  `Networking` remotes (`ClaimRank`, `RedeemCode`, `GetPurchases`),
  `SharedStorage.Tools.Kitchen` (clone/restructure from `ToolsStorage`),
  `SharedStorage.Effects.PickupBeam`, `ModelStorage`, `Animations.Kitchen` (clone).
  Update `docs/SYSTEMS.md` instance contract. Non-kitchen wiring is unblocked.
- **P0.3 Crash sweep** — require-time nil-index guards (`SpillService`, `Recipes`,
  `OrderController`), Spill 100% crash, `CurrencyService` negative guard, duplicate
  `TableUtil` key in `wally.toml`, `ProcessReceipt` unmapped-product safety.
  Gates: Selene/StyLua no-new-findings, `rojo build`, TestEZ in Studio.
  **Start with tests** (repo TestEZ exists — `src/server/Tests/OrderService.spec.luau`) —
  add focused coverage for the fixed defects, keep smallest file with the project.
- **P1 Open the doors** — remove join kick + rank 7/8 gates (⚠ Jack approval),
  clock-in toggle, first-minute guided order. Server+client+`RankUtil` display-only.
- **P2 Hybrid loop** — NPC service (spawner, wander-to-counter, visual order bubbles,
  patience, tips, VIP variants) reusing archived `NPCFolder`/NPCs/SimplePath;
  kiosk/tap ordering reusing `Pages/Ordering`; `OrderService` queue w/ source badges;
  Barista Levels 1–50 + shift loop w/ end-of-shift payout (stats exist).
- **P3 Money** — receipt hardening (idempotency, unmapped safe), `ClaimRank` grants or
  delist rank passes, wire Shop to live data (currency, capsules, gamepasses), honors
  in-world ad boards, capsule odds/pity. ⚠ All prices/odds/rewards = Jack approval.
- **P4 Retention** — quests (`QuestService` hooks already referenced), chests
  (`TreasureChestsFound` + archived nodes), leaderboards, Karen/Mysterious Stranger
  events, repaired cleanliness meter event.
- **P5 Relaunch** — store rewrite, group shout/wall, comeback promos, 2x weekend,
  full release gate (Gauge/Sentry/Lens/Keeper/Quill). ⚠ Publishing = Jack approval.

Validation per phase: lint/format/build gates above + real Studio Play captures
(join→payout; NPC full cycle; dual-player kiosk; purchase idempotency; quest/chest/event).

## 5. Tooling diagnosis (two Rojo incidents)

- Incident 1 [VERIFIED live via curl]: a `rojo serve` (Rokit 7.5.1) was already healthy
  on `localhost:34872` serving `boba-cafe`; failures were plugin-side (wrong port and/or
  duplicate Rojo toolbar button + plugin). Cargo `rojo` is 7.7.0; Rokit CLI 7.5.1 — all
  7.x negotiates protocol 4, versions not blocking. `rojo build` verified OK.
  Also running: `rojo sourcemap --watch` (VS Code ext, harmless).
- Incident 2: server dropped mid-build-window. **UNVERIFIED cause.** Hypotheses
  (unproven): Rojo crashed on a file change / extension restarted; plugin pointed
  elsewhere. The last live note had a fresh serve listening on :34872 with an
  Established Studio socket — possibly a slow-bind window, do not re-diagnose from that.
- **Open item:** re-confirm `rojo serve` is up (curl `http://localhost:34872/api/rojo` →
  expect `{"projectName":"boba-cafe"...}`) before any P0 work. If plugin "can't find
  server": wait 60–90s after VS Code says "serving," confirm address `localhost:34872`,
  keep only the official `rojo-rbx` plugin enabled.

## 6. Open questions for Jack (not yet answered — do not assume)

1. Economy starting points: BobaBucks per serve, capsule/pass/product prices, level
   rewards (proposal table needed at P3 — Jack approval gate).
2. Group reward design: daily bonus vs exclusive pet vs earnings multiplier.
3. Levels 1–50 unlock flavor: cosmetic-only vs gameplay perks (speed etc.).
4. Phase-scope/pricing approvals as they arise (join-block removal P1; publishing P5).

## 7. Next steps for the successor agent

1. Confirm Rojo (§5 open item), re-verify §3.1 sync state live, then update this doc.
2. Touch base with Jack on §6 items (batch them; don't block P0.3 on P3 answers).
3. P0.3 fix pass with TestEZ coverage (smallest-defect-first; gates per P0.3).
4. P0.2 wiring in Studio (Rigger lease on Studio instance
   `2681d381-0b16-4b2c-acd6-c2c9fdc9791e`, placeId `89999123284040`), proxies from §3.3
   positions (station-by-station: measure, place, name, verify prompt spawn in Play).
5. Play-verify: join → clock-in → first guided order → payout. Record capture IDs.
6. Then P1→P5 in order; keep board + this handoff current (`tasks/REVIVAL-001/`).

## 8. What was NOT touched this session

- No product code changed; no place content added/edited/removed (read-only probes,
  camera moves, and Jack's own `KITCHEN` anchor only).
- Not run: Selene, StyLua, `rojo build` (except the one-shot diagnostic build to
  `/tmp` in incident 1, exit 0), TestEZ, any Play test. All system-runtime claims are
  from source + Edit-mode inspection, not execution.
