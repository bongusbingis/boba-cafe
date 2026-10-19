> **Prime override (DEC-021):** the meter sits top-centre, directly under the TopBar time pod. Deltas (PROPOSED): spill cleaned +3, fast serve +1, walkout or wrong −2, a slow drain while spills are present. Spill XP 5 goes to ProgressionService if it exists.

# M2-RATING: Cafe Rating and Rush Hour
Model: sonnet   Studio: no   Depends on: M2-SHIFT (`CustomerResolved`, Hud/init.luau), M2-VARIANTS (CustomerService/init.luau pay path)   Size: L

## Goal
A server-wide Cafe Rating meter (starts 50%) rises with Perfect serves and clean floors and falls on walkouts; at 100% a 120 s Rush Hour brings more NPCs and double pay. Settled by design §5.6 (concept SETTLED, numbers PROPOSED).

## Read (only these)
- `M1.2/design.md` lines 339-347 (§5.6)
- `docs/SYSTEMS.md` lines 150-163 (Spills and Cleanliness)
- `src/server/Modules/SpillService/init.luau` lines 100-140 (`SpillCleaned`)
- `src/server/Modules/CustomerService/init.luau`: `_countBaristas`, `_spawnIfNeeded`, `_pacingLoop`, the pay lines in `_onServeTriggered`
- `src/shared/Configuration/CustomerConfig.luau` (`SERVER_CAP`, target per barista: grep)
- `src/shared/UI/Components/Core/Hud/OrderQueue.luau` lines 40-165, `Hud/init.luau`, `docs/STYLE.md` lines 219-235 (2.4) and 473-482 (4.3)

## Write scope
- `src/server/Modules/CafeRatingService.luau` (new)
- `src/shared/Configuration/RatingConfig.luau` (new)
- `src/server/Modules/SpillService/init.luau` (one signal only)
- `src/server/Modules/CustomerService/init.luau` (rush multipliers only)
- `src/shared/UI/Components/Core/Hud/CafeRating.luau` (new)
- `src/shared/UI/Components/Core/Hud/init.luau` (mount only)
- `src/server/Tests/CafeRating.spec.luau` (new; the delta maths only)

## Steps
1. **RatingConfig.luau**, every value `-- PROPOSED (Jack)` unless noted: `START = 50`, `PERFECT = 4`, `CLOSE = 1`, `WALKOUT = -8`, `SPILL_CLEANED = 3` (all divided by `N = max(1, clocked-in baristas)`, design §5.6), `RUSH_SECONDS = 120`, `RUSH_NPC_MULT = 1.5`, `RUSH_CAP_BONUS = 4`, `RUSH_PAY_MULT = 2`, `AFTER_RUSH = 60`, `MIN_GAP_SECONDS = 360 -- TUNING`.
2. **Known SpillService crash.** `docs/SYSTEMS.md` says the old `BoostMultiplier` path is already gone, and `grep BoostMultiplier src` finds nothing. Make no change for it; record that in evidence. Cleanliness stays clamped to 100.
3. **SpillService signal.** Add `SpillCleanedSignal = GoodSignal.new()` to the service table (require `Packages.GoodSignal` as `ShiftService` does) and fire it at the end of `SpillService:SpillCleaned` (inside `pcall`). Nothing else changes. Points stay as they are (retiring Points is an economy change: Jack's).
4. **CafeRatingService.** Pure function `CafeRatingService.Apply(rating, delta, baristas) -> number` = `clamp(rating + delta / max(1, baristas), 0, 100)` (spec it). State `rating`. Subscribe to `CustomerService.CustomerResolved` (Perfect, Close, Walkout) and `SpillService.SpillCleanedSignal`. Publish `workspace:SetAttribute("CafeRating", rating)` and `workspace:SetAttribute("RushHour", bool)` (the client reads them; no remotes).
5. **Rush Hour.** When `rating >= 100` and `os.clock() - lastRushEnd >= MIN_GAP_SECONDS` (first Rush has no gap): set `RushHour` true for `RUSH_SECONDS`, then false, `rating = AFTER_RUSH`, `lastRushEnd = os.clock()`. While rating is 100 inside the gap it stays at 100. Announce start and end with `DialogService:Notify` to every player, `Text = "Rush Hour! More customers and double pay!"` / `"Rush Hour is over."` (existing toast only; no new banner visual).
6. **CustomerService hooks (minimum edits).** Add `CustomerService:IsRushHour()` (reads the workspace attribute). Spawn target and `SERVER_CAP` read through helper functions that multiply by `RUSH_NPC_MULT` and add `RUSH_CAP_BONUS` while Rush Hour runs. Final pay in `_onServeTriggered` is multiplied by `RUSH_PAY_MULT` while Rush Hour runs (after the variant multiplier from M2-VARIANTS; round once).
7. **CafeRating.luau (HUD).** Copy STYLE 4.3 and `OrderQueue.luau`: a small meter at top centre: `Banner` title "Cafe Rating", a `ROSE_MID`-free bar using `Styles.GREEN` fill on a `Styles.OFFWHITE` track (as the patience bar does in M1.5b; if that bar component is reusable, reuse it), percent text. During Rush Hour the title text reads "Rush Hour!". Mount in `Hud/init.luau`. Hide until the player is clocked in.
8. **Not built (needs assets or Jack):** Rush Hour music, lighting, confetti (DEC-008: never substitute). Spills awarding XP (see M2-PROGRESS STOP-AND-ASK).
9. `stylua` then `gate` on all changed files.

## Done when
- Rating starts at 50, moves per the table, saturates at 100 and triggers Rush Hour once, then drops to 60.
- During Rush Hour spawn target, cap and pay change as above.
- HUD meter shows rating.
- Gate passes on all changed files.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN (Jack tests: temporarily set `START = 99`).

## STOP-AND-ASK
- Top centre is used by the TopBar time pod (STYLE 2.4/3.6). If no free spot exists beside it, ask Jack where the meter sits.
- The packet text mentions "fast serves" moving the rating; design §5.6 gives no fast delta (Perfect +4, Close +1, walkout -8, spill +3). Only those four are built. Ask Jack if fast should add more.
- Rush Hour banner, music and lighting: ask Jack for the existing assets or approval of a new banner.

## Evidence
`tasks/REVIVAL-001/M2-RATING/evidence.md` (RUNBOOK step 5). Say that the BoostMultiplier crash is already removed.
