---
id: SEASON-PASS
title: Season Pass + Starter Bundle (MONETIZATION)
status: PACKET
source_commit: see git log on uhweifh, local only
---

# SEASON-PASS: "Boba Season" Season Pass + Starter Bundle

Model: sonnet (Mason), then Lens for visual gate   Studio: no (Jack tests)   Size: M-L
Depends on: MONETIZATION-AUDIT (report), ProcessReceipt (`ProductActionMap`), CapsuleService (grant + hatch), QuestService (slots/rerolls), ProgressionService (`GrantTitle`), Featured/Shop storefront.
Jack answers (2026-10-22): premium track **may include light convenience perks**; price target **299 R$**; surfacing = **Shop "Season" tab + Featured cards only**; **Starter Bundle is in scope and both live on the Featured page.**

## Goal

A 30-tier, 4-week **Season Pass** with a free track and a 299 R$ premium track (cosmetics + BobaBucks + capsules + three light convenience perks), surfaced as a Shop "Season" tab and a Featured card. A one-time **Starter Bundle** (PROPOSED ~99 R$: 300 BB + 1 Regular Pet Capsule + 1 Nametag Capsule) is built in the same lane and surfaced as a Featured card that hides once claimed. Nothing is locked behind the pass; the pass never grants serve power, and its convenience perks are chosen to **not overlap Tip/Xp pass families** (Barista/Kitchen Leader/VIP are untouched).

All economy values in this packet are **PROPOSED (JACK economy)** until Jack approves them. Robux prices are **never hardcoded** (DEC-026): the UI fetches live `MarketplaceService:GetProductInfoAsync` and the purchase prompt is click-only.

## Design summary (for the Mason)

### Season state
- `ProfileTemplate` gains (additive; reconcile fills old profiles):
  - `SeasonPass = { SeasonId = 0, Xp = 0, Premium = false, ClaimedTiers = { [number] = true } }`
  - `StarterBundleClaimed = false`
- Season identity: `SeasonConfig.GetCurrentSeasonId(now) = floor((now - SEASON_1_START_EPOCH) / SEASON_LENGTH_SECONDS) + 1` (returns 0 before the first season starts). Seasons are 28 days, anchored to a start epoch Jack confirms.
- Rollover (`_ensureState`): if the stored `SeasonId ~= current`, reset to `{ SeasonId = current, Xp = 0, Premium = false, ClaimedTiers = {} }`. **Unclaimed rewards are forfeited at rollover** (standard; see STOP-AND-ASK).

### Season XP
- Earned from existing play signals (server, all wired in `SeasonPassService:KnitStart`):
  - `CustomerService.CustomerResolved` → `Kind == "Served"` → +10 XP (flat per serve; PROPOSED)
  - `ShiftService.ShiftEnding` → +15 XP (PROPOSED)
  - `SpillService` `SpillCleanedSignal` → +5 XP (PROPOSED; **verify the exact signal name** in `SpillService`)
  - `QuestService.QuestClaimed` (new GoodSignal, see step 5) → +10 XP per claim (PROPOSED)
- Tier requirement: `SeasonConfig.XpRequired(tier) = 50 + 10 * tier` (tier 1 = 60; tier 30 = 350; total 6,150). PROPOSED.
- Season XP is **not** affected by the Xp pass family (it is pass XP, not player XP). No yield on the serve path: hooks are `task.spawn`ed from the signals.

### Tracks (PROPOSED — placeholder until Jack approves)
`SeasonConfig.TRACK[tier] = { Free = reward?, Premium = reward? }`, reward shape `{ Type = "BobaBucks", Amount } | { Type = "Capsule", Name } | { Type = "Nametag", Name } | { Type = "Title", Id } | { Type = "Perk", Perk }`.

Free track: 25 BB at tiers 3/6/9/12/15/18/21/24/27 (25 each), 1 Nametag Capsule at tier 10, 1 Regular Pet Capsule at tier 20, 1 Nametag Capsule at tier 30. (Total 225 BB + 3 capsules.)
Premium track (in addition): exclusive animated nametag `Season1Sunrise` at tier 1 (new `Nametags.luau` entry, tier Uncommon, animated, OffSale=true — the item is granted by the pass, never shop-sold), perk `QuestSlot` at tier 5, perk `HatchSpeed` at tier 10, perk `QuestReroll` at tier 15, 150 BB at tier 20, title `Season1` at tier 25 (new `Titles.MANUAL_TITLES` entry), 400 BB at tier 30. (Total 550 BB + 1 exclusive nametag + 1 title + 3 perks.)

