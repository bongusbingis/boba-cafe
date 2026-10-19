> **Prime override (DEC-021):** STOP-AND-ASK answered: the client stacks a 2nd OrderTicket; that is a later lane (M2-TICKET2), so stay server-only here. ADD: a title system. In `Progression.luau`, add `TITLES` (level -> title text, every 5 levels; names PROPOSED (Jack), for example Trainee, Barista, Senior Barista, …, Boba Legend). Set the player attribute `LevelTitle` on level change. Overhead display follows in M2-TICKET2. L35-50 rewards reuse existing nametag colours and particles (grep the cosmetics config).

# M2-PROGRESS: XP, levels 1-50, widening NPC orders, 2nd ticket slot, cosmetics
Model: sonnet   Studio: no   Depends on: M2-SHIFT (ProfileTemplate, CustomerService/init.luau, `ShiftEnding` signal, `CustomerResolved` signal)   Size: L

## Goal
Serving earns XP; levels 1-50 widen what NPCs order, give a second ticket at L5 and a cosmetic every 5 levels; a toast announces each level-up. Nothing is locked (DEC-011 Q10). Numbers are placeholders (DEC-017/018, task rule).

## Read (only these)
- `M1.2/design.md` lines 306-337 (§5.3-§5.4)
- `src/shared/Configuration/CustomerConfig.luau` (whole; `ORDER_POOL`, `SIZE_WEIGHTS`)
- `src/server/Modules/CustomerService/Rules.luau`: grep `function Rules.PickOrder`; read that function
- `src/server/Modules/CustomerService/init.luau`: `_pickOrderFor`, `_assign`, `_makeTicket`, `_fireTicket`, `_releaseTicket`, `_tickets` uses (grep)
- `src/shared/Configuration/ProfileTemplate.luau` lines 1-40 and 77-122 (type and defaults)
- `src/server/Modules/DataService/PlayerSetup.luau` lines 80-100 (the item-grant pattern to copy)
- `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau` lines 22-80 (names and `Tier`)
- `src/server/Modules/DialogService.luau` line 136 (`Notify`); `src/server/Modules/StatisticsService.luau` (whole)

## Write scope
- `src/shared/Configuration/Progression.luau` (new)
- `src/server/Modules/ProgressionService.luau` (new)
- `src/shared/Configuration/ProfileTemplate.luau` (add `Level = 1`, `XP = 0` and their types; nothing else)
- `src/shared/Configuration/CustomerConfig.luau` (add `MinLevel` to pool entries only)
- `src/server/Modules/CustomerService/Rules.luau` (`PickOrder` level argument)
- `src/server/Modules/CustomerService/init.luau` (pass level; ticket slots)
- `src/server/Tests/Progression.spec.luau` (new; XP curve only)

