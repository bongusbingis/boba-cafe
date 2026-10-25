# REVIVAL-001 branch review (Sentry): 098175c..ee9a515

Reviewer: Sentry (read-only on src/). Scope: the 23 commits from 10c20a5 (GAMEPLAY-SERVE-QUEST-YIELD) to
ee9a515 (BIG-B1-P3-RECIPEBOOK), with the focus on how packets interact. Working tree src/ is identical to ee9a515
(checked with `git diff ee9a515 -- src`), so the file:line references below match both.

## Verdict

**PASS-WITH-FIXES.** No P1. Nothing found that blocks join or play, or adds a yield to the NPC serve path. 3 P2, 10 P3.

Gates I re-ran:
- Selene, base vs head per changed file: no new findings. New files are clean. Recipes/init.luau went from 4 to 3.
- StyLua `--check`: drift only in AppDialogs.luau, which is pre-existing and accepted.
- `rojo build default.project.json -o <scratchpad>/review.rbxl`: OK.
- TestEZ in Studio: not run (this review is read-only).

Accepted items, not repeated below: the AppDialogs StyLua drift; the Quests card has no opener (DEC-057); the
TICKET-RECIPE-LINK link half is not wired; the quest rollover race (P3, QuestService 83-103).

---

## P2

### P2-1 Shift card XP progress and level double-count the shift XP
- Where: `src/server/Modules/ProgressionService.luau:194-217`. Shown at `src/shared/UI/Components/Core/Hud/ShiftCard.luau:56-72`.
- Owner: GAMEPLAY-PROGRESS-CALLOUTS (XpIntoLevel, XpForLevel, NextUnlock). The root cause is the M2-PROGRESS prediction.
- Mechanism: `AddXp` runs `GetDataAsync(player):andThen(...)` synchronously once the profile is loaded. evaera
  promise 4.0.0 runs `Promise.new` executors with `task.spawn`, and `andThen` on a resolved promise calls the
  callback at once (init.lua:306 and :1253). So when `AddXp` returns, `state.XP` and `state.Level` already include
  `granted`. The "prediction" then does `local xp = state.XP + granted` and starts from the already-updated
  `state.Level`, which counts the shift XP twice.
- Failure scenario: the player is Level 2 with 30/40 XP after the shift XP lands (real value). The card computes
  30 + 20 = 50, so it shows "XP +N · Level up! Level 3 (10/xx)" and "Next: Level 4 · ...". At the same moment the
  new LevelBar (HUD-LEVELBAR) shows "Lv 2 30/40", and the "Level up!" toast never comes. The LevelAfter line was
  already wrong before this range, but this range adds the visible (into/for) numbers and the next-unlock line.
- Fix: snapshot `state.Level` and `state.XP` before calling `AddXp(player, shiftXp, true)` and predict from that
  snapshot plus `granted`. Simpler still: after `AddXp`, read `state.Level` and `state.XP` directly when the
  promise has settled. If `state` was nil before `AddXp`, read it after `AddXp` without adding `granted`. Add a
  spec where the profile is loaded, so the synchronous path is covered.

### P2-2 Toast queue: stale and dropped high-value toasts when several producers fire on one serve
- Where: `src/shared/UI/Components/Core/Hud/SmallNotification.luau:205-226` (drop policy) and `:254-266` (cycle).
- Owner: GAMEPLAY-TOASTS (queue policy). The producers come from SERVE-FEEDBACK, QUESTS-PING,
  GAMEPLAY-QUEST-NUDGES, GAMEPLAY-PROGRESS-CALLOUTS, SHIFT-END and CLIENT-PATIENCE.
- Mechanism: the queue keeps 1 active toast plus 3 queued. When it is full it drops `queue[1]`, the oldest
  non-hint toast. It has no priority and no dedupe. A queued toast cycles in 0.8 + 2 + 0.35 + 0.9 = about 4.05 s,
  and an unqueued one in about 7 s. Before GAMEPLAY-TOASTS, a new toast replaced the current one immediately.
- Producers on one shift-ending serve, all within about 2 s:
  1. "Order served!" (CustomerService/init.luau:848)
  2. The Team Combo broadcast to every player (init.luau:409-417, 434), or the combo milestone (849-856)
  3. Quest halfway or "Quest complete: ..." for CustomersServed (QuestService.luau:160-202)
  4. "Level up!" from serve XP and possibly again from shift XP (ProgressionService.luau:153-157)
  5. "Quest complete" for ShiftsCompleted (ShiftService.luau:278 → QuestService)
  6. "Break areas are open!" at L3 (AreaController.luau:96-99)
  7. The capsule nudge about 2.5 s later (ShiftService.luau:355)

  Other players' Team Combo lines, "Team Combo is over." and the Rush Hour lines also enter the same queue.
