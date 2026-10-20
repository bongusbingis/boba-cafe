# GAMEPLAY-TOASTS: every toast shows its message; toasts queue instead of erasing each other
Model: sonnet (Mason, Studio: no)   Depends on: GAMEPLAY-REVIEW items N1-N3 (OBVIOUS)   Size: S

## Goal
- **Blank toasts are fixed.** `SmallNotification` renders only `notification.Text` (`SmallNotification.luau:238`). Callers that send `{ Title, Description }` with no `Text` produce an empty card: the serve toast (`CustomerService/init.luau:830`), Wrong drink (`:769`), Customer rescued (`:837`), Customer left (`:954`), Trash (`TrashService.luau:42`), the spill refusal (`Spill.luau:245`), promo redeem (`PromoCodes.server.luau:172`), Order Placed/Failed (`Pages/Ordering/init.luau:321`). STYLE 9.8 records this.
- **Bursts no longer erase the important toast.** A serve, a level-up, a Team Combo and a quest toast can arrive within seconds; today each push replaces the current card.
- **Legacy hints never overwrite gameplay feedback.**
- Same panel, springs, sizes, font and colours. No new visual.

## Verified facts
- `module.Push(notification)` fires a module-level BindableEvent (`:76-78`). The component keeps one `activeEntry`; a push sets a new entry, which cancels the running animation thread (`:116-127`, `:129-179`).
- Timings: open (spring) then `task.wait(0.8)`, fade in, hold `HOLD_DURATION` 5 s, fade out, wait 0.35 s, close, wait 0.9 s, then clear if still active.
- Hints: a loop posts one of `HINTS` every 60 s through the same event (`:99-113`).
- Every server toast arrives through `AppDialogs.luau:269-271` (`SmallNotification.Push(notification)`), and client toasts through `DialogController:Notify` (`:239-241`) and `:Toast(text)` (`:247-249`). Normalising inside `Push` (or at the top of the listener) covers all of them.
- Precedent for joined text: `EventService.luau:90` and `TreasureHuntService.luau:111` send `Text = title .. ": " .. message`.

## Write scope
- `src/shared/UI/Components/Core/Hud/SmallNotification.luau` only.
- `docs/STYLE.md` section 4.4 (behaviour sentence: "a new push replaces the current one immediately" becomes the queue rule) and 9.8 (payload mismatch: now normalised). Text only.
Not touched: any server file, `AppDialogs.luau`, any caller, `HINTS` text (copy cleanup is a separate JACK question, Q-G9), `Styles.luau`, `Pane`.

## Steps
1. **Text fallback** (in `Push`, before firing): if `typeof(notification.Text) ~= "string"` or it is empty, build it: with both `Title` and `Description` as non-empty strings, use `Title .. sep .. Description`, where `sep` is `" "` when `Title` ends in `!`, `?`, `.` or `:`, else `": "`. With only one of them, use that one. With neither, do not push (warn once: `[SmallNotification] toast with no text`). Copy the table; never mutate the caller's table.
2. **Queue:** keep a `queueRef` (array) next to `activeEntry`. On push: if nothing is active, show it now; otherwise append. Cap the queue at 3. When full, drop the oldest *hint* first, else the oldest entry. Mark hint pushes with an internal field (for example the loop pushes `{ Text = hint, _hint = true }`).
3. **Busy hold:** when the animation reaches the hold, use `HOLD_DURATION` (5 s) if the queue is empty, else `HOLD_BUSY = 2` s. When an entry finishes (the existing "clear if still active" step), pop the next queued entry instead of setting nil. Keep `from = { SizeY = 0, Opacity = 1 }` so each card replays cleanly.
4. **Hint courtesy:** the hint loop skips its turn (continues to the next 60 s wait) when a toast is active, the queue is not empty, or a non-hint toast started less than 20 s ago (`lastGameplayAt` ref, set on every non-hint push).
5. Keep all existing springs and constants. Add only `HOLD_BUSY` and `HINT_QUIET_SECONDS = 20` as TUNING constants in the constants block.
6. Update the story if `Stories/` has one for SmallNotification (grep `SmallNotification` in `src/shared/UI/Stories`); otherwise none.
7. Gate and `rojo build`.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio, no saves, do not commit.
- Serve-path invariant: nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout. This lane is client-only and touches no server file.
- Studio-authored content (`workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`) is not in the Rojo tree and is not edited. No sound is added (`SoundEnabled` stays unused).
- DEC-013 / STYLE section 0: existing tokens, components and motion only. No new colour, font, radius, asset, spring, or panel. No literal `Color3.fromRGB` beyond what the file already has.
- No economy change; no toast text is hand-written by this lane except the warn message.
- Gate on every changed Luau file (stylua only if the file has no DEC-001 drift; otherwise gate alone with no new findings): `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`, plus `rojo build default.project.json -o <path outside the repo>`.

## Done when
- Every caller listed above would render a non-empty label (show the computed `Text` for each in evidence by reading the payloads).
- Three pushes in one frame show in order with 2 s holds; a single push still holds 5 s; hints never interrupt.
- STYLE 4.4/9.8 updated; gate shows no new findings; `rojo build` succeeds.
- Evidence in `tasks/REVIVAL-001/GAMEPLAY-TOASTS/evidence.md`.

## STOP-AND-ASK
- If a caller depends on replace-immediately behaviour (grep `Push(` and `:Notify(` for any "cancel" intent): stop and report.
- If fixing requires touching `AppDialogs` or a server file: stop (out of scope).

## Test for Jack (Play, his Studio)
- Serve an NPC: the toast reads "Order served! +N · Perfect · Fast" (plus Combo from the 2nd Perfect in a row).
- Hand a wrong drink: the toast shows the reason (for example a wrong size).
- Let a customer walk out: "Customer left: Customer left. Combo lost."
- Level up right after a serve: both toasts show, one after the other.
- Stand idle 2-3 min: hints still appear, never on top of a gameplay toast.
- Phone emulator: the toast still sits bottom-left and does not block the thumbstick (report what you see).
