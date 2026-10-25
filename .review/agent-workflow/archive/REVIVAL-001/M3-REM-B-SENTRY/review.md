VERDICT: FAIL

# M3-REM-B Sentry review
Scope: uncommitted diff plus new PassCatalog, Perks, PerkService, PerkService.spec (incl. ShiftService widening). Read-only static review; no Studio, Play or TestEZ (DEC-019). One P2, four P3.

## Findings

### P2-1 Serve pay now yields after the tools are destroyed: double-pay race on a cold pass cache
- src/server/Modules/CustomerService/init.luau:722-723 (tool:Destroy) then :735-737 (PerkService:GetTipBonus -> GamepassUtil:PlayerOwnsPassAsync, which awaits MarketplaceService:UserOwnsGamePassAsync). The function header (line 679) says "No yield between the FindServeTools pick and the tool destroy", and npc.State stays "AtCounter" until npc:Leave (~line 785), so the check (3) "still waiting" guard is not closed during the new yield.
- Nothing prefetches passes server-side (PrefetchAllPassesAsync has no server caller), so the first serve of a session does up to 4 sequential UserOwnsGamePassAsync calls for the Tip family (Barista, Senior Barista, Kitchen Leader, Staff Assistant), each with 3 immediate retries: roughly 0.5-1s or more, longer if Marketplace is slow.
- Scenario: a player holds two matching drinks (or a second barista rescues, or the prompt is re-triggered) and fires Serve again during that window. The second trigger passes checks 1-4 (NPC still AtCounter, ticket still held) and consumes a second tool. The NPC is paid twice; combo, stats, quests and XP double-count; the shift sees two Served for one customer. Before this change the function never yielded here. The window opens on a cold cache (every player's first serve, and while any check is in flight).
- Fix: resolve the tip bonus before the destroy (and before reading `combo`), or claim the NPC synchronously before any yield (e.g. npc.State = "Serving" or a per-npc flag, cleared on failure). Also prefetch passes on PlayerAdded in PerkService:KnitStart (GamepassUtil:PrefetchAllPassesAsync) so lookups are normally cache hits.

## P3

### P3-1 RealOrderService also yields mid-payout
- src/server/Modules/RealOrderService.luau:248-262. Record() runs before the yield, so the anti-farm history is already updated; self-serve exits at line 213 before any boost, so no self-farming. Pay is granted after the yield under pcall, so a barista leaving mid-lookup is safe. Low risk; the prefetch fix in P2-1 covers it.

### P3-2 A failed pass lookup is cached as "not owned" for the whole session
- src/shared/Utility/GamepassUtil.luau (ensureCached): on MarketplaceService failure after 3 immediate retries the catch returns false, but playerCache[passId] keeps the settled promise and is never retried. A transient Marketplace error costs a paying owner the Tip and XP boost until rejoin (only a warn). Fail-closed (no unearned pay), which is the safe direction. Pre-existing util behaviour, also affecting QuestService/DailyRewardService. Suggested: clear the cache entry in the catch so the next call retries (outside this packet).

### P3-3 Small pays round the pet boost away
- CustomerService/init.luau:739 and RealOrderService.luau:249 use math.round(pay * (1 + bonus)) on small integer pays. A 2% Basic pet changes nothing under 25 BB, a 4% Rare pet nothing under 13 BB, so these boosts are largely inert and Tips shows 0. Values match approved E21 (2/4/7/10%); rounding is consistent between NPC and real orders. Jack decision: accept, or round the extra up when bonus > 0 (pay change, needs approval).

### P3-4 Cosmetic and coverage
- RealOrderService.luau:249-251: pay may be fractional (Payout * multiplier), so tip = boosted - pay can be fractional; ShiftService:AddTip floors it (ShiftService.luau:274), so the Tips line can undercount actual BB by under 1 per order. Summary Pay is derived by subtraction so it stays consistent with the line.
- Specs: PerkService.spec covers catalog, family max, unlisted owner, pet table and the AddXp boost (level 1 needs 87 XP, so 20 * 1.5 = 30 does not level; assertion holds). Nothing tests PetService:GetBestTipBonus, GetTipBonus (max of pass and pet), the CustomerService/RealOrder tip math, ShiftService:AddTip and Tips reset, or AddXp's return value. Suggest pure-function tests for these.

## Checks
1. Pay: boost applied once, after Rush Hour and before Modify; reason stays "Gameplay" for NPC serves and unchanged (none) for real orders, so the M4-FIXES leaderboard feed sees the same reasons. Tip = boosted - pay is bookkeeping only, never paid separately. Max-not-sum holds (GetFamilyBonus max; GetTipBonus max of pass and pet). Inputs are server-side only (MarketplaceService, equippedPetsByUserId); no remote or client value. Self-serve returns before pay. PASS except P2-1.
2. Values trace to approved sources: Barista/Senior 25%, Kitchen Leader/Staff Assistant 50% (revival-plan 6.3, E20), pets 2/4/7/10% (E21); XP 25/50% per "tips & XP" in 6.3 and DEC-036 B2. Catalog IDs match revival-plan (6202153, 6202144, 15243046, 6202139, 12385781, 2126368, 219650999, 12385834, 12385760, 12385742, 14067346). Deferred IDs (7564248, 7564221, 8022138, 43707849) absent. Non-boost perks are flags only. No untraceable number.
3. Registering catalog IDs into GamepassUtil.Gamepasses mutates only the server copy of the shared table (separate VM from the client), same precedent as QuestService. Server consumers are only PlayerOwnsPassAsync, PrefetchAll and GetPassData; no server shop listing or purchase prompt iterates it (Settings.luau iterates its own gated IDs client-side). No side effect found. Cache is per player and cleared on PlayerRemoving. Yield: P2-1. Marketplace failure: P3-2 (fail-closed).
4. XP: AddXp scales once by round(amount * (1 + bonus)) and returns the granted amount; level-up math uses the same boosted amount. Serve XP and shift-end XP each call AddXp once; _shiftXp accumulates boosted amounts, so summary.Xp = earned + granted is consistent and LevelAfter uses granted. No double-boost. AddXp yields at _getXpBonus on a cold cache before any state mutation (harmless).
5. ShiftService: Tips lives in per-player state, reset by newState each shift; AddTip is not in .Client (no remote). Summary Pay = state.Pay - Tips, so Pay + Tips = actual NPC pay; real-order boost is added to both Pay and Tips and nets out (real-order base pay was never in state.Pay). No boost: Tips 0, unchanged. PlayerRemoving and clock-out clear state; AddTip with no state is a no-op; no leak. ShiftService.spec fixture updated.
6. PetService:GetBestTipBonus reads only the server snapshot equippedPetsByUserId; returns 0 for no pets, unknown tier (Uncommon, Special) or nil; cleared on PlayerRemoving. Tier strings (Basic, Rare, Epic, Legendary) match item data.
7. Specs sound; nothing obviously failing. Gaps in P3-4.
8. No new remotes, no client-trusted inputs.

## Needs Jack
- P3-3 pet boost rounding (economy; accept or approve a change).
- P2-1 is a code fix, no approval needed.

---

# Re-review (after builder fixes)
VERDICT: PASS

Static read-only review of the current working tree (DEC-019). P2-1 is closed; one new P3 and notes below.

## P2-1 closure: yield trace
- CustomerService:_onServeTriggered: the only yield-capable call (PerkService:GetTipBonus -> PlayerOwnsPassAsync await) now sits at entry, before checks (1)-(5). From the clocked-in check through FindServeTools, tool destroy, TakeTipExtra and Modify there is no new yield point: TakeTipExtra is pure arithmetic; Knit.GetService after KnitStart is a table lookup (pcall-wrapped, no WaitForChild); no WaitForChild was added. After the entry yield all guards are re-evaluated on fresh state, so a concurrent second trigger hits npc.State/ticket checks. CLOSED.
- RealOrderService:_onOrderPickedUp: GetTipBonus runs right after the self-serve guard and before the bubble/tool handling, history Record and pay; nothing after it yields except as before. CLOSED.
- PerkService:PlayerAdded is dispatched by src/server/init.server.luau (also for players already in the server), so the cache is normally warm and the entry lookup rarely yields at all.

## Remainder (TakeTipExtra)
- Returns 0 for bonus <= 0 or basePay <= 0, so negative pay and zero bonus cannot touch the remainder. Remainder is clamped at >= 0, base pay is never reduced, and the extra is floor(remainder + 1e-9), at most the true sum, so no over-pay. Server-only, inputs server-derived. No path between TakeTipExtra and Modify returns early, so the extra is not consumed without being paid. Cleared in PlayerRemoving (hook is dispatched).
- Extra feeds result.Tip (CustomerResolved) and ShiftService:AddTip; pay is paid once, Tips derived from the same extra.

## Test seam
- PetService._equipped is an ordinary non-Client field aliasing the server-local table; Knit only replicates .Client, so it is not client-reachable, and no production path reads it. Fine.

## M4-FIXES regression
- CurrencyService reasons unchanged: "Gameplay" for NPC serves, none for real orders. Modify call shape unchanged. Leaderboard feed sees the same reasons.

## New P3
- P3-5 RealOrderService.luau (TakeTipExtra call): the barista can leave during the entry yield; TakeTipExtra then writes _tipRemainder[player] after PlayerRemoving already cleared it, leaking one number per such event (keyed by the dead Player). Same for GamepassUtil Cache[userId] being recreated post-leave (pre-existing). Fix: guard `barista.Parent ~= nil` after the lookup (or in TakeTipExtra). Negligible impact.
- Earlier P3-2 (failed lookup cached as not owned), P3-3 (small-pay rounding: the remainder now fixes this for pet boosts, since fractions accumulate) remain/resolved respectively; P3-3 is superseded. Specs for TakeTipExtra, GetBestTipBonus and Tips now exist.