- Failure scenarios:
  - (a) "Level up!" or "Quest complete: ..." is the oldest queued item when the 5th toast arrives, so it is dropped
    and the player never sees it.
  - (b) Corrective, time-sensitive toasts wait behind the backlog: "Wrong drink" (init.luau:778), wrong-station
    hints (KitchenController.luau:411-416) and "Clock In to use the kitchen" (KitchenController.luau:494). The next
    serve's "Order served!" also waits, by up to about 12 s, so the feedback arrives after the player has moved on.
  - (c) Repeated identical toasts fill the queue. For example, the ClockedOut InteractionFailed toast has no cooldown.
- Fix:
  - Add a priority tier. Never drop Level up, Quest complete, Quest claimed or First order. Drop or collapse low
    tiers first: other players' Team Combo lines, "Team Combo is over." and hints.
  - Collapse "Order served!": a new one replaces a queued one.
  - Let corrective toasts (Wrong drink, wrong station, Clock In) replace the active toast instead of queueing.
  - Dedupe identical `Text` already in the queue.
- No new token or visual is needed.

### P2-3 Nickname prompt can be lost for good
- Where: `src/server/Modules/DataService/PlayerSetup.luau:36-39`, `:53-56`, `:87-119`. Timeout path:
  `src/server/Modules/DialogService.luau:66-72` and `:100-111`.
- Owner: ONBOARD-NICK. **PENDING JACK** (join/play flow, once-per-profile semantics).
- Mechanism: the hook is registered only inside the `FirstJoin == 0` branch, and `FirstJoin` is stamped on that
  same join. A nil result is treated as Skip, and DialogService resolves every pending dialog with nil after 120 s
  or when the player leaves.
- Failure scenarios. In each case the prompt copy says "This cannot be changed later", and the player never gets
  another chance:
  - (a) A new player leaves, crashes or teleports before finishing the 5-customer first shift.
  - (b) A new player never clocks in, or clocks out before the first shift ends.
  - (c) The prompt appears about 9 s into shift 2, and the player is busy serving or AFK for 120 s. The timeout
    resolves nil, which counts as Skip.

  Before this range, a timeout re-prompted. Now it skips silently.
- Fix (for Jack to choose): register the hook on any join where `Nickname == ""` and
  `Statistics.ShiftsCompleted == 0`, not only on the first join. Treat a timeout (nil) differently from an explicit
  Skip (""): keep the hook for the next ShiftEnding, as the `gaveUp` path already does. Neither change needs a new
  profile field.

---

## P3

1. **The ShiftsCompleted quest advance still yields inside `_endShift`.** `ShiftService.luau:277-279`. Owner:
   GAMEPLAY-SERVE-QUEST-YIELD (missed call site) or SHIFT-END.
   - `AdvanceQuest` awaits `GetDataAsync`. On a day rollover it also calls `_hasPass`, which is a network lookup.
     This happens before `ShiftCardOpen` is set and before `Client.ShiftEnded:Fire`.
   - It does not block the NPC serve, because it runs on a separate GoodSignal handler thread. It does delay the
     card. The nickname listener's 8 s timer has already started at ShiftEnding, so on a slow lookup the prompt can
     open while the card is still opening.
   - Fix: `task.spawn` it, as the serve path does.
2. **Quest copy and the claim dot point at UI that is no longer mounted.** `QuestService.luau:170-172` says "Open
   Quests to claim." The QUESTS-PING claim dot lives in `BottomRight.luau:45-89/126-141`, and BottomRight is no
   longer mounted (`Hud/init.luau:70`).
   - The missing opener is an accepted item (DEC-057). The new copy and the dead dot are its consequence.
   - Fix: reword the toast or restore an opener when Jack decides. Remove or re-home the dot together with the opener.
   - Owner: GAMEPLAY-QUEST-NUDGES, QUESTS-PING.
3. **The ticket column grows upward with no height cap.** `Hud/init.luau:73-80`, `OrderTicket.luau:355-360`. Owner:
   DEC-057 change and GAMEPLAY-MOBILE-TICKET.
   - The column's bottom edge is fixed at 0.65 of the screen, and phones now auto-expand both tickets on a new
     order. Two expanded tickets at TICKET_SCALE 1.6 can reach the ShiftCard area (0.99, 0.14 top-right; both use
     ZIndex 10). A new ticket usually arrives during the 8 s card window, because the next shift starts at once.
     On short viewports the column can clip off the top of the screen.
   - Needs a Studio check at the phone and 1280x720 presets.
   - Fix: cap the column height (UISizeConstraint, or collapse ticket 2 while it would overflow), or keep tickets
     collapsed while `ShiftCardOpen`.
4. **ShiftCard rows have no cap; the layout only fits by arithmetic.** `ShiftCard.luau:34-75, 113-128`.
   - The current maximum is 6 rows: 6 × 0.12 + 5 × 0.02 = 0.82 of the Container, which fits. One more row (for
     example an ENGAGE-SHIFT-STREAK line) makes 0.96. Eight rows overflow the Border, because there is no clipping.
   - "Next shift starts now" is now effectively dead: `NextUnlock` is non-nil until the max level, so the First
     card never shows it.
   - Fix: size rows from `#lines`, or merge lines. Decide whether the "Next shift" copy should stay.
   - Owner: SHIFT-END, GAMEPLAY-PROGRESS-CALLOUTS.
