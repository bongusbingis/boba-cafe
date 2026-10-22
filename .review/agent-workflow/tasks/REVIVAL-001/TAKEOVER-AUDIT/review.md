# REVIVAL-001 TAKEOVER-AUDIT: Sentry review of 2f41d8a

Reviewer: Sentry (read-only). Scope: the takeover checkpoint 2f41d8a, read from the commit itself (`git show 2f41d8a:<path>`).
ActivityScript.server.luau was not read. I checked later commits (up to HEAD bdd9561) only to mark which findings are
already fixed.

The following were known and being fixed elsewhere, so they are not repeated here: PourMoments cleanup/lock, register
patience, Take Order re-roll and slot recheck, LeaderboardService infinite wait, the drink clone when seating is off,
B4SeatingForce outside Studio, donation ProcessReceipt, invite friend/age checks, SmallNotification queue, and the
nickname prompt.

**Verdict: CHANGES REQUESTED.** 1 P1 (already fixed at HEAD), 4 P2, 11 P3. I found no exploit that can mint large
amounts of currency. Every reward path I checked is server-authoritative.

## P1

### P1-1 Tablet flow drops first-session scripted protection (new players can get walkouts on their first customers). Fixed at HEAD (c52bb5e, `RolledScriptedFor`).
- `src/server/Modules/CustomerService/init.luau:1029` (`local scripted = npc.Scripted`) and `:969`.
- Failure: `_onTakeOrderTriggered` gets `scripted` from `_pickOrderFor` but only uses it for `ClearVariant`. It never
  stores it on the NPC. At submit, `npc.Scripted` is still the constructor default `false`, so `SetAssignment(..., false)`
  runs.
- Effect on a brand-new player's first 3 orders (FIRST_SESSION_COUNT):
  - Patience ticks (`Npc.luau:772` skips ticking only when Scripted), so they can walk out.
  - The session-shift trim applies.
  - The serve is not forced to "Fast".
  - `Rules.Payout` treats the order as non-scripted.
  - The "Your first order!" toast never fires: `isFirstServe` requires `npc.Scripted`.
- Fix: carry the scripted roll on the NPC, keyed to the taker, and pass it to `SetAssignment`. HEAD already does this.

## P2

### P2-1 A stale NPC tablet hijacks the register's Ordering page (real-player ordering breaks for that client)
- `src/shared/UI/Pages/Ordering/init.luau:164-170`, `:381`; `src/shared/UI/App.luau:59` and `handleSetCurrentPage`;
  `src/client/Modules/OrderController.luau` (`OpenOrdering`).
