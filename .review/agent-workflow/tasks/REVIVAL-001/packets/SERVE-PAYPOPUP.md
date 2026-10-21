---
id: SERVE-PAYPOPUP
title: Juicy serve pay popup - rising gold +N BB and Perfect sparkle
priority: P2
role: Mason
worker_tier: sonnet
release_gate: after   # split gate: the S3 popup half (D1-D7) ships before release, the S9 sparkle half (D8) after
depends_on: [SERVE-FEEDBACK]
status: READY
source_commit: 098175c
read_scope:
  - src/server/Modules/CustomerService/init.luau (symbols: _showServePay and its call in _onServeTriggered)
  - src/shared/UI/Styles.luau (GOLD, FONT_FREDOKA)
  - src/client/Modules/DailyRewardController.luau (controller shape to copy)
  - src/shared/Utility/WorldPath.luau
  - src/server/Modules/SpillService/Spill.luau (_FinishCleaning: the Sparkles clone/Emit pattern, read only)
write_scope:
  - src/server/Modules/CustomerService/init.luau (the _showServePay function and its single call argument list only)
  - src/client/Modules/ServeJuice.luau (new file)
invariants:
  - "Serve-path no-yield: nothing yields between the serve guards and the payout in CustomerService:_onServeTriggered. `_showServePay` runs after the payout; it only creates Instances and calls task.delay, which do not yield. Add no WaitForChild, task.wait, data or Marketplace call to it."
  - "Client code never touches the serve path; all waits live in task.spawn on the client."
  - "DEC-013 / STYLE 1.2: colours from Styles only. Fill GOLD, stroke = GOLD lerped 30% to black, thickness 1 (the ActionButton label-stroke derivation). Font Styles.FONT_FREDOKA. No new colour, font or asset."
  - "The Sparkles particle is the existing ReplicatedStorage.SharedStorage.CleanlinessStorage.Sparkles; never build a substitute (DEC-008)."
acceptance:
  - "On every serve a gold '+N BB' label rises 2 studs and fades out over 1 s, then the server destroys the gui at 1.5 s as before."
  - "On a Perfect serve a sparkle burst plays at the NPC head; on Close none."
  - "If Sparkles or the Customers folder is missing, nothing errors and the popup still works (sparkle skipped, one warn)."
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/CustomerService/init.luau src/client/Modules/ServeJuice.luau' (stylua only on files whose HEAD copy passes stylua --check; ServeJuice.luau is new, so stylua it)"
  - "rojo build default.project.json -o <scratchpad path outside the repo>"
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/SERVE-PAYPOPUP
forbidden: [WORKER-PRIMER section 8, new particle or texture, new colour/font, editing Styles.luau, editing KitchenController.luau, any yielding call in _showServePay, sounds]
---

Rules and gate: `_meta/WORKER-PRIMER.md` (not repeated). Lease: CustomerService/init.luau after SERVE-FEEDBACK, before PATIENCE-RAMP. `ServeJuice.luau` is a new file (one writer).

## Source excerpt
- S3: What: Juicy pay popup: the client finds the server's ServePay gui under workspace.Customers, tweens StudsOffset +2 studs and fades out over 1 s; text +N BB in GOLD with the sanctioned derived stroke (STYLE 1.2). Why: The +N is easy to miss; a rising number is the genre's universal "you got paid". Files: new small client module or KitchenController; server _showServePay text only. Effort: S. Risk: Low. Tag: JACK (new look). Q-G5 (DEC-054): popup rises and fades, GOLD with derived stroke.
- S9: What: Perfect sparkle: a short existing-particle burst at the NPC on Perfect (only if a particle is already authored, for example CleanlinessStorage.Sparkles). Why: Visual punctuation for quality. Files: client. Effort: S. Risk: Low. Tag: JACK (reusing an asset for a new purpose).