5. **The capsule nudge can land while the nickname prompt is still open.** `ShiftService.luau:333-338`. It waits at
   most 45 s on `NicknamePending`, and the prompt opens at about 9 s. A player who takes more than about 36 s gets
   the toast under the dialog. It is harmless (non-blocking). Owner: SHIFT-END.
6. **The ShiftEnding connection leaks.** `PlayerSetup.luau:91` is never disconnected when a new player leaves before
   the first shift ends. The closure holds `player` and `proxy`. It is bounded to new players.
   - Fix: in the handler, disconnect when `player.Parent == nil`, or disconnect on PlayerRemoving.
   - Owner: ONBOARD-NICK.
7. **The last serve's XP may count toward the next shift (pre-existing, made more visible).** ShiftService
   (`ShiftService.luau:453`) and ProgressionService (`ProgressionService.luau:168`) both handle CustomerResolved, in
   GoodSignal or Knit start order.
   - If ShiftService runs first, the shift-ending serve's XP goes into the next shift's `_shiftXp`. The card's
     "XP +N" then misses it, and the next card includes it.
   - Fix: add the shift's serve XP from ShiftService's own result, or have ProgressionService handle the serve
     before ShiftEnding.
   - Owner: M2-PROGRESS or SHIFT-END (low).
8. **The Daily auto-open waits for a first serve forever.** `DailyRewardController.luau:37-56`. A returning profile
   with `CustomersServed == 0` (players who only roleplay) never gets the automatic Daily dialog. The
   `ListenToChange` connection is also never released.
   - Confirm with Jack whether non-baristas should still get the auto-open.
   - Owner: ONBOARD-FIRSTRUN.
9. **Latent Recipe Book focus bug.** `Recipes/Content.luau:66-68` focuses by `orderItem.Item`. Classic, Taro and
   Strawberry are all "Custom Boba", so once the TICKET-RECIPE-LINK focus is wired, all three blocks will be
   focused together.
   - Fix: focus by `entry.Key`, or by Item plus Syrup Flavor.
   - Owner: BIG-B1-P3-RECIPEBOOK or TICKET-RECIPE-LINK.
10. **The Boba Bucks pill counts up from 0 on every join or remount.** `BottomLeft.luau:75-103`. The initial
    currency state is 0, so the first data load runs the pop and count-up from 0 to the balance. It is cosmetic.
    Fix: skip the animation when `prev` is the placeholder 0 before the first load. Owner: HUD-BOTTOMLEFT.

---

## Checked and OK (no finding)
- **Serve path.** The quest advance is spawned. The combo toast is deferred, and the first-order toast uses
  defer + 0.2 s. The Team Combo broadcast is deferred. RealOrder's `RecordCustomer` is deferred. No new yield
  before `CustomerResolved`.
- **Combo and Team toasts.** The milestone toast is suppressed when a Team Combo completes on the same serve and on
  the first serve. "Team N/10" disappears correctly when the chain resets. The next-bonus math matches
  `Rules.Payout`.
- **`_firstServe`.** Multi-assign while `served == 0` is correct: it is cleared on the first serve and on
  PlayerRemoving.
- **Nickname flow.** It cannot double-show: it disconnects before prompting, and the invalid-retry loop is
  unchanged. ShiftEnding sets `NicknamePending` synchronously, before `_capsuleNudge` is spawned. ShiftCardOpen
  timing: the listener's 8 s delay is queued before the attribute's clear, so the prompt opens at about 9 s, after
  the card.
- **RealOrder shift result.** Pay/Tips accounting: AddTip adds the tip to Pay and Tips, and RecordCustomer adds
  pay − tip. The card's Pay − Tips gives the base pay, so it is consistent.
- **Personal bests.** The first-ever shift cannot show "new best". `_writeBests` only raises values.
  `PrevBest*` carries into `nextState`.
- **Sounds.** The level-up sound has a single owner (LevelBar). The "Level up!" toast is silent. UiSfx skips
  missing sounds with one warning. Clones are cleaned up by Ended and by Debris.
- **CafeRating RushEndsAt.** It is set and cleared on every rush, party start, extend and end path, and published
  before `_notifyAll`.
- **Recipe pool.** Taro and Strawberry stations were verified in source by BIG-B1-P1-AUDIT. `_sameOrder` compares
  Syrup Flavor, so the no-repeat rule still works with three "Custom Boba" entries. `NewDrinksAt` and `unlocksAt`
  read pool Labels. The CustomerConfig → Progression require has no cycle.
- **LevelBar.** It sits in CurrencyPanel at LayoutOrder −1. The toast is at −6, so it stays above and the bar does
  not jump. Hook order is stable per environment.
- **NPC reactions.** The Karen Close stomp and the "Leaving" line are kept. Karen Perfect waves and uses
  `Karen.LeavingServed`. Confused plays once per NPC at yellow.
- **ServeJuice.** `WaitForChild("Customers", 30)` warns and continues. It is purely cosmetic and every callback is
  wrapped in pcall.