### Convenience perks (premium-only, active while claimed this season)
Perk = claimed premium tier holds (`Premium == true` and `ClaimedTiers[perkTier] == true`). `SeasonPassService:HasPerk(player, perk)` is **synchronous** from a per-player cache.
- `QuestSlot`: +1 daily quest slot. Stacks additively with `QuestConfig.BONUS_SLOT_PASSES` (slot count = `BASE_SLOTS + passBonus + seasonBonus`; `GenerateDailyQuests` already clamps to the pool size).
- `QuestReroll`: +1 daily free reroll. Stacks additively with the Star Employee reroll.
- `HatchSpeed`: pet hatch accumulates 25% faster (elapsed × 1.25). No pass grants this; no overlap.
- **Excluded on purpose:** no Tip/Xp boost perks — they would cannibalize Barista/Kitchen Leader families (DEC-036 B3 highest-wins). If Jack later wants an XP perk, it goes through `PerkService` as a new family with explicit rules, not here.

### Premium purchase & receipt
- `ProductIds.SeasonPass: number?` (nil until Jack pastes the Creator Hub ID; nil = inert, same as Boba Party).
- `ProcessReceipt` merges a `SeasonPass` action into `ProductActionMap`: the callback receives `playerData`, sets `playerData:SetValue({ "SeasonPass", "Premium" }, true)` for the **current** season (sync, no yield — same discipline as `BobaBuckReceipts`), and returns true. A `pendingOnGranted` hook (like donations) fires `AnalyticsEvents:Custom(player, "SeasonPassPurchased")` and `Client.SeasonPassChanged:Fire(player)` deferred.
- Retroactive: premium rewards for already-reached tiers are claimable immediately after purchase; XP still gates future tiers.
- Buying in the last days still grants premium for the current season (retroactive claims only).

### Starter Bundle
- `ProductIds.StarterBundle: number?` (nil until Jack creates it). `StarterBundleConfig = { BOBA_BUCKS = 300, CAPSULES = { "Regular Pet Capsule", "Nametag Capsule" } }` (PROPOSED).
- `StarterBundleReceipts.luau` (mirrors `BobaBuckReceipts`): `BuildActions()` returns the product action. Grant is **synchronous on `playerData`**: `CurrencyService:ApplyLoaded(player, playerData, "BobaBucks", 300, "StarterBundle")`, two capsule items written directly into the profile (`playerData:SetValue({ "Inventory", "Items", "Capsules", HttpService:GenerateGUID(false) }, { Name = ..., StackCount = 1, Properties = { RandomSource = "Paid" } })` — the `ProgressionService._onLevelUp` direct-write pattern), and `playerData:SetValue({ "StarterBundleClaimed" }, true)`. Return true only after all three writes.
- Add `StarterBundle` (and `SeasonPass`) to `CurrencyService.LEADERBOARD_EXCLUDED_REASONS` — Robux-paid BB must not buy leaderboard spots (DEC-035 Q8).

### UI (STYLE.md governs — no new tokens/components)
- **Shop tab `Season`** (`src/shared/UI/Pages/Shop/Season.luau`, new): tab structure per STYLE 4.1 — transparent full-size Frame; title `TextLabel` exactly per 4.1a (AnchorPoint (0.5,0), Position (0.470149,0), Size (0.94,0.09), `Styles.GREEN`, TextScaled). Content column (vertical `UIListLayout`, Padding 0.02 scale):
  1. `Banner` (`Styles.GREEN`, text `Season {id} · {days} days left`).
  2. Buy row (only when not premium): `ShopItem`-style row using `PromptButton` ("Buy Season Pass", `Styles.GREEN`) + live price label fetched via `MarketplaceService:GetProductInfoAsync(ProductIds.SeasonPass, Enum.InfoType.Product)` (copy `Products.luau` live-fetch pattern; DEC-026). Click → `MarketplaceService:PromptProductPurchase`. If the ID is nil the row is hidden and premium tiers show "Unavailable" (fail closed, no crash).
  3. Premium status line when premium: `{n}/30 tiers claimed` in `Styles.GREEN_DEEP`.
  4. Track: `ScrollingFrame` (Active, AutomaticCanvasSize Y, BackgroundTransparency 1, ScrollBarThickness 5, black) with a vertical `UIListLayout` (Padding 0.02 scale); 30 tier rows.