## Verified facts (HEAD 098175c)
- `_showServePay(npc, pay)` builds a BillboardGui named `ServePay` (Size 120x40 offset, StudsOffset (0,4.5,0), AlwaysOnTop, Adornee = `npc.Model.Head`), one TextLabel (`Styles.GREEN_DEEP`, text `+{pay}`), parents it to `npc.Model` and destroys it after 1.5 s. NPC models live under `workspace.Customers` (`CUSTOMERS_FOLDER_NAME`; KitchenController reads `workspace:FindFirstChild("Customers")`).
- Sparkles is authored at `ReplicatedStorage.SharedStorage.CleanlinessStorage.Sparkles` (SpillService checks that path; `Spill._FinishCleaning` clones it, parents it to a part and calls `:Emit(30)`). ReplicatedStorage content is readable by the client.
- Client controllers are loaded by `Knit.AddControllersDeep(script.Modules)` in `src/client/init.client.luau`, so a new file in `src/client/Modules` must be a `Knit.CreateController`.

## Decisions made
- D1 (server text): `payLabel.Text = ` + backtick string `+{pay} BB`. Rationale: Q-G5 copy and the review.
- D2 (server look): `payLabel.TextColor3 = Styles.GOLD`; add a `UIStroke` child of `payLabel` with `Color = Styles.GOLD:Lerp(Color3.new(0, 0, 0), 0.3)`, `Thickness = 1`, `ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual`. Rationale: STYLE 1.2 label-stroke derivation (ActionButton.luau:92); GREEN_DEEP text is replaced.
- D2b (style review): also set `gui.MaxDistance = 80` (NPC bubble value, STYLE 4.5 and checklist 10). Instance property only, no yield; inside the same `_showServePay` function in write scope.
- D3 (grade hand-off): `_showServePay(npc: Npc.Npc, pay: number, grade: Rules.ServeGrade)` sets `gui:SetAttribute("Grade", grade)` BEFORE `gui.Parent = npc.Model`. The call in `_onServeTriggered` becomes `self:_showServePay(npc, pay, grade)`. Rationale: the client reads the grade from the gui it already watches; no remote.
- D4 (server lifetime): keep `task.delay(1.5, ...)` unchanged; the client animation (1 s) ends before it. Rationale: no behaviour change when the client module is absent.
- D5 (client module): `src/client/Modules/ServeJuice.luau`, `Knit.CreateController({ Name = "ServeJuice" })`, strict mode, header comment naming REVIVAL-001 SERVE-PAYPOPUP. `KnitStart` runs `task.spawn` that does `workspace:WaitForChild("Customers", 30)`; if nil it warns once (`[ServeJuice] workspace.Customers not found; pay popup disabled`) and returns. Otherwise connect `customers.DescendantAdded` to `onAdded(instance)`. Rationale: the server owns the instance; the client only animates it locally.
- D6 (match): `onAdded` acts only when `instance:IsA("BillboardGui") and instance.Name == "ServePay"`, skipping if `instance:GetAttribute("Juiced")` is true (set the attribute locally first). Rationale: runs once per popup.
- D7 (tween): `local label = instance:FindFirstChildWhichIsA("TextLabel")`; `local stroke = label and label:FindFirstChildWhichIsA("UIStroke")`; one `TweenService:Create(instance, info, { StudsOffset = instance.StudsOffset + Vector3.new(0, RISE_STUDS, 0) })`, one for `label` `{ TextTransparency = 1 }` and one for `stroke` `{ Transparency = 1 }`, all with `info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)`. Missing label or stroke skips only that tween. Rationale: 1 s rise and fade as specified; Quad Out is a standard TweenInfo, no new spring.
- D8 (sparkle): when `instance:GetAttribute("Grade") == "Perfect"`, `local anchor = instance.Adornee`; if it is a BasePart, find the template once with `WorldPath.find(ReplicatedStorage, { "SharedStorage", "CleanlinessStorage", "Sparkles" })` (cache the result, also cache a miss), require `template:IsA("ParticleEmitter")`, `local burst = template:Clone()`, `burst.Parent = anchor`, `burst:Emit(SPARKLE_COUNT)`, `Debris:AddItem(burst, SPARKLE_CLEANUP_SECONDS)`. A missing template or wrong class warns once (`[ServeJuice] CleanlinessStorage.Sparkles missing or not a ParticleEmitter; sparkle disabled`) and skips. No other particle is created. Rationale: S9 reuses the authored asset exactly as Spill does.
- D10 (voice and budget): the popup is beat 1 of FEEDBACK-VOICE 2: it appears instantly on every serve, uses `BB` (never "Boba Bucks"), is GOLD because it is money (FEEDBACK-VOICE 5), makes no sound, and does not count as a toast.
- D9: the module is purely client-side and every callback body runs in `pcall`; an error in juice never reaches gameplay.

