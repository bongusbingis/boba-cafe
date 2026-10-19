# M3-REM-B evidence

RESULT: DONE (code complete, gate PASS; not run in Studio per DEC-019). Open items below.

## Files changed
- New: src/shared/Configuration/PassCatalog.luau, src/shared/Configuration/Perks.luau, src/server/Modules/PerkService.luau, src/server/Tests/PerkService.spec.luau
- Edited: src/server/Modules/PetService.luau, ProgressionService.luau, CustomerService/init.luau, RealOrderService.luau

## Steps
1. PassCatalog: 11 approved rows (Barista, Senior Barista, Kitchen Leader, Staff Assistant, VIP, Premium Lounge, Star Employee, More Quests, Instant Brewing, Faster Walk Speed, Double Storage). Listed = the six on-sale; the rest Legacy. No x2/x4, Unlock All Pets, Unlimited Stock. Double Storage is a catalog row only (perk InventoryX2, no effect wired; M3-REM-D).
2. Perks: TipBoost25/50, XpBoost25/50 (Family, Value) and PetTipBonus table.
3. PerkService: HasPerk, GetFamilyBonus (max, not sum), plus GetTipBonus (max of pass Tip bonus and PetService best pet bonus). Test seam _hasPass as in QuestService. It registers catalog-only pass ids (Senior Barista, Staff Assistant, Premium Lounge, Double Storage) into GamepassUtil.Gamepasses, same precedent as QuestService's More Quests, because PlayerOwnsPassAsync returns false (with a warn) for ids not in that table.
4. PetService:GetBestTipBonus (packet scope text said GetBestTipTier; step 4 said GetBestTipBonus, used that). Unknown tier = 0 (Uncommon, Special also 0; only Basic/Rare/Epic/Legendary approved).
5. ProgressionService:AddXp multiplies amount by 1 + Xp bonus, rounded, before use. Per B2=A it applies to every AddXp caller including skipShiftCount (shift-end) calls, spill XP, quest reward XP and RealOrderService XP.
6. Tip wiring (B1=A, B3=A): CustomerService serve pay and RealOrderService pay multiplied by 1 + max(pass, pet).

## Pay/XP lines changed
- CustomerService/init.luau: the serve-payout function (the one that computes Rules.Payout, PayoutVariant, Rush Hour, then CurrencyService:Modify). Boost applied after Rush Hour, before Modify. CustomerResolved result gains `Tip` (extra BB) and the comment documents it. Pay in the result is the boosted pay.
- RealOrderService.luau: _onOrderPickedUp, after `local pay = Rules.Payout(...) * multiplier`; boosted pay is rounded only when a bonus applies (no-boost path unchanged).
- ProgressionService.lua:AddXp (amount scaled), new helper _getXpBonus.

## Gate
PASS  src/shared/Configuration/PassCatalog.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/shared/Configuration/Perks.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/PerkService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/PetService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/ProgressionService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/PerkService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS

## Test for Jack (Studio, not run by me)
1. Run the TestEZ suite (PerkService.spec, QuestService.spec, DailyRewardService.spec, Progression.spec, CustomerService.spec, RealOrder.spec should pass).
2. Without passes/pets: serve pay and XP unchanged.
3. Own Barista (or grant via test pass): serve an NPC; pay is +25% and XP +25%. Own Kitchen Leader as well: +50%, not +75%.
4. Equip a Legendary pet with no pass: pay +10%. Barista plus Legendary pet: +25% (highest wins).
5. Real-player order served: same boost on the barista's pay.
6. Quests/daily/Instant Brew still behave as before.

## Deviations and uncertainties
- Shift summary Tips line is NOT wired: ShiftService.luau (out of write scope) still sets `Tips = 0` and RecordCustomer sums only result.Pay. CustomerResolved now carries `Tip` for NPC serves; ShiftService should sum `result.Tip` into the summary Tips line (follow-up, needs ShiftService in a write scope). Real-player orders do not fire CustomerResolved, so their boost extra will not appear in that line unless a separate hook is added.
- B2=A scope: AddXp-level scaling also boosts quest reward XP, and shift-end XP. The shift card's summary.Xp and LevelAfter prediction in the ShiftEnding handler still use the unboosted shiftXp, so the card can understate XP/level by the boost. Fixing needs an edit outside AddXp (same file, KnitStart); not done per "AddXp only" scope. Say if you want it.
- Pay shown in the serve notification for boosted real orders is `+{pay}` after boost; not changed.
- PetService file end-of-file whitespace was normalized by StyLua (no code change).
- Spec uses a fake Knit.GetService / fake DataService for the AddXp test, restored afterEach.

## Follow-up (Prime: deviations 1 and 2 closed; scope widened for these)
Files also changed: src/server/Modules/ShiftService.luau, src/server/Tests/ShiftService.spec.luau (state fixture gains Tips = 0), plus further edits to ProgressionService.luau and RealOrderService.luau.
- ShiftService: ShiftState.Tips accumulates floor(result.Tip) from CustomerResolved (RecordCustomer) and via new ShiftService:AddTip (server-only, no remote) for real orders; reset per shift in newState. Summary Tips = state.Tips; summary Pay = state.Pay - state.Tips (base pay), so Pay + Tips + Bonus adds up and no-boost shifts are unchanged. Pay (state) still includes boost BB.
- RealOrderService:_onOrderPickedUp calls ShiftService:AddTip(barista, extra) in pcall via lazy Knit.GetService.
- ProgressionService:AddXp now returns the granted (boosted) XP; the ShiftEnding handler uses it for summary.Xp (serve XP already boosted + granted shift XP) and the LevelAfter prediction.
- Accepted: quest-reward XP is boosted (B2=A, all XP earned in play).

Gate output (follow-up):
PASS  src/server/Modules/ShiftService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/ProgressionService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/server/Tests/ShiftService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/ShiftService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/ProgressionService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS

Test for Jack additions: with Barista, finish a shift: card Tips = total boost BB (NPC plus real orders), Pay = base, Xp/level-up match the boosted XP. Without passes: Tips 0 and card unchanged.

## Sentry fix round (P2-1, P3-3, P3-1, P3-4)
- P2-1: CustomerService:_onServeTriggered resolves PerkService:GetTipBonus first (before any check/destroy); from the checks through the tool destroy and payout there is no yield. Header comment updated. RealOrderService:_onOrderPickedUp resolves the bonus right after the self-serve guard, before the Served marks, history Record and pay. PerkService:PlayerAdded prefetches all passes (init.server runs it for players already in the server too).
- P3-3/P3-4: base pay is no longer rounded. PerkService:TakeTipExtra (synchronous) adds base*bonus to a per-player remainder, pays floor(remainder) and keeps the fraction; cleared in PerkService:PlayerRemoving. That extra is exactly what goes to result.Tip and ShiftService:AddTip. No approved value changed.
- Specs added: PerkService.spec (GetBestTipBonus per tier/unknown/none via a PetService._equipped test seam, GetTipBonus max, remainder carry, AddXp return value), ShiftService.spec (Tips accumulation, AddTip floor, per-shift reset, summary Pay = base).
- P3-2 (GamepassUtil fail-closed cache) left as is.
Gate output:
PASS  src/server/Modules/PerkService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/PetService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/ProgressionService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/ShiftService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/PerkService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/ShiftService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
Test for Jack additions: with a Basic (2%) pet on a ~10 BB serve, every 5th serve pays +1 BB; spam-click Serve right after joining: only one payout.