- **Tier row** (page-local composition, `Pane`-based — allowed like `StatCard`, no new shared component): `Pane` ClassName "Frame", `CornerRadius = Styles.CORNER_CARD`, `Stroke = { Color = Styles.GREEN_DIM, Thickness = 1 }`, `Native.BackgroundColor3 = Styles.OFFWHITE`, list layout horizontal. Children: tier number + reward text (`Styles.GREEN_DEEP`, TextScaled, `MaxTextSize = 18`), a FREE/PREMIUM tag (`Styles.GRAY` / `Styles.GOLD`), and a `PromptButton` (Size (0.22,0.7)):
  - Claimable → "Claim", `Styles.GREEN_DIM`, calls `ClaimTier`.
  - Claimed → "Claimed", `Styles.GRAY`, Disabled.
  - XP-locked → "Locked", `Styles.GRAY`, Disabled, plus a `Styles.GRAY` "Needs X XP" hint line.
  - Premium-locked (free tier has no reward) → "Premium", `Styles.GOLD`, click opens the Roblox purchase prompt (click-only; if not premium).
  - Loading: centred spinner (asset 5634393881, per STYLE 2.5) while state/prices load.
- **Featured page** (`Featured.luau`): add two `FeaturedCardData` entries:
  - `SeasonPass`: Name "Season 1", live price fetched like the Boba Party card (`EventProducts.fetchPrices` pattern but for `ProductIds.SeasonPass`), `TopBanner = { Color = Styles.ROSE_MID, Text = "New Season", Size = UDim2.fromScale(1.05, 0.28) }`, `OnClick` → `Knit.GetController("DialogController").OpenShopRequested:Fire("Season")` (reuses the existing shop-open mechanism).
  - `StarterBundle`: Name "Starter Bundle", live price, `TopBanner = { Color = Styles.GREEN_BADGE, Text = "Best Value", ... }`, `OnClick` → `PromptProductPurchase(Players.LocalPlayer, ProductIds.StarterBundle)` (only when id ~= nil); card **hidden** when `StarterBundleClaimed` is true (read from `DataController.LocalPlayerData`).
  - Card images: use existing asset IDs as placeholders (e.g. `rbxassetid://16728139086` for Season, `rbxassetid://6073658218` for Starter). Jack may supply key art later; **not a blocker** (assets exist).
- **Shop init** (`Shop/init.luau`): add `{ Key = "Season", Label = "Season", LayoutOrder = 1, Content = c(require(script.Season)) }`; renumber existing tabs (Products 2 … Group Benefit 7). The existing landing-key loop already finds "Season"; no extra mapping needed.
- **Story**: `Stories/Season.story.luau` (0.7×0.7 centered frame rendering the page with fake state; guard runtime-only work with `RunService:IsRunning()` per STYLE 4.3/HUD recipe).
- Copy per STYLE §7: Title Case buttons ("Buy Season Pass", "Claim", "Locked", "Premium"); sentence-case hints ("Complete serves, spills, shifts and quests to earn Season XP."); BB with thousands separators.

## Read (only these)
- `docs/STYLE.md` §1 (tokens), §2.5 (lists/scrolling), §3.2/3.3 (OpenableMenu, PromptButton, Banner, ShopItem), §4.1/4.1a (page recipe), §7 (copy).
- `src/shared/UI/Pages/Shop/init.luau`, `Featured.luau`, `Products.luau`, `Pets.luau` (tab + live-price + purchase-prompt patterns).
- `src/shared/UI/Components/Buttons/PromptButton.luau`, `ShopItem.luau`, `Banner.luau`; `src/shared/UI/Components/Pane.luau`.
- `src/server/Scripts/ProcessReceipt.server.luau` (whole — `ProductActionMap`, `pendingOnGranted`).
- `src/server/Modules/BobaBuckReceipts.luau`, `DonationReceipts.luau` (module action pattern).
- `src/server/Modules/CapsuleService.luau` — `GrantEarnedCapsule`, `currentSessionElapsed`, `flushAccumulatedTime`, `completePendingHatches` (grep those names).
- `src/server/Modules/QuestService.luau` — `_ensureDailyQuests`, `RerollQuest`, `ClaimQuest`, `ClaimWeeklyQuest`.
- `src/server/Modules/ProgressionService.luau` — `GrantTitle`, `_onLevelUp` (the direct profile item-write pattern).
- `src/server/Modules/CurrencyService.luau` — `ApplyLoaded`, `LEADERBOARD_EXCLUDED_REASONS`.
- `src/shared/Configuration/QuestConfig.luau`, `ProfileTemplate.luau`, `ProductIds.luau`, `Titles.luau` (MANUAL_TITLES), `InventoryItemDefinitions/Nametags.luau` (entry shape + Animation).
- `src/server/Modules/SpillService/init.luau` — grep the spill-cleaned signal name before wiring step 6.
- `src/server/Tests/BobaBuckReceipts.spec.luau`, `QuestService.spec.luau` (spec style with fakes).

