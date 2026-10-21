# REVIVAL-001 branch review fixes (Opus fixer, 2026-10-20/21)

Authority: Jack, 2026-10-20 ("I trust opus and I will fix things/change myself afterwards"). Design calls below
were made by the fixer, not PENDING JACK.

| ID | Status | Commit | Notes |
|----|--------|--------|-------|
| P2-1 + E-O1 | FIXED | efb12ff | `_applyShiftXp` snapshots Level/XP before `AddXp` and predicts from the snapshot (`ProgressionService.Predict`); with no cache before AddXp it reads the cache as-is. Level-up toast is `ProgressionService.LevelUpText(level)`: "Level up! You are now level L · {unlock1} · {unlock2}", new drinks and the nametag first, from `unlocksAt`/`Rules.NewDrinksAt` (covers Taro, Strawberry, Espresso, Mango). Spec: `ProgressionService.spec.luau`. |
| P2-2 | FIXED | 4267ad3 | `SmallNotification.Classify` (tier 1..5, kind Corrective/Served; optional `Priority`/`Corrective` fields) and `SmallNotification.Route`. Tier 1 (Level up, Quest complete/claimed, first order) is never dropped; queue is tier-ordered, FIFO within a tier; overflow drops the oldest of the lowest tier; queued "Order served!" is replaced by the newest; identical text (active or queued) is ignored; Wrong drink / "Next: " wrong-station / Clock In replace the active toast at once and a displaced tier 1-2 toast goes back to the front; hints drop while busy. Other players' Team Combo lines are tier 3, own tier 2. No producer changes needed. Spec: `ToastQueue.spec.luau`. |
| P2-3 + P3-6 | FIXED | 1b54074 | Hook registers on every join while `Nickname == ""` and the new profile field `NicknameSkipped` (default false, additive via Reconcile) is false; fires on any shift end. Skip ("") sets `NicknameSkipped`. A nil result is a timeout (>= 115 s: re-armed for the next shift end), a leave (offered next join) or an empty Submit (re-prompt "Type a nickname, or press Skip."). Prompt copy "This cannot be changed later" kept: a Submit and a Skip are both final. Connections are released on leave (AncestryChanged), which also fixes P3-6. |
| P3-1 | FIXED | 3265c30 | ShiftsCompleted `AdvanceQuest` is `task.spawn`ed in `_endShift`. |
| P3-2 | FIXED (reword) | 3265c30 | Toast is now "Quest complete: {title}!". The BottomRight claim dot stays with the unmounted BottomRight (no opener exists yet; nothing to re-home). |
| P3-5 | FIXED | 3265c30 | Capsule nudge waits up to 160 s on `NicknamePending` and skips this shift (retries next shift end) if the prompt is still open. |
| P3-4 | FIXED | 15aa28e | ShiftCard row height = min(0.12, (1 - 0.02*(n-1))/n), so the new Streak line (7 rows) and any later line fit. "Next shift starts now" copy kept (harmless). |
| P3-3 | SKIPPED | - | Ticket column height cap vs ShiftCard needs a viewport check at phone/1280x720 presets, and OrderTicket mobile auto-expand was reworked in the checkpoint. Left for a UI pass. |
| P3-7, P3-8, P3-9, P3-10 | SKIPPED | - | Not in scope for this pass (serve-XP ordering, Daily auto-open for non-baristas, Recipe Book focus key, Bucks count-up from 0). P3-7/P3-9 touch CustomerService/Recipes, owned by other agents right now. |

## Gates
- Selene: no findings in any changed file (base vs head per file).
- StyLua `--check`: clean on every changed file.
- `rojo build default.project.json -o C:/Users/jackc/AppData/Local/Temp/fix.rbxlx`: OK after each commit.

## Studio checks (Roblox Studio MCP, place 89999123284040)
1. Rojo sync confirmed: new specs and the edited ProgressionService/ShiftService/SmallNotification are in Studio.
2. Full TestEZ suite via workspace attribute `RunTests` (no edit to RunTests.server.luau): "All 745 test(s) passed."
3. Targeted TestEZ run in the Server DataModel (ProgressionService, ToastQueue, ShiftService, QuestService, Progression specs): 57 passed, 0 failed.
4. `RunTests` attribute cleared afterwards.

Seen in the console, not from these fixes: `CustomerService.Npc:884: attempt to call a nil value` on NPC despawn (CustomerService is being edited by another agent).
