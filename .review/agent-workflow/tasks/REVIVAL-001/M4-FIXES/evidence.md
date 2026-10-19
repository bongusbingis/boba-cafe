# M4-FIXES evidence

RESULT: PASS (gate PASS; Play and TestEZ not run per DEC-019)

## Files changed
Services: TreasureHuntService, BadgeService, LeaderboardService, CurrencyService, CustomerService/init, RealOrderService (all src/server/Modules).
Config: TreasureHuntConfig, DailyRewardConfig, QuestConfig, ProfileTemplate, LeaderboardConfig (src/shared/Configuration).
UI: DailyRewardsDialog, and QuestCard (reroll price text, step 6 hit).
Specs: BadgeService, DailyRewardService, TreasureHuntService, LeaderboardService, QuestService.

## Per step
1. Chest cooldown: PLAYER_COOLDOWN_SECONDS = 900; profile field LastTreasureChestTime = 0 (type + default). ClaimChest loads data (DataService:GetDataAsync), refuses if os.time() - last < cooldown, notifies "Next treasure chest in N min" via DialogService:Notify (existing path, as EventService uses), writes the timestamp before granting. Re-checks `_claimedChests` after the data yield. If data fails to load the chest is refused (warn). Frenzy untouched. No new remote.
2. Veteran: LEGACY_BADGES is the five IDs, marked DEC-035 Q3, DEC-037 Q12. FirstStaff stays in Badges map; join award unchanged. Spec asserts 5 entries, FirstStaff absent, and FirstStaff alone gives no Veteran.
3. Leaderboards: (a) OrdersServed +1 in CustomerService (NPC serve) and RealOrderService:_onOrderPickedUp (barista, after self-serve return and after the `not barista or #specs == 0` guard); MostBobaBucks in CurrencyService:Modify (BobaBucks, amount > 0, reason not excluded); MostActive +1/player/min loop in KnitStart. All resolved with Knit.GetService inside pcall. (b) IncrementStat adds to `_pending[userId][board]`; flushed by loop every REFRESH_INTERVAL_SECONDS, PlayerRemoving (that user), and BindToClose (waits up to 25 s on in-flight writes). One _updatePlayerStat per (user, board) per flush. (c) Hidden = true on MostTips and TopDonators; RefreshBoards skips their query and sets SurfaceGui.Enabled = false; IncrementStat ignores them. (d) RefreshStatues queries OrdersServed + MostBobaBucks only; targets "Most Tips"/"Most Boba Bucks", role containing "Tip" (or "Boba Bucks"), and index fallback 2 map to MostBobaBucks; Top Donators target/role sets a skip flag (no winner, no fallback); fallback 1 is OrdersServed only. Doc comment updated.
4. DailyRewardsDialog unpacks (promiseOk, claimOk, reason, grantResult) (convention confirmed: DailyRewardController uses `local ok, status = ...:await()`). InventoryFull toasts the capsule message; any other failure toasts "Couldn't claim right now - try again in a moment."; status untouched so the claim stays available.
5. Specs: Daily and Treasure now fake CapsuleService (HasCapsuleSpace/GrantEarnedCapsule); added full-inventory-keeps-streak case and chest-cooldown case. Daily spec amounts updated to 30/45/60/180.
6. Amounts per DEC-036 with markers. Quest rewards are per-target arrays; both generators index by the rolled target index (RNG call count unchanged). REROLL_COST_BOBABUCKS = 20.

## Excluded CurrencyService reason strings (MostBobaBucks)
- "QuestRerollRefund" (only existing positive-BB refund via Modify).
- Robux pack receipts: no Modify caller exists yet (DEC-035 Q8), so no reason string to exclude; add it to LEADERBOARD_EXCLUDED_REASONS when wired.
Counted (play-earned or grant): Gameplay, DailyReward, QuestReward, TreasureChest, and nil reason (PromoCodes.server.luau calls Modify with no reason, so promo-code BB counts; flag for Jack).

## Reroll-price hits (50 BB)
- src/shared/UI/Components/Core/Hud/QuestCard.luau:257 literal "50 BB" -> now `{QuestConfig.REROLL_COST_BOBABUCKS} BB`.
- src/server/Tests/QuestService.spec.luau: test name "charge 50", expected -50 and balance 50 -> use REROLL_COST_BOBABUCKS; the insufficient-funds test used balance 30 (now enough for 20) -> changed to 10.
- QuestService.luau uses the config constant (no change).

## Test for Jack (Studio, no automated Play)
- Open a chest, then another within 15 min: second is refused with "Next treasure chest in N min", chest stays, no BB.
- Chest pays 20-40 BB; capsule about 1 in 10.
- Join with only FirstStaff: no Veteran title; with FirstQuest etc.: Veteran.
- Serve NPCs and real players; earn BB; stay a few minutes; after about 2 min check Orders Served, Boba Bucks, Active boards fill. Most Tips and Top Donators boards are dark.
- Statue 2 shows the Most Boba Bucks leader. Any sign on statue 2 still reading "Most Tips" needs a Studio relabel.
- Fill capsule inventory, claim daily on Day 4/7: toast "inventory is full", button still available, streak unchanged. Daily BB 30/45/60/60/90/120/180.
- Quest HUD reroll button reads "20 BB"; quest rewards vary by target.

## Deviations / unsure
- QuestCard.luau and DailyRewardService.spec edits are within the packet's "any file holding a hard-coded reroll price" and "spec" scope; DailyRewardService.spec previously referenced a removed `_getInventoryServer` shim and an unfaked CapsuleService.
- Flush failures are warned and the delta is dropped (no retry), to keep to one write per (user, board).
- Promo-code BB counts toward MostBobaBucks (see above).
- Board-flush and MostActive loops start before the LeaderboardsFolder wait, so they run even if place boards are missing.

## Gate output
PASS  src/server/Modules/BadgeService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/CurrencyService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/LeaderboardService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/TreasureHuntService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/BadgeService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/QuestService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/DailyRewardService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/TreasureHuntService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/LeaderboardService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/Configuration/DailyRewardConfig.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/Configuration/LeaderboardConfig.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/Configuration/ProfileTemplate.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/Configuration/QuestConfig.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/Configuration/TreasureHuntConfig.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/UI/Components/Core/Hud/QuestCard.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
