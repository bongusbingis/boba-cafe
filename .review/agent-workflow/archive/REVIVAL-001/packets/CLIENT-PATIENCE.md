---
id: CLIENT-PATIENCE
title: Client patience cues - impatient toast, rescue broadcast, bubble focus
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [GAMEPLAY-TOASTS]
status: READY
source_commit: 098175c
read_scope:
  - src/client/Modules/KitchenController.luau (updateServePrompts, toast, isClockedOut, resolveServeTarget)
  - src/shared/Configuration/CustomerConfig.luau (RESCUE_MULT, RESCUE_FRACTION, PATIENCE_RED_FRACTION)
  - src/server/Modules/CustomerService/Npc.luau (Model attributes State, AssignedUserId, PatienceEnd, PatienceTotal; buildBubble "OrderBubble")
  - src/client/Modules/AppDialogs.luau (DialogController:Toast)
write_scope:
  - src/client/Modules/KitchenController.luau (updateServePrompts and new locals above it; one new require)
invariants:
  - client-only; no server file touched; no serve-path code (the serve-path no-yield rule is not in play)
  - the server stays the authority for Serve/Rescue (Rules.CanServe); this packet only changes what the player sees
  - DEC-013: no new UI; toasts are plain text through DialogController:Toast
  - a failure here must never break the 0.2 s prompt loop (KnitStart already wraps updateServePrompts in pcall)
acceptance:
  - own customer reaching <= 25% shows "Your customer is getting impatient!" exactly once per NPC
  - another barista's customer becoming rescuable within 40 studs shows the rescue toast, at most once per 20 s
  - OrderBubble of an NPC assigned to someone else is hidden locally unless fraction < 0.3
  - unassigned NPC bubbles and own bubbles stay visible; clocked-out players see every bubble
checks:
  - wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/client/Modules/KitchenController.luau' (run stylua first only if stylua --check passes on the HEAD copy)
  - rojo build default.project.json -o <path outside the repo>
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/CLIENT-PATIENCE
forbidden: [see WORKER-PRIMER 8, any server edit, any new Remote, any edit to the station-guidance code in KitchenController (BIG-B7 area)]
---

Read [WORKER-PRIMER](_meta/WORKER-PRIMER.md) first. Anchor edits by symbol, not line.

