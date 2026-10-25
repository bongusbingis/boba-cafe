# M2-SHIFT: count-based shifts and the end-of-shift card
Model: sonnet   Studio: no   Depends on: M1.4e, M1.5b (done first; both edit CustomerService/init.luau and Hud)   Size: M

## Goal
A clocked-in barista works shifts of 10 resolved customers (5 for the very first shift), sees "Shift k/N", and gets a non-blocking card at the end that disappears by itself. Settled by DEC-011 (Q11), design §5.1-§5.2.

## Read (only these)
- `M1.2/design.md` lines 292-304 (§5.1-§5.2)
- `src/server/Modules/ShiftService.luau` (whole; ~110 lines)
- `src/server/Modules/CustomerService/init.luau`: grep `_onServeTriggered`, `_onCustomerLeft`, `_clearTicket`; read only those three functions
- `src/shared/Configuration/ProfileTemplate.luau` lines 94-106 (Statistics)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` lines 60-110 and 306-345 (shift timer button, its state)
- `src/shared/UI/Components/Core/Hud/OrderQueue.luau` lines 40-165 (the HUD model to copy)
- `src/shared/UI/Components/Core/Hud/init.luau` (whole)
- `docs/STYLE.md` sections 3.6, 4.3 (lines 404-414, 473-482)

## Write scope
- `src/server/Modules/ShiftService.luau`
- `src/server/Modules/CustomerService/init.luau` (only: add signal `CustomerResolved`, fire it; nothing else)
- `src/shared/Configuration/ProfileTemplate.luau` (add `ShiftsCompleted = 0` to `Statistics` and its type, nothing else)
- `src/shared/Configuration/ShiftConfig.luau` (new)
- `src/shared/UI/Components/Core/Hud/ShiftCard.luau` (new)
- `src/shared/UI/Components/Core/Hud/init.luau` (mount ShiftCard only)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (only the shift-timer button: text and visibility)
- `src/server/Tests/ShiftService.spec.luau` (new; star rule only)

## Steps
1. **ShiftConfig.luau.** `SHIFT_SIZE = 10`, `FIRST_SHIFT_SIZE = 5` (Q11), `CARD_SECONDS_FIRST = 8`, `CARD_SECONDS_LATER = 6` (design §5.2), `SHIFT_BONUS_PER_STAR = 0 -- PROPOSED (Jack)` (real value set at the M3 gate), `SHIFT_XP = 10` and `SHIFT_XP_PER_STAR = 5` (design §5.4; each `-- PROPOSED (Jack)`).
2. **Stat.** ProfileTemplate `Statistics.ShiftsCompleted = 0` (its type too). The first-ever shift is the one where this is 0.
3. **CustomerService signal.** Add `CustomerResolved = GoodSignal.new()` next to `CustomerLeft`. Fire `(player, result)` once per resolved customer for the assigned barista, with `result = { Kind = "Served" | "Walkout", Grade = "Perfect" | "Close"?, Pay = number, Fast = boolean, Combo = number }`. Fire it at the end of the Perfect/Close branch of `_onServeTriggered` and in `_onCustomerLeft` when reason is `"PatienceOut"` (use the player held in the ticket; no player means no fire). Wrap in `pcall`.
4. **ShiftService state (session only).** Per clocked-in player keep `{ Resolved, Target, Served, Walkouts, Perfects, Pay, BestCombo }`. Target = `FIRST_SHIFT_SIZE` when the profile's `Statistics.ShiftsCompleted == 0` (read it the way `CustomerService:_readServedCount` reads CustomersServed), else `SHIFT_SIZE`. Create state on `SetClockedIn(true)`; clocking out discards it (shift is paused, nothing banked; pay is already banked per serve). Set player attributes `ShiftCount` (Resolved) and `ShiftTarget` after every change so the client reads them.
5. **RecordCustomer.** `ShiftService:RecordCustomer(player, result)` updates the state, then if `Resolved >= Target` and the player has no open ticket (`CustomerService` has no ticket for the player; check through `CustomerService:HasTicket(player)`, add that one-line method in init.luau if it does not exist) calls `_endShift`. If a ticket is open, end the shift when the ticket clears: connect to `CustomerResolved` (it fires on every clear) and re-check. Subscribe in `KnitStart`: `CustomerService.CustomerResolved:Connect(function(p, r) self:RecordCustomer(p, r) end)`.
6. **_endShift.** Stars: 3 = zero walkouts and Perfects/Served >= 0.8; 2 = at most 1 walkout and >= 0.5; else 1 (§5.2; `Served` counts Perfect and Close). Build `summary = { Shift = n, Stars, Served, Walkouts, Pay, Tips = 0, Bonus = stars * SHIFT_BONUS_PER_STAR, BestCombo, First = (ShiftsCompleted == 0), Seconds = CARD_SECONDS_FIRST or LATER }`. Fire a new server signal `ShiftService.ShiftEnding = GoodSignal.new()` with `(player, summary)` BEFORE sending, so ProgressionService can add `summary.Xp`, `summary.LevelBefore`, `summary.LevelAfter`. Then pay `Bonus` through `CurrencyService:Modify(player, "BobaBucks", Bonus)` only when Bonus > 0, `StatisticsService:IncrementStat(player, "ShiftsCompleted")`, `self.Client.ShiftEnded:Fire(player, summary)`, and reset the state for a new shift (Target = `SHIFT_SIZE`). The next shift starts by itself. Put the pure star rule in a function `ShiftService.StarsFor(served, perfects, walkouts)` and spec it (3 cases per star level).
7. **Client signal.** In `ShiftService.Client` add `ShiftEnded = Knit.CreateSignal()` (declare it the way `OrderService` declares `NotepadUpdated`).
8. **ShiftCard.luau (UI; follow STYLE.md exactly, DEC-013).** Copy the HUD recipe in STYLE 4.3 and the layout of `OrderQueue.luau` lines 75-165: 9-slice panel + border + `Banner` title ("Shift Complete"), `Styles` tokens only, `Styles.FONT_FREDOKA`. Rows as text lines in `OFFWHITE`: stars as text `★` x n, "Customers served: n", "Pay: n  Bonus: n", "Best combo: x n"; if `summary.Xp` is non-nil add "XP: +n" and, when `LevelAfter > LevelBefore`, "Level up! Level n". Anchor in a free HUD zone per STYLE 2.4 (STOP-AND-ASK if none is free). It never blocks input (no overlay, no `Active`, no buttons) and removes itself after `summary.Seconds`. First shift: add one line "Next shift starts now" (no button). Subscribe to `Knit.GetService("ShiftService").ShiftEnded` inside `React.useEffect` guarded by `RunService:IsRunning()`; disconnect in cleanup. Mount it in `Hud/init.luau`.
9. **Shift readout.** In `BottomLeft.luau`, the shift-timer `NormalButton` currently shows `"00:00"` for admins only. Make it visible to every clocked-in player, text `Shift k/N` from the player attributes `ShiftCount` / `ShiftTarget` (listen with `GetAttributeChangedSignal`). Keep its colour (`ROSE_MID`) and layout order. Hide it when clocked out. Do not touch any other button.
10. `stylua` then `gate` on all changed files.

## Done when
- A shift ends at 10 resolved customers (5 when `ShiftsCompleted == 0`) and never while the player has an open ticket.
- The card shows, never blocks input, and clears itself after 6 s (8 s on the first shift).
- `Shift k/N` shows for any clocked-in player.
- The star-rule spec exists.
- The gate passes on all changed files.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN (Jack tests: serve 5 customers on a fresh profile, see the card; serve 10 more, see the compact card).

## STOP-AND-ASK
- No free HUD zone for the card (STYLE 2.4): ask Jack where it sits.
- Tips and shift bonus values are placeholders (0); the real values come at the M3 gate. Do not invent them.

## Evidence
`tasks/REVIVAL-001/M2-SHIFT/evidence.md` (RUNBOOK step 5). Include the final `summary` table shape (PROGRESS depends on it).