## Write scope
- `src/shared/Configuration/SeasonConfig.luau` (new)
- `src/shared/Configuration/StarterBundleConfig.luau` (new)
- `src/shared/Configuration/ProductIds.luau` (add `SeasonPass`, `StarterBundle` stubs + types)
- `src/shared/Configuration/ProfileTemplate.luau` (add `SeasonPass`, `StarterBundleClaimed` + types/defaults)
- `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau` (add `Season1Sunrise` — OffSale)
- `src/shared/Configuration/Titles.luau` (add `Season1` manual title)
- `src/server/Modules/SeasonPassService.luau` (new)
- `src/server/Modules/StarterBundleReceipts.luau` (new)
- `src/server/Scripts/ProcessReceipt.server.luau` (merge both product actions)
- `src/server/Modules/CurrencyService.luau` (two excluded reasons)
- `src/server/Modules/QuestService.luau` (season slot/reroll bonuses; new `QuestClaimed` GoodSignal)
- `src/server/Modules/CapsuleService.luau` (hatch-speed multiplier in elapsed accumulation)
- `src/shared/UI/Pages/Shop/init.luau` (Season tab)
- `src/shared/UI/Pages/Shop/Season.luau` (new)
- `src/shared/UI/Pages/Shop/Featured.luau` (two cards)
- `src/shared/UI/Stories/Season.story.luau` (new)
- `src/server/Tests/SeasonPass.spec.luau` (new)
- `src/server/Tests/StarterBundleReceipts.spec.luau` (new)

