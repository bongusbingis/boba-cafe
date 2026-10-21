# T5 bubble-focus — evidence (REVIVAL-001/CLIENT-PATIENCE, task T5-BUBBLE)

- C1/C3 verified present: commit 1a4d892 is an ancestor of HEAD; `runPatienceCues`
  (C1 impatient toast + C3 rescue broadcast), `patienceFraction`, `CustomerConfig`
  require, and `CustomerConfig.RESCUE_FRACTION` in `updateServePrompts` all present.
  Only D7 was added.
- T5 rule in `runPatienceCues` (src/client/Modules/KitchenController.luau):
  `hideBubble = clockedIn and assigned ~= nil and assigned ~= LocalPlayer.UserId
  and not (fraction < CustomerConfig.RESCUE_FRACTION)`; applies
  `bubble.Enabled = not hideBubble` only when the value differs; missing bubble
  skipped silently; own pcall with warn-once `[KitchenController] Patience cues failed`.
- Station-guidance (B7) area untouched; no server edits; no new Remote/UI.
- Gate: `stylua src/client/Modules/KitchenController.luau`
  + `gate src/client/Modules/KitchenController.luau` → GATE: PASS
  (selene new=0, stylua=ok; HEAD copy was stylua-clean so stylua ran first).
- Rojo: `rojo build default.project.json -o /tmp/boba-t5-build.rbxl` → exit 0.

## Gate output (raw)

```
PASS  src/client/Modules/KitchenController.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

## Acceptance (code-mapped; runtime checks S1–S6 are Jack's batch)

- Other barista's NPC bubble hidden locally unless fraction < 0.3: `runPatienceCues`
  T5 block reuses the `fraction` from `patienceFraction` — code-verified only.
- Unassigned NPC bubbles and own bubbles stay visible: `assigned ~= nil` and
  `assigned ~= LocalPlayer.UserId` guards — code-verified only.
- Clocked-out players see every bubble: `clockedIn` guard — code-verified only.
- C1/C3 behavior unchanged: existing lines untouched — code-verified only.

## UNVERIFIED

- All runtime behavior (S5 multi-client bubble check needs Studio Start, 2 players).