## Steps
1. **Progression.luau.** Constants, each line `-- PROPOSED (Jack)` (design §5.4): `XP_PER_ITEM = 10`, `XP_PERFECT = 5`, `XP_FAST = 5`, `MAX_LEVEL = 50`. `Progression.XpToNext(level) = 60 + 25*level + 2*level^2` (87 at L1, 447 at L9). `Progression.LevelForXp(totalXp)` (pure; walks the curve; capped at 50). Table `MIN_LEVEL_BY_ITEM` (L1 Classic Milk Tea, Regular Coffee, Fudge Brownie; L2 Taro, Strawberry syrups; L3 Hot Cocoa Classic; L4 macarons and Strawberry tapioca; L5 two-item orders; L6 iced coffee option; L7 Espresso, Cappuccino, sugar option; L8 Mango, Matcha syrups and mochis; L9 Caramel, Vanilla cocoa; L10 Mystic Burst, Banana Blast tapioca; L12 Americano and ice creams; L15 Brown Sugar, Chocolate, Passion Fruit syrups and 3-item orders) exactly as design §5.3 lists. `TICKET_SLOTS = { [1] = 1, [5] = 2 }` (a function `Progression.SlotsFor(level)`).
2. **Rewards table** `COSMETIC_REWARDS`: one entry per multiple of 5 up to 50, each `{ ItemType = "Nametags", Name = <name>, Tier = <Tier> }`, names taken in file order from `Nametags.luau` lines 22-80 (copy `Tier` from the entry). If the file has fewer than ten entries, STOP-AND-ASK (below). Titles are not built here.
3. **Profile.** Add `Level = 1`, `XP = 0` to `ProfileTemplate` (type and defaults). DataService reconcile adds them to old profiles (non-destructive, design §5.4).
4. **ProgressionService.** `Name = "ProgressionService"`. Methods: `AddXp(player, amount)` (read the profile with `DataService:GetDataAsync(player):andThen(function(proxy) ... end)`, same pattern as `StatisticsService`; `SetValue({"XP"}, ...)`; while `XP >= XpToNext(Level)` and Level < MAX: subtract, `Level += 1`, call `_onLevelUp`), `GetLevel(player)` (reads the player attribute `Level`, default 1). Set player attribute `Level` on join (after the profile loads) and on every level-up (other services and the client read it).
5. **_onLevelUp(player, level).** If `COSMETIC_REWARDS[level]` exists: grant with `proxy:SetValue({ "Inventory", "Items", "Nametags", HttpService:GenerateGUID(false) }, { Name = ..., Tier = ..., Equipped = false, Properties = {} })` (copy of `PlayerSetup.luau:89`). Then `DialogService:Notify(player, { Text = "Level up! You are now level N" .. (reward and (" · New nametag: " .. Name) or ""), SoundEnabled = true })`. Send `Text`, not `Title`/`Description` (STYLE 4.4 payload warning). Wrap the whole body in `pcall`; a failure warns and never blocks serving (RUNBOOK).
6. **XP sources.** In `KnitStart`: `CustomerService.CustomerResolved:Connect` (from M2-SHIFT): for `Kind == "Served"`, `AddXp(player, XP_PER_ITEM * itemCount + (Grade == "Perfect" and XP_PERFECT or 0) + (Fast and XP_FAST or 0))`; `itemCount` is `result.Items` (add `Items = #npc.Spec items` to the result table in init.luau, one line). `ShiftService.ShiftEnding:Connect(function(player, summary) ... end)`: add `XP = SHIFT_XP + SHIFT_XP_PER_STAR * summary.Stars` (use `ShiftConfig`), then set `summary.Xp` (total XP gained this shift, including serve XP: keep a per-player counter reset on `ShiftEnding`), `summary.LevelBefore`, `summary.LevelAfter`.
7. **Level pool.** `CustomerConfig.ORDER_POOL` entries get `MinLevel` from `MIN_LEVEL_BY_ITEM`. `Rules.PickOrder` gets an optional `level` argument (default 1) and picks only entries with `MinLevel <= level`; every existing caller keeps working. `CustomerService:_pickOrderFor` passes `ProgressionService:GetLevel(player)`. Item count: 1 item below L5, 2 items (drink plus a food from the pool) at L5-14, 3 items at L15+ (functions in Rules; config `ITEM_COUNT_BY_LEVEL = { [1]=1, [5]=2, [15]=3 } -- PROPOSED (Jack)`).
8. **2nd ticket slot.** Server side only. `_tickets[player]` becomes a list of at most `Progression.SlotsFor(level)` tickets; `_assign` treats a barista as free while `#tickets < slots`; every `TicketChanged` fire carries `Slot = index`; clearing sets that slot to nil. The `OrderService:HasActiveOrder` and pending-order guards stay as they are. The client keeps showing one ticket until Jack approves a layout (STOP-AND-ASK below).
9. **Spec** (Progression.spec.luau): `XpToNext(1) == 87`, `XpToNext(9) == 447`, `LevelForXp` boundaries at 87/88, cap at 50, `SlotsFor(4) == 1` and `SlotsFor(5) == 2`.
10. `stylua` then `gate` on all changed files.

## Done when
- A fresh profile has Level 1, XP 0; serving raises XP; crossing the curve raises Level and fires the toast.
- L5 grants the first nametag; L50 is the cap.
- The NPC pool at L1 is exactly the M1 slice.
- A barista at L5 can hold two tickets (server).
- The gate passes on all changed files.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN (Jack tests: serve 5 customers, see XP and level-up toast).

## STOP-AND-ASK
- How does the HUD show a 2nd ticket (M1.5b `OrderTicket` shows one)? Ask Jack before any client change.
- `Nametags.luau` has fewer than ten entries: ask Jack which cosmetics fill L35-L50.
- Titles at L10 and L50 ("Boba Legend"): no title system exists in code; ask Jack where titles live.
- XP for cleaning a spill: design §5.4 gives no value. Ask Jack (RATING does not award XP until answered).

## Evidence
`tasks/REVIVAL-001/M2-PROGRESS/evidence.md` (RUNBOOK step 5).