## Steps
1. **SeasonConfig.luau** (pure data + pure helpers, like `QuestConfig`): `SEASON_LENGTH_SECONDS = 28 * 86400`, `SEASON_1_START_EPOCH` (PROPOSED; see STOP-AND-ASK), `TIER_COUNT = 30`, `GetCurrentSeasonId(now)`, `XpRequired(tier) = 50 + 10 * tier`, `XpCumulative(tier)`, `TRACK` table exactly as "Tracks" above with every economy line `-- PROPOSED (Jack)`, `PERK_TIERS = { QuestSlot = 5, HatchSpeed = 10, QuestReroll = 15 }`, `HATCH_SPEED_MULT = 1.25`, `XP` constants for the four sources (all PROPOSED). No Instances, no services.
2. **StarterBundleConfig.luau**: `BOBA_BUCKS = 300`, `CAPSULES = { "Regular Pet Capsule", "Nametag Capsule" }` (PROPOSED).
3. **ProductIds.luau**: add `SeasonPass: number?` and `StarterBundle: number?` to the type and table (`nil` — inert until Jack pastes IDs). Do not touch existing IDs.
4. **ProfileTemplate.luau**: add the `SeasonPass` type/defaults and `StarterBundleClaimed = false` (additive only; reconcile fills old profiles).
5. **QuestService.luau**: import `GoodSignal` from `Packages`; add `QuestService.QuestClaimed = GoodSignal.new()`; fire it (pcall-guarded) after a successful `ClaimQuest` and `ClaimWeeklyQuest`. In `_ensureDailyQuests` add the season bonuses: resolve `SeasonPassService` at call time inside `pcall` (nil-safe), `slotCount = QuestConfig.BASE_SLOTS + (hasBonusSlot and 1 or 0) + (season:HasPerk(player, "QuestSlot") and 1 or 0)`; `freeRerolls = (pass and 1 or 0) + (season:HasPerk(player, "QuestReroll") and 1 or 0)`. No other behavior changes; a missing SeasonPassService means no bonus.
6. **SeasonPassService.luau** (Knit service, `Client = { SeasonPassChanged = Knit.CreateSignal(), GetSeasonState = ..., ClaimTier = ... }`):
   - Per-player cache `{ SeasonId, Xp, Premium, ClaimedTiers }` set in `PlayerAdded` after `GetDataAsync`, and kept in sync on every write; `_ensureState` normalizes + rolls over (forfeit).
   - `AddSeasonXp(player, amount)` — profile read via `DataService:GetDataAsync(player):andThen(...)`, `SetValue({ "SeasonPass", "Xp" }, ...)`, fire `SeasonPassChanged`. Reject `amount <= 0` and non-number.
   - `ClaimTier(player, tierIndex)` — per-player lock (`questLocks` pattern), validate with pure `SeasonConfig.ValidateClaim(state, tierIndex)` (returns `Ok | Locked | Claimed | PremiumRequired | InvalidTier`), then **grant capsules first** via `CapsuleService:GrantEarnedCapsule` (fail → return reason, do not mark claimed — the quest pattern), then mark the tier claimed (`SetValue`), then pay BB via `CurrencyService:Modify(player, "BobaBucks", amount, "SeasonPass")`, insert the exclusive nametag via the direct profile write (`ProgressionService._onLevelUp` pattern, GUID, `Equipped = false`), and grant titles via `ProgressionService:GrantTitle`. Perk tiers need no grant — `HasPerk` reads the claimed set.
   - `GrantPremium(player)` (called by the receipt action; receives `playerData`) — sync: `playerData:SetValue({ "SeasonPass", "Premium" }, true)` for the current season; update the cache; fire `SeasonPassChanged` deferred (`task.spawn`).
   - `HasPerk(player, perk)` — synchronous cache read: `Premium and ClaimedTiers[PERK_TIERS[perk]] == true`; returns false when the cache is cold (fails closed).
   - `KnitStart`: connect the four XP sources (each `task.spawn` + `pcall`): `CustomerService.CustomerResolved` (Kind == "Served"), `ShiftService.ShiftEnding`, the spill signal (verify name), `QuestService.QuestClaimed`. Resolve services inside the handlers, never at require time.
   - `PlayerRemoving`: clear the cache and locks.
7. **CapsuleService.luau**: add a sync helper `_hatchMultiplier(player)` = `SeasonPassService:HasPerk(player, "HatchSpeed") and SeasonConfig.HATCH_SPEED_MULT or 1` (pcall-guarded, default 1). Apply to elapsed time in exactly the places elapsed is computed: `currentSessionElapsed` (used by `GetHatchTimeRemaining`, `TryCompleteReadyHatch`, and the 60 s loop) and `flushAccumulatedTime`. Never change the stored `TimeAccumulated` semantics (stored seconds remain raw; the multiplier scales session seconds at read/write time).
8. **StarterBundleReceipts.luau**: `BuildActions()` → `{ Name = "Starter Bundle", Grant = grant }`; `grant(player, receiptInfo, playerData)` validates the product id, then applies the three synchronous writes (BB via `ApplyLoaded`, two capsule `SetValue` inserts, `StarterBundleClaimed = true`); return false with a reason on any failure. `GetAmount`-style helper for the spec.
9. **ProcessReceipt.server.luau**: merge `StarterBundleReceipts.BuildActions()` and a `SeasonPass` action (`{ "Season Pass", function(player, _receipt, playerData) return SeasonPassService:GrantPremium(player, playerData) end }`) into `ProductActionMap`, with the same collision-warn guard as donations/packs. Add a `pendingOnGranted` hook for the season pass that fires `AnalyticsEvents:Custom(player, "SeasonPassPurchased")` and `SeasonPassService.Client.SeasonPassChanged:Fire(player)`. No other changes to the receipt flow.
10. **CurrencyService.luau**: add `SeasonPass = true` and `StarterBundle = true` to `LEADERBOARD_EXCLUDED_REASONS` (with a comment citing DEC-035 Q8).
11. **Titles.luau / Nametags.luau**: add `{ Id = "Season1", Text = "Season 1", Source = "Manual", Description = "Season 1 pass holder", UnearnedDisplay = "Secret" }` to `MANUAL_TITLES`; add `Season1Sunrise` to `Nametags.luau` (Uncommon, animated like `Tangerine`, `OffSale = true`, `CanBeSold = true`, Price `" 150"` — it is never shop-listed because `OffSale`, price is inert). Both marked PROPOSED (Jack).
12. **Season.luau + Shop/init.luau + Featured.luau + story** exactly per the UI section above. Live prices only (DEC-026); all click handlers from player clicks; no new Styles tokens; every text label uses `Styles.FONT_FREDOKA`; siblings carry `LayoutOrder`.
13. **Specs**: `SeasonPass.spec.luau` — `GetCurrentSeasonId` boundaries (before start → 0, exact epoch → 1, +27d → 1, +28d → 2), `XpRequired`/`XpCumulative` values, `ValidateClaim` decision table (Ok/Locked/Claimed/PremiumRequired/InvalidTier), rollover reset forfeits. `StarterBundleReceipts.spec.luau` — grant writes BB + two capsules + flag on a fake `playerData`; unknown product returns false; collision-safe BuildActions. Follow the fake-based style of `BobaBuckReceipts.spec.luau`.
14. Run `stylua` on every changed/new Luau file, then `scripts/gate.sh <files>` (no new Selene/StyLua findings vs HEAD; `rojo build` passes). Do **not** run a live TestEZ session while another Rojo/Studio runtime run is in progress (DEC-007).