- `ActiveNpcOrder` is cleared only by `closeMenu()` (the page's own close button, or a successful submit).
- The page can close without it:
  - Switching to another HUD page.
  - Pressing Take Order again while the tablet is open. `handleSetCurrentPage` toggles, so a second
    `OpenOrderingRequested` *closes* the page while it stores the new NPC.
- Failure: in both cases `OrderController.ActiveNpcOrder` stays set. The next time this player opens Ordering from the
  register prompt ("Use Ordering System", TopBar.luau:80, staff clocked out), the page falls back to the stale NPC data.
  It shows "Customer Request", validates against the old NPC, and sends the order to
  `CustomerService:SubmitNpcOrder` instead of `OrderService`. The player cannot place real-player orders until a
  tablet session ends through `closeMenu`. This is still present at HEAD.
- Fix:
  - Only use `props.Args[1]`, and drop the controller fallback, or clear `ActiveNpcOrder` from the page's unmount
    cleanup.
  - In App, make `OpenOrderingRequested` open the page (or re-render with the new args) instead of toggling it.

### P2-2 The pour meter has no gamepad or keyboard input, so console players get Poor on every pour station
- `src/client/Modules/KitchenController.luau:656` (only `tapButton.Activated`); `PourMoments.luau:187-194`
  (timeout = Poor); `OrderSpec.luau:487-494`.
- Failure: the only input is a ScreenGui TextButton. A gamepad user has no binding: no ContextActionService, no
  `ButtonA`/`ButtonR2`, no GuiService selection. Every SkillMoment station (Sink, Milk, Syrups, Tea powders, Hot
  chocolate, Coffee Machine) times out to Poor.
- Effects:
  - Every drink is at best Close, which lowers pay, combo and rating.
  - Any one minor mistake now makes the drink **Wrong**, so it cannot be served (Poor plus 1 minor = Wrong).
  - The tool keeps `PoorPours`, so the cup must be trashed.
- New players get the meter right after their first serve (session `_unlocked`), with no tutorial. Their next scripted
  orders are graded this way.
- Still present at HEAD.
- Fix: bind the tap through ContextActionService (ButtonA/ButtonR2/Space/E) while a window is open. Alternatively,
  until Jack rules on audit Q4, make a timeout neutral ("Good") and keep Poor for an actual miss.

### P2-3 The Rush minimum target ignores the barista count: 25+ NPCs spawn into an empty cafe and never leave
- `src/server/Modules/CustomerService/init.luau:539` (`rushMin = RUSH_MIN_TARGET or 25`) vs `Rules.PacingTarget(0) = 0`.
- Failure:
  - With 0 clocked-in baristas, `_pacingTarget` still returns 25 during Rush or a Boba Party. A customer can buy a
    party with no baristas on.
  - `_spawnIfNeeded` does not check `IsPaused`, so it spawns up to 25 rigs. `RUSH_SPAWN_GAP_SECONDS` is 0.2 and the
    queue cap is 35.
  - While paused, patience never ticks (`Npc.luau` `IsPaused` branches), so the crowd stays after the rush ends.
- Result: 25 animated rigs with a 0.1 s poll thread each on a server with nobody working, and a permanent crowd. This
  is server cost and blocks the counters for the next barista. Still present at HEAD.
- Fix: `if self._baristas == 0 then return 0 end` before the rush floor. Also consider scaling the floor by the number
  of baristas (for example, the floor only applies when baristas >= 1).

### P2-4 The "Global / All Time" leaderboards show this month's data
- `src/server/Modules/LeaderboardService.luau:578-593` (Global loop) and `:435` (`"All Time"` label).
- Failure: the Global boards call `GetTopEntries(boardType)`, which reads `LeaderboardConfig.GetMonthKey` (the monthly
  store). The header says "All Time", but the table resets every month, so the board misleads players.
- The loop also issues a second `GetSortedAsync` per board per refresh, doubling the OrderedDataStore read budget for
  the same data.
- Still present at HEAD.
- Fix: until an all-time store exists, either hide the Global boards or label them with the month. Fetch entries once
  per board and reuse them for Monthly and Global.

## P3

1. **Pour timing claim can be forged for a guaranteed Perfect.** `PourMeter.luau:96-102`, `PourMoments.luau:273-285`.
   - The client sends `claimedElapsed`. The server accepts any value in [serverElapsed - 0.3, serverElapsed].
   - The View gives ZoneCenter and Period, so an exploiter can claim the exact centre time within that 0.3 s, which
     covers 0.375 of the track.
   - Impact is capped: TIP 1 BB x MAX 2 per drink, and no grade change.
   - Fix (optional): cut `LATENCY_ALLOWANCE_SECONDS` to about 0.15 or scale it by the player's measured ping. Accept as
     is if the cap stays.
2. **High-ping players are graded late.** The client's `OpenedAt` is the time it received the window, so the server's
   elapsed time is the claim plus the round trip. Above 300 ms RTT (common on mobile), the clamp pushes the graded
   position past what the player saw. Fix: as in item 1, or send the server's `StartedAt`, use
   `GetServerTimeNow()` on both sides, and clamp to RTT.
3. **The ticket patience bar is always hidden in tablet mode.** `init.luau:765` (`_makeTicket` reads `PatienceEnd`).
   The ticket is built at submit, before `StartPatience` runs at pickup, so `PatienceEnd` is nil and is never
   re-fired. OrderTicket hides the bar for the whole wait. Still at HEAD. Fix: call `_fireTicket` again from
   `_onAtPickup` with a fresh `_makeTicket`.
4. **`Rules.ValidateSubmittedOrder` trusts the shape of client input.** `Rules.luau:360/389`. Non-table elements (for
   example numbers) make `ItemsMatch` index a number and throw inside the remote. The error is noisy but harmless. Fix:
   `typeof(submitted) == "table"` guard, and cap `#submittedList`.
5. **The overhead title stops following level-ups.** `ProgressionService.luau` `_ensureTitles` / `_onLevelUp`.
   - Overheads now prefer `EquippedTitle`, which is always a string once loaded, over `LevelTitle`.
   - Existing profiles get their current highest title equipped once. Later level titles are granted but not equipped.
   - The overhead freezes at the title the player had when the update shipped, which regresses the old auto title.
   - Fix: on level-up, if the equipped title is a Level title (not Manual), move it to the new highest title.
6. **The Titles and Staff UI show a title as equipped after the player unequipped.** `Inventory/Titles.luau:168-170`
   and `Menu/Staff.luau`. Both fill `Equipped == ""` with the highest level title on the client, so an explicit
   unequip shows as "Equipped" the next time the page opens. Fix: apply that default only when `data.Titles == nil`.
7. **A weekly claim across the Monday rollover can clobber the new week.** `QuestService.luau:419-429`.
   - `GrantEarnedCapsule` runs before `SetValue`.
   - If an AdvanceQuest or GetWeeklyQuests call rolls the week over during that window, the claim writes last week's
     list back over the new one. `AssignedWeek` is already current, so the player keeps the old list for a week.
   - The window is narrow. Fix: re-read `playerData.WeeklyQuests.ActiveQuests` after the grant, and abort or refund if
     it is a different table or `AssignedWeek` changed.
8. **The weekly `BobaOrdered` quest is driven by customer pickups, not by preparing drinks.** `QuestConfig.WEEKLY_POOL`;
   `OrderService.luau:744`. The title says "Prepare N Boba Drinks", but progress only comes when *this player picks up
   an order as a customer*. At 9-40 for a week, a barista cannot realistically complete it. This semantic predates the
   commit, but the weekly x3-5 multiplier makes it much worse. Fix: drop it from `WEEKLY_POOL`, or advance it from the
   serve path.
9. **The H6 streak counts zero-star and all-walkout shifts.** `ShiftService.luau:280-291`. Walkouts count toward
   `Resolved`, so taking 10 orders and letting them walk out still advances the streak (+30 BB every 3rd). This is low
   value. Fix: require `stars >= 1` or `Served > 0`.
10. **Pickup fallback stacks NPCs.** `ClaimPickupSpot` (init.luau diff) sends overflow NPCs to `pickupNodes[1]` without
    claiming it. In a 50-NPC rush they pile up on one part. Fix: queue overflow, or offset like the line overflow does.
11. **Test changes (the 7 "greened" specs).** Only two assertions changed meaning. The rest are fixture-only (signal
    stubs, `_lastClaimAttempts` reset, `afterAll` restores) or a correctness fix (plain `string.find` in
    `_formatEntriesText`, where the old patterns treated `.` and `-` as magic).
    - `LeaderboardService.spec.luau:55-60`: **weakened (tautology).** The expected key is now built with the same
      `os.date("%Y_%m_")` the implementation uses, so it can never fail. The real bug it hid:
      `LeaderboardConfig.GetMonthKey` (`LeaderboardConfig.luau:53`) uses local time while `os.time{...}` is UTC. Prod
      servers are UTC, so there is no live impact, but Studio runs near a month boundary write to the wrong month.
      Fix: `os.date("!%Y_%m_", t)` and restore the hardcoded expectations.
    - `RecipeBookContent.spec.luau:66` "grab text stays" now asserts `"1. Fudge Brownie"`. The test no longer checks
      the pastry "Grab it from the display." instruction, which `Content.build` no longer emits. Either confirm the
      grab instruction was dropped on purpose and rename the test, or restore the line in Content.
    - ShiftService, EventService, CafeRating, DailyReward and OrderSpec: no assertion was removed or loosened. One
      note: the ShiftService streak test calls the real `_endShift`. That fires the real ShiftEnding listeners and
      `QuestService:AdvanceQuest` against fake players, and each call may wait the 10 s data timeout. This is slow,
      not wrong.

## Checked and clean
- **Pour server authority.** The server owns the window, the clock and the tier. `PerfectPours` and `PoorPours` are
  set on the server and client writes do not replicate. The tip is read synchronously before the tools are destroyed
  and adds no yield on the serve path. The walk-away limit (10 studs) matches the prompt-side check.
- **Titles ownership.** `GrantTitle` is server-only. `Client:EquipTitle` validates the type, the catalog and
  ownership, and is debounced. `Normalize` drops unknown ids.
- **Weekly and daily claims.** Per-user `questLocks`. The daily path sets `Claimed` before paying with no yield in
  between. The weekly path grants first and marks after, under the lock. The ProfileTemplate change is add-only
  (`WeeklyQuests`, `RewardCapsule?`, `InvitedFriends`). Reconcile fills existing profiles and no migration is needed.
  `Titles` is still missing from the template; it is filled on join.
- **The week index** (`GetCurrentWeek`) steps exactly once per Monday 00:00 (UTC on Roblox servers).
- **GamepassBoardController** is client-only: it prompts purchases, and grants are not trusted from the client. Every
  wait is inside `task.spawn`, so nothing blocks join. If streaming is on, a board whose parts stream out loses its
  GUI until rejoin (minor). The pass mappings remain audit Q2 for Jack.
- **Tablet order validation** runs on the server against `npc.Orders`. The client is given the answer, but submitting
  pays nothing; only a ticket is created.
- **The H6 streak bonus** is applied after `ShiftEnding` and before `Client.ShiftEnded`, so the card receives it.