## 1. Source excerpt
- C1: About-to-leave warning: when your own customer drops to red (<= 25%), one toast "Your customer is getting impatient!" (once per NPC). Why: urgency right when it matters; prevents surprise walkouts. Files: client (OrderTicket's patience effect) or KitchenController. Effort XS, Risk Low.
- C3: Rescue broadcast: when an unassigned or other barista's NPC becomes rescuable, clocked-in baristas within 40 studs get "A customer needs help! Rescue for 1.5x pay" (throttled to once per 20 s). Why: turns Rescue into a visible co-op moment; teaches the mechanic. Files: client. Effort S, Risk Low.
- T5: Bubble focus: on the client, hide OrderBubble for NPCs assigned to other baristas unless they can be rescued (fraction < 0.3). Why: at 20+ players, 16 always-on-top bubbles are a wall; rescue opportunities pop out. Files: client (KitchenController.updateServePrompts already computes this). Effort S, Risk Med (multi-client check).

## 2. Decisions made
- D1: Everything lives in `KitchenController.luau` inside the existing 0.2 s `updateServePrompts` loop. Why: it already walks `workspace.Customers` and computes `fraction`; no new connection.
- D2: Replicated inputs are Model attributes on each `workspace.Customers` child, all set by `Npc.luau`: `State` (string, "AtCounter" while waiting at the counter), `AssignedUserId` (number or nil), `PatienceEnd` (server time, set only once assigned), `PatienceTotal` (number). Unassigned NPCs have no `PatienceEnd`, so `fraction = 1` (existing behaviour) and they are never rescuable. Why: this is exactly what the current code reads. The local player's `ClockedIn` Player attribute (ShiftService) is read through the existing `isClockedOut()`.
- D3: Thresholds come from `CustomerConfig`: red = `PATIENCE_RED_FRACTION` (0.25), rescue = `RESCUE_FRACTION` (0.3), multiplier = `RESCUE_MULT` (1.5). The hard-coded `0.3` in `updateServePrompts` is replaced by `CustomerConfig.RESCUE_FRACTION` (same value). Why: one source of truth, the server uses the same keys.
- D4: C1 fires when ALL hold: `AssignedUserId == LocalPlayer.UserId`, `State == "AtCounter"`, `fraction <= PATIENCE_RED_FRACTION`, `fraction > 0`, and the ticket is not scripted. Scripted check: if `resolveServeTarget() == model` and `Knit.GetController("OrderController").CurrentOrder.Scripted == true`, skip. "Once per NPC" = weak-keyed table `impatientToasted[model] = true`. Why: no false alarm for the tutorial NPC (it never leaves); a Model is collected when the NPC leaves.
- D5: C3 fires on the transition not-rescuable to rescuable, tracked per model in weak-keyed `wasRescuable[model]`. Rescuable for C3 = clocked in, `State == "AtCounter"`, `AssignedUserId ~= nil`, `AssignedUserId ~= LocalPlayer.UserId`, `0 < fraction < RESCUE_FRACTION`, and the local character's `HumanoidRootPart` within `RESCUE_BROADCAST_STUDS` of the NPC's `HumanoidRootPart`. One module-level `lastRescueToastAt` (os.clock) throttles to one toast per `RESCUE_TOAST_COOLDOWN_SECONDS` across all NPCs; a transition suppressed by the throttle is not retried (the flag still flips). Why: unassigned NPCs cannot be rescued; the toast is a one-shot nudge, not a stream.
- D6: Walking into range of an NPC that is already rescuable also fires the toast (the transition is on the rescuable-and-in-range flag, not on a server event). Why: late arrivals are the people who can help.
- D7: T5 rule per model each tick: `hideBubble = clockedIn and AssignedUserId ~= nil and AssignedUserId ~= LocalPlayer.UserId and not (fraction < RESCUE_FRACTION)`. Apply `bubble.Enabled = not hideBubble` where `bubble = model:FindFirstChild("OrderBubble")`, only when the value differs. The "Speech" label is a child of the same BillboardGui and hides with it. Why: clocked-out players are not working a ticket and keep full information; if `Npc` destroys and rebuilds the bubble it is corrected within 0.2 s.
- D8: Toasts use the existing `toast(text)` helper in the file (calls `DialogController:Toast`, which pushes `SmallNotification`, queued by GAMEPLAY-TOASTS). No sound. Why: sounds are Jack's (DEC-054); the queue stops these toasts erasing serve toasts.
- D9: The new logic runs in its own `pcall` per tick inside `updateServePrompts`, after the existing prompt code; on error it warns once (module boolean `patienceCuesWarned`). Why: a bug must not stop the Serve/Rescue prompt updates.

## 3. Exact strings
- C1: `Your customer is getting impatient!`
- C3: built as `` `A customer needs help! Rescue for {CustomerConfig.RESCUE_MULT}x pay` `` which renders `A customer needs help! Rescue for 1.5x pay`.
- Warn: `[KitchenController] Patience cues failed: <err>` (once).

## 4. Exact numbers
- `RESCUE_BROADCAST_STUDS = 40`
- `RESCUE_TOAST_COOLDOWN_SECONDS = 20`
- From config: red 0.25, rescue 0.3, multiplier 1.5.

## 5. Signatures and names
- New require beside the others: `local CustomerConfig = require(Shared.Configuration.CustomerConfig)`.
- `local function patienceFraction(model: Model): number` (extracts the existing `PatienceEnd`/`PatienceTotal` math; returns 1 when unassigned).
- `local function runPatienceCues(model: Model, root: BasePart, fraction: number, clockedIn: boolean)` called from the `updateServePrompts` model loop (inside the `if prompt and prompt:IsA("ProximityPrompt")` branch, after the existing Serve/Rescue/disabled block); handles C1, C3, T5.
- Weak tables: `setmetatable({}, { __mode = "k" })` for `impatientToasted` and `wasRescuable`.
- No new remote, attribute or profile field.

## 6. UI spec
No new UI. Toasts only (text via the GAMEPLAY-TOASTS queue). Bubble visibility only through `BillboardGui.Enabled`, a local property that never replicates to the server.

## 7. Studio checks (Prime batches for Jack; need two clients, Studio Start with 2 players)
- S1: Client A takes an order and lets the customer drain to the red bar. Expect one toast "Your customer is getting impatient!" at the red threshold, never again for that NPC.
- S2: Same during the first-session script (scripted NPC). Expect no impatient toast.
- S3: Client A holds a ticket and waits; Client B (clocked in, within 40 studs) sees "A customer needs help! Rescue for 1.5x pay" once when it drops below 30%. A second NPC below 30% within 20 s gives no second toast; after 20 s a new one is allowed.
- S4: Client B 60 studs away sees no rescue toast; walking into range while the NPC is still below 30% shows it.
- S5 (T5 multi-client check): Client B sees only its own and unassigned bubbles; A's bubble is hidden on B until A's customer is below 30%, then it appears on B. Client A still sees its own bubble. A clocked-out client sees all bubbles.
- S6: B uses Rescue on the shown NPC: prompt reads "Rescue", payout is 1.5x as before (no behaviour change).

## 8. Asset prerequisites
None. Reads `workspace.Customers` models, their `HumanoidRootPart` and the `OrderBubble` BillboardGui (built by `Npc.luau`). A missing bubble or root: skip that NPC silently.

## 9. Open items: none

## Summary
- C1, C3 and T5 added to `KitchenController.updateServePrompts` through one helper `runPatienceCues`; client-only.
- Thresholds read from `CustomerConfig` (0.25 red, 0.3 rescue, 1.5x); 40 studs and 20 s are packet constants.
- Attributes used: Model `State`, `AssignedUserId`, `PatienceEnd`, `PatienceTotal`; Player `ClockedIn`.
- Scripted first-session NPC excluded from C1 via `CurrentOrder.Scripted`.
- Needs GAMEPLAY-TOASTS landed so toasts queue; BIG-B7 follows on the same file.
- Studio checks S1-S6 need two clients.
