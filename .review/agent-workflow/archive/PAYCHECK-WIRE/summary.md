# PAYCHECK-WIRE — paycheck firing + receiving architecture

## Result
PASS (implemented, gate PASS, Studio/TestEZ verification owed to Jack).

## What existed
`ShiftService._endShift` built the shift `summary` and fired `ShiftEnded`
(rendered by `ShiftCard`) plus the internal `ShiftEnding`. No dedicated
paycheck payload or receiver. `FirstPaycheck` badge defined, never awarded.

## What changed (this lane only)
- `src/server/Modules/ShiftService.luau` — new `Client.Paycheck`
  `Knit.CreateSignal`, fired in `_endShift` right after `ShiftEnded` with
  the receipt-only paycheck (`Pay`, `Tips`, `Bonus`, `Total`,
  `StreakBonus`, `Stars`, `Served`, `Walkouts`, `Shift`, `First`).
  Display-only: base/tips moved at serve time, star/streak bonus just above.
- `src/shared/UI/Components/Core/Hud/PaycheckCard.luau` (new) —
  always-mounted receiver: subscribes to `Paycheck`, queues payloads,
  centred `Page` pop (GREEN header, GOLD `PAYCHECK` banner, art slot, pay
  lines, GREEN `Collect`, 8 s auto-dismiss). Unconditional hooks only
  (the LVLUP-POPUP crash class). Silent; `ShiftCard` keeps its jingle.
  `PaycheckArt()` is the single marked wire-in point for Jack's UI/image.
- `src/shared/UI/Components/Core/Hud/init.luau` — mounts it (ZIndex 20).
- `src/shared/UI/Stories/PaycheckCard.story.luau` (new) — preview payload.
- `src/server/Tests/ShiftService.spec.luau` — `Paycheck` fake in the spec
  harness + "Paycheck receipt" test: one fire per `_endShift`, pay lines
  and `Total == Pay + Tips + Bonus`, shift count, `First == false`.
- `docs/SYSTEMS.md` — M2-SHIFT row documents the signal, payload, card,
  and art slot.

## Checks observed
- `gate` on all 5 Luau files: `GATE: PASS` (2026-10-21, selene new=0,
  stylua ok, rojo build PASS).
- No other working-tree files touched by this lane (verified by file list).

## PORT 2026-10-21: original check art wired in
Jack supplied the original game's check tree + handler. Ported into
`PaycheckArt()`: same check image (`rbxassetid://15045483052`), same
fractional overlay positions, same green block, same Accanthis font refs.
Field mapping: Player = LocalPlayer.Name ("Barista" fallback in stories),
Date = today, Amount = shift Total, AmountString = "{Total} Boba Bucks",
Reason = "First shift complete!" or "Shift N complete". Dropped from the
old handler: fly-in/out tween (Page pop replaces it), screen darken, and
tap-anywhere-to-dismiss (all three would block input behind the card;
Collect/X/8 s dismiss instead). Re-gated clean (single file + rojo build).
Flag: AccanthisADFStd.json is outside `Styles.luau` (faithful port of
Jack's own art); if it does not resolve, labels fall back to the default
font — one-line swap to Fredoka if Jack prefers. Check image loads from
the public asset id; confirm visually in the story.
Fix 2026-10-21: card bodies were fully transparent (`Pane` defaults
`BackgroundTransparency` to 1; the fill was set without overriding it),
so only the header bar and button rendered solid. Set `BackgroundTransparency
= 0` on both card shells; re-gated clean.
Redesign 2026-10-21 (Jack: old UI is a LITERAL paycheck): dropped the
generic card shell (header, breakdown rows, Collect) — the popup is now
just the check at 0.55 x 0.22 with a CloseButton on its corner, X / 8 s to
dismiss, breakdown left on ShiftCard. Re-gated clean.
Fix 2026-10-21 (too small, X mid-right): check is now 0.7 x 0.28, and the
CloseHolder anchors at the X's own center (derived from CloseButton's
fixed fractions) so it sits 20 px inside the top-right corner. Re-gated.

## NOT RUN (Jack, jacks project)
- Quick receiver test (Play server command bar):
  `Knit.GetService("ShiftService").Client.Paycheck:Fire(player, { Pay = 42, Tips = 8, Bonus = 10, Total = 60, Stars = 3, Served = 10, Walkouts = 0, Shift = 4, First = false })`
  → centred PAYCHECK card, silent, dismisses via Collect/X/8 s.
- Full path: clock in, serve a full shift → card fires from `_endShift`.
- Story render + TestEZ suite (`TESTS_ENABLED = true`, revert after).
- Open: award `FirstPaycheck` badge on first payout (badge id exists,
  never awarded); needs Jack's call.
