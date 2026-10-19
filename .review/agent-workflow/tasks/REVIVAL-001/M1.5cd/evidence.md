RESULT: PASS
Scope of PASS: static gate and pure-logic tests only. All runtime behaviour is UNVERIFIED (no Studio).
Task: REVIVAL-001-M1.5cd (Mason). Base commit: cbf5271 (branch uhweifh).

## Changed files (sha256)
- 4b39772f5825cdc665d8276cea1bc75141c08768b0f9d0ec828e2a599c168a5e  src/client/Modules/KitchenGuidance.luau
- 8f5f7012716d10ad12c19d8d08a3ef404daf19e3efdd449fde75d0cf83eb7b77  src/server/Tests/KitchenGuidance.spec.luau
- bfaa0484d513b99c496758e9b08d4c010fe979b2d605c648ec6c1db9b3c62279  src/client/Modules/KitchenController.luau
- 2e6bc219a218e73c0283e84e7fca83652258bdd2256ba0c78e7872e7520ede0c  src/client/Modules/AppDialogs.luau
- ac7c64f4dfd4acab8f7ccdfec33d265033580f481960eafff16340ed9d68c280  src/shared/Configuration/SettingsConfig.luau
- dbf7290e025f431ad8312c6638f46b95f9b73d0d6303a2841c4a536b04fcd2d7  src/server/Modules/KitchenService/init.luau

New files: KitchenGuidance.luau (pure logic, client Modules; not a controller) and its spec, as allowed by the lease.

## What changed
- SettingsConfig: SyrupHighlighting label "Station hints", no MinRank; ShiftTimerEnabled no MinRank; unused MIN_STAFF_RANK removed. The MinRank field stays in the Setting type because SettingsService and Settings.luau still read it.
- KitchenController: guidance runtime (0.2 s poll, pcall-wrapped, disables itself after 5 errors). Index of Models under workspace.Assets.Kitchen by name; nearest Model to the character for Steps[current].Station gets one Highlight (cap 2 slots); beam (Attachment + Beam built in code) only when KitchenGuidance.ShouldShowBeam; setting off or clocked out clears everything. PromptButtonHoldBegan on kitchen prompts gives "Next: <label>" at hold start (well under 0.3 s). InteractionFailed("ClockedOut") listener shows a Clock In toast. GetCurrentChoice() exposed. Instant Brew path unchanged.
- AppDialogs: DialogController:Toast(text) (SmallNotification reads .Text; Notify passes Title/Description, which it never read). When a dialog opens, a gold UIStroke tween pulses the button whose label equals GetCurrentChoice() (size, coffee, food pickers); removed when the dialog changes.
- KitchenService/init.luau: fires InteractionFailed("ClockedOut") on the clocked-out branch. Grep first: no client listener and no ClockedOut fire existed before.

## Gate (full output)
```
PASS  src/client/Modules/KitchenGuidance.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/KitchenGuidance.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/client/Modules/KitchenController.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/client/Modules/AppDialogs.luau  selene new=0 (baseline[HEAD]=3 now=2)  stylua=pre-existing stylua drift
PASS  src/shared/Configuration/SettingsConfig.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=pre-existing stylua drift
PASS  src/server/Modules/KitchenService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

## Lune results
Run with a SHIM (a 10-line describe/it/expect in $TMPDIR/kg/run.luau, not TestEZ, not in the repo). The spec was copied with its two requires rewritten to local copies of OrderSpec and KitchenGuidance. Result: 23 passed, 0 failed (NearestIndex 3, Compute 7, ShouldShowBeam 4, WrongStationMessage 4, ResolveSpec 4, cap 1). The real TestEZ run reads the module from game.StarterPlayer.StarterPlayerScripts.Client.Modules (unverified path).

## Design questions / dependencies hit
- Q3 (blender): not decided. Blender is in NEUTRAL_STATIONS so no toast under Q3=false; under Q3=true the Steps chain makes it the current station and it highlights. Works under either answer.
- Q4 (first session): "first 3 customers" is counted per client session (distinct CurrentOrder objects), not from the profile. Persistent count needs a decision.
- Q13 (syrup bar): nearest-Model highlight works at any spacing.
- Q14: not touched.
- M1.4f ticket shape (OrderController.CurrentOrder) is not on disk. ResolveSpec accepts a spec, .Spec, {Category,Item,CustomInfo}, or a list of those. Serve-step NPC target is read from order.Npc / NpcModel / Customer / Model if it is a Model; otherwise no NPC highlight. Needs confirming against M1.4f.
- Tuning constants (beam 3 customers / 20 s, max 2 highlights, neutral stations) sit in KitchenGuidance.luau as -- TUNING, because KitchenConfig is outside the lease.

## Gauge Studio steps
1. Rojo sync, Play with a seeded boba NPC order. Confirm one gold Highlight on the nearest Clear Cup model, and a gold beam from the character to it.
2. Move between two Milk models; the Highlight follows the nearer. Count Highlight instances in workspace: never more than 2.
3. Make each step; Highlight and beam advance. At Serve it moves to the NPC (if M1.4f exposes it).
4. Complete 4+ orders of the same item; the beam stops on order 4 until idle 20 s, then returns. A new item shows the beam again.
5. Settings > Staff > "Station hints" off: Highlight and beam vanish; toasts stop. Visible to a low-rank account.
6. Hold a wrong station (for example Taro Syrup at the Milk step): toast "Next: Milk" within 0.3 s of pressing.
7. Open the Clear Cup size picker, Coffee Machine picker and Food Display: the matching button has a pulsing gold outline.
8. Clock out, use a station: Clock In toast; no highlights while clocked out.
9. Set workspace attribute RunTests = true; confirm KitchenGuidance.spec passes in TestEZ.