## Done when
- A fresh profile gets `SeasonPass = { SeasonId = 0, Xp = 0, Premium = false, ClaimedTiers = {} }` and `StarterBundleClaimed = false`; old profiles reconcile the same fields.
- Serving, shifts, spill cleaning and quest claims add Season XP; the Shop "Season" tab shows the track, claims free tiers, and shows premium tiers locked until purchase.
- The 299 R$ product (once Jack pastes the ID) grants premium for the current season; premium rewards for already-reached tiers become claimable retroactively.
- The Featured page shows the Season card and the Starter Bundle card; the starter card hides after purchase; both purchases go through the durable `ProcessReceipt` path and answer `PurchaseGranted` only after the grant is in the profile.
- `QuestSlot`/`QuestReroll` add one extra slot/reroll while their tiers are claimed; `HatchSpeed` makes the HUD hatch timer progress 25% faster for premium holders; Barista/Kitchen Leader/VIP perk behavior is unchanged.
- The gate passes on every touched file; specs pass in Studio (RunTests attribute set, run, then cleared).

## Checks to run
- `stylua` + `scripts/gate.sh` on all touched files (no new findings vs HEAD).
- TestEZ: set `workspace:SetAttribute("RunTests", true)` in Edit, Play, read Output, clear the attribute (never edit `TESTS_ENABLED`). At minimum `SeasonPass.spec` and `StarterBundleReceipts.spec` pass; existing `QuestService`, `CapsuleService`, `BobaBuckReceipts` specs still pass.
- Studio runtime (Jack): buy path, claim path, rollover via a debug season start override if needed — recorded as evidence by Lens/Gauge per RUNBOOK.

## STOP-AND-ASK
- **Jack creates the two Creator Hub developer products** (Season Pass 299 R$; Starter Bundle ~99 R$ PROPOSED) and pastes the IDs into `ProductIds.luau`. Until then both surfaces stay inert (nil = hidden/fail-closed) — this is expected, not a blocker for building.
- **Economy approval:** the TRACK table, XP curve (`50 + 10*tier`), XP source values, perk values, and Starter Bundle contents are all PROPOSED (JACK economy). Nothing ships without Jack's approval.
- **Season start epoch:** propose first Friday after ship (`SEASON_1_START_EPOCH`); Jack confirms.
- **Rollover forfeit:** unclaimed rewards are forfeited at season end (standard). Confirm; the alternative (auto-claim premium on rollover) is a small follow-up if Jack prefers.
- **Perk overlap policy:** convenience perks are QuestSlot/QuestReroll/HatchSpeed only. If Jack wants a Tip or Xp perk in the premium track, it must be added through `PerkService` families with explicit stacking rules — do not guess (DEC-008).

## Evidence
`tasks/REVIVAL-001/SEASON-PASS/evidence.md` (gate output, spec output, Studio captures, product IDs).
