# SEASON-PASS — build evidence (2026-10-23)

Task: SEASON-PASS (Season Pass "Boba Season" + Starter Bundle). Built in the repo
from packet `REVIVAL-001/packets/SEASON-PASS.md`, steps 1–14.

## Jack confirmations used (2026-10-23, structured input)

- Economy: build now with all packet values as clearly-marked `PROPOSED (Jack)`
  constants. Nothing ships without economy approval.
- Rollover: unclaimed rewards forfeited at 28-day rollover (standard).
- Build: proceed now with `ProductIds.SeasonPass/StarterBundle = nil`
  (surfaces hidden/fail-closed) until Jack pastes the Creator Hub IDs.
- Season-1 epoch: `1792972800` (2026-10-26 00:00 UTC, first Monday after
  release), per Jack 2026-10-23.

## Files

New:

- `src/shared/Configuration/SeasonConfig.luau`
- `src/shared/Configuration/StarterBundleConfig.luau`
- `src/server/Modules/SeasonPassService.luau`
- `src/server/Modules/StarterBundleReceipts.luau`
- `src/shared/UI/Pages/Shop/Season.luau`
- `src/shared/UI/Stories/Season.story.luau`
- `src/server/Tests/SeasonPass.spec.luau`
- `src/server/Tests/StarterBundleReceipts.spec.luau`

Edited:

- `src/shared/Configuration/ProductIds.luau` (nil stubs)
- `src/shared/Configuration/ProfileTemplate.luau` (additive fields)
- `src/shared/Configuration/Titles.luau` (`Season1` manual title)
- `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau`
  (`Season1Sunrise`, OffSale)
- `src/shared/Inventory/CapsuleUtil.luau` (OffSale excluded from roll pool —
  keeps the pass nametag exclusive; no-op for existing content)
- `src/shared/UI/Pages/Shop/RandomCosmeticsPurchase.luau` (odds display skips
  OffSale to match the pool; no-op for existing content)
- `src/server/Modules/QuestService.luau` (`QuestClaimed` signal + season
  slot/reroll bonuses, nil-safe)
- `src/server/Modules/CapsuleService.luau` (HatchSpeed multiplier on session
  elapsed)
- `src/server/Modules/CurrencyService.luau` (`SeasonPass`, `StarterBundle`
  leaderboard exclusions, DEC-035 Q8)
- `src/server/Scripts/ProcessReceipt.server.luau` (both product actions)
- `src/shared/UI/Pages/Shop/init.luau` (Season tab, LayoutOrder 1)
- `src/shared/UI/Pages/Shop/Featured.luau` (two cards, nil/hide fail-closed)

## Checks

- `gate` (Selene new=0 + `stylua --check` + `rojo build`) on all 20 files:
  **GATE: PASS** (3 initial findings fixed: manual table.clone, unused var,
  shadowed vars; re-run clean).
- Lune probe of `SeasonConfig` pure logic (20 checks: season boundaries,
  XP curve, full `ValidateClaim` table incl. retroactive premium): **ALL PASSED**.
- TestEZ specs written (`SeasonPass`, `StarterBundleReceipts`) but **NOT RUN**
  (Studio-only; Jack runs Play/TestEZ per DEC-019). Existing `QuestService`,
  `CapsuleService`, `BobaBuckReceipts` specs untouched.

## Still needed from Jack

1. Creator Hub product IDs pasted into `ProductIds.luau` (Season Pass 299 R$,
   Starter Bundle ~99 R$ PROPOSED).
2. Economy approval (track table, XP curve/sources, perk values, bundle
   contents, nametag/title).
3. ~~Season-1 start epoch~~ — confirmed 2026-10-26 (first Monday after release).
4. Studio run: TestEZ specs + buy/claim/rollover pass + look approval.
5. Optional: custom key art for the two Featured cards (placeholders in use).