## Exact strings
- Label: `+{pay} BB` (example `+12 BB`).
- Warn lines: as in D5 and D8, once each.

## Exact numbers (animation constants, TUNING, not economy)
`RISE_STUDS = 2`, `FADE_SECONDS = 1`, `SPARKLE_COUNT = 30` (same as Spill), `SPARKLE_CLEANUP_SECONDS = 3`.

## Signatures
- Server: `CustomerService:_showServePay(npc: Npc.Npc, pay: number, grade: Rules.ServeGrade)`. Attribute on the gui: `Grade` (string, "Perfect" or "Close").
- Client: `ServeJuice` controller with `KnitStart`; private `onAdded(instance: Instance)`, `playSparkle(anchor: BasePart)`. No remotes, no profile fields.

## UI spec
World-space BillboardGui already placed by the server (Size 120x40 offset, StudsOffset start (0,4.5,0), ends at (0,6.5,0)). TextScaled Fredoka, GOLD, 1 px derived stroke (STYLE 1.2 label stroke, the only sanctioned derivation; no other shade). No Pane, no new component.
Style review: an offset-sized BillboardGui does NOT scale with distance; it stays 120 x 40 screen px at every distance. At 844x390 that is 14 % x 10 % of the screen, the same order as the NPC bubble (200 x 64 px), so it stays legible; it renders under all ScreenGui HUD (billboards draw below 2D UI), so it cannot cover the ticket column, toast or level bar. D2b: set `gui.MaxDistance = 80` (the NPC bubble value, STYLE 4.5 / checklist 10 "MaxDistance set") so distant serves by other players do not stack constant-size popups across the screen. The popup starts 1 stud above the bubble's StudsOffset (3.5) and rises away from it; overlap with a still-visible bubble at the start is Studio check S1.

## Studio checks (for Jack, batched)
- S1: serve a Close drink. Expect a gold "+N BB" over the NPC head rising about 2 studs and fading in about 1 s; no sparkles.
- S2: serve a Perfect drink. Expect the same plus a short sparkle burst at the head.
- S3: have a second player in the server serve. Expect both clients see the popup.
- S4: temporarily rename `CleanlinessStorage.Sparkles` (Jack's Studio only). Expect popup still works, one warn, no errors; rename back.
- S5: pay, toast, combo and the customer leaving behave exactly as before.

## Asset prerequisites
`ReplicatedStorage.SharedStorage.CleanlinessStorage.Sparkles` (ParticleEmitter, exists per SpillService; Studio-authored, not in Rojo). If absent: skip the burst only, never build a substitute.

Open items: HARD-STOP 1 (confirm only, not blocking): "Sparkles in CleanlinessStorage may be reused for the Perfect burst: yes or no?" (S9 is tagged JACK; DEC-053 delegation covers it, so the packet proceeds; answer no = delete D8.) Gate note (split gate): the S3 half (D1-D7, D10) is release before; the S9 half (D8) is release after. Frontmatter says `after` because of S9; Prime ships the S3 half first by omitting D8.

## Summary
- Server `_showServePay` text becomes `+N BB`, GOLD with the derived 30% stroke, plus a `Grade` attribute.
- New client Knit controller `ServeJuice` tweens the server's ServePay gui (rise 2 studs, fade 1 s).
- Perfect clones the existing CleanlinessStorage.Sparkles at the NPC head (Emit 30, cleanup 3 s).
- All client code is pcall-wrapped; a missing particle is skipped with one warn.
- Serve path unchanged: `_showServePay` still only builds Instances after the payout.
- Leases: after SERVE-FEEDBACK; ServeJuice.luau is a single-writer new file.
