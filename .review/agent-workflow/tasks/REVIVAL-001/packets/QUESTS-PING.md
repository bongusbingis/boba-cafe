---
id: QUESTS-PING
title: Halfway quest progress toast (server) and a claimable dot on the Quests button (client)
priority: P1
role: Mason
worker_tier: haiku-ok
release_gate: before
depends_on: [GAMEPLAY-TOASTS, GAMEPLAY-QUEST-NUDGES]
status: READY
source_commit: 098175c
read_scope: [src/server/Modules/QuestService.luau, src/shared/Configuration/QuestConfig.luau, src/shared/UI/Components/Core/Hud/BottomRight.luau, src/shared/UI/Components/Core/Hud/QuestCard.luau, src/shared/UI/Components/Core/Hud/init.luau, src/shared/UI/Components/Buttons/NormalButton.luau]
write_scope: [src/server/Modules/QuestService.luau (AdvanceQuest only), src/shared/UI/Components/Core/Hud/BottomRight.luau]
invariants: [serve-path no-yield: AdvanceQuest can yield, so the new toast is task.defer + pcall and adds no wait, DataStore or await call; new code runs after SetValue and QuestsUpdated, DEC-013 (existing tokens and components only), no economy change, no Quests claim or reroll logic change]
acceptance:
  - AdvanceQuest posts one toast per quest per day when Progress first reaches ceil(Target / 2) for quests with Target >= 4, text "<Quest title>: <Progress>/<Target>".
  - The Quests button shows a green dot while any quest is Completed and not Claimed; the dot hides when none are.
  - No new Styles token, no new component file, no sound.
checks: [scripts/gate.sh on each changed file (Selene, StyLua --check, no new findings); rojo build default.project.json -o <path outside repo>]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/QUESTS-PING
forbidden: [WORKER-PRIMER 8, editing QuestConfig.luau (titles, targets, rewards), editing ClaimQuest, RerollQuest, CustomerService, RealOrderService, QuestCard.luau, NormalButton.luau, Hud/init.luau, adding any wait or DataStore call inside AdvanceQuest]
---

Worker rules: `_meta/WORKER-PRIMER.md` sections 1-10. Source commit 098175c. Anchor by symbol name.

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- Q3 (review, HEAD c77e20c): What: Quest progress pings at halfway ("Serve 5 customers: 3/5"). Why: Micro-goals mid-shift. Files: QuestService. Effort: XS. Risk: Low. Tag: OBVIOUS (watch toast volume; only after N2).
- Q4 (review, HEAD c77e20c): What: Claimable dot on the Quests button. Why: Standard affordance. Files: BottomRight.luau. Effort: XS. Risk: Low. Tag: JACK.

## 2. Decisions made
- D1 Halfway threshold: `threshold = math.ceil(quest.Target / 2)`. Target 5 gives 3, matching "3/5". Rationale: exact halfway rounded up, no float.
- D2 Only quests with `Target >= 4` get a halfway ping. Rationale: Targets of 1 and 2 would ping at the same moment as completion or be meaningless.
- D3 Once per quest per day: the entry gets a persisted flag `HalfwayPinged = true` inside `Quests.ActiveQuests`. The list regenerates each day (`AssignedDay`), so the flag resets daily. Rationale: survives rejoin, no in-memory table. The field is added to saved entries only (adding a field is allowed; no rename or removal).
- D4 The ping is skipped on the call that completes the quest. Rationale: `GAMEPLAY-QUEST-NUDGES` already announces completion.
- D5 Toast text is built from `QuestConfig.GetQuestTitle(quest)` (the template title, e.g. "Serve 5 Customers") plus `": "` plus `Progress/Target`. Rationale: the title is the single source of quest copy; the template uses capital C, so the output reads "Serve 5 Customers: 3/5".
- D6 The toast goes through `DialogService:Notify(player, { Text = ... })` inside `task.defer` and `pcall`, looked up with `self:_getService("DialogService")` and nil-checked. Rationale: non-yielding, safe with the spec fake (which returns nil), and the Text payload is the form the TOASTS queue renders.
- D7 Claimable dot: a `Pane` Frame using `Styles.GREEN_BADGE` fill, `Styles.CORNER_FULL` corner, `Styles.OFFWHITE` stroke thickness 2 (the stroke used by `NormalButton`), placed over the Quests button. Rationale: `docs/STYLE.md` has no notification-dot pattern. The nearest existing pattern is the `GREEN_BADGE` token (STYLE section 1, "Best Value" badge), so the dot uses that token; no new colour, shape or size token. This is the fallback named in the brief.
- D8 Dot data: `BottomRight` fetches `QuestService:GetQuests()` once on mount and listens to `QuestService.QuestsUpdated`. `claimable = true` when any entry has `Completed == true` and `Claimed ~= true`. Rationale: same client API `QuestCard` already uses; no new remote.
- D9 (FEEDBACK-VOICE 1-5): the halfway toast is info: no exclamation mark, no emoji, no sound (SOUNDS leaves it silent), priority tier 3 (FIFO until the queue has a priority field). The dot is green (`GREEN_BADGE`), never gold, since gold is money and rank only.

## 3. Exact strings and numbers
- Halfway toast: `string.format("%s: %d/%d", QuestConfig.GetQuestTitle(quest), quest.Progress, quest.Target)`, e.g. `Serve 5 Customers: 3/5`. The dot has no label.
- Threshold `math.ceil(quest.Target / 2)`. `HALFWAY_MIN_TARGET = 4` at the top of QuestService.luau, next to `DATA_TIMEOUT_SECONDS`.
- Dot: `UDim2.fromOffset(px(16), px(16))`, `px = usePx()`; position `UDim2.fromScale(0.94, 0.1)`, `AnchorPoint = Vector2.new(0.5, 0.5)`, `ZIndex = 5`.

## 4. Signatures and names
- `QuestService:AdvanceQuest(player: Player, questType: string, amount: number?): boolean` (unchanged).
- New saved entry field `HalfwayPinged` on `Quests.ActiveQuests[i]`, accessed as `(quest :: any).HalfwayPinged`.
- Existing client API: `QuestService:GetQuests()` and `QuestService.QuestsUpdated`.

## 5. Code shape

### 6a. QuestService.luau, AdvanceQuest only
1. Add `local halfwayEntries = {}` immediately after `local changed = false`.
2. Inside the `for _, quest in activeQuests do` / `if quest.Type == questType and not quest.Completed then` block, immediately after the existing `if quest.Progress >= quest.Target then quest.Completed = true end` lines and before `changed = true`, add:
```lua
if not quest.Completed and quest.Target >= HALFWAY_MIN_TARGET and (quest :: any).HalfwayPinged ~= true
	and quest.Progress >= math.ceil(quest.Target / 2) then
	(quest :: any).HalfwayPinged = true
	table.insert(halfwayEntries, quest)
end
```
3. After the existing `if changed then ... end` block (after its `QuestsUpdated` fire) and before `return changed`, add:
```lua
if #halfwayEntries > 0 then
	task.defer(function()
		pcall(function()
			local dialog = self:_getService("DialogService")
			if dialog then
				for _, quest in halfwayEntries do
					dialog:Notify(player, {
						Text = string.format("%s: %d/%d", QuestConfig.GetQuestTitle(quest), quest.Progress, quest.Target),
					})
				end
			end
		end)
	end)
end
```
If `GAMEPLAY-QUEST-NUDGES` has already added its own `task.defer` block after `QuestsUpdated`, add this block after that block. Do not merge them.

### 6b. BottomRight.luau
- Add `local RunService = game:GetService("RunService")`, `local Knit = require(Packages.Knit)`, `local usePx = require(UI.Hooks.usePx)`.
- In the component: `local px = usePx()` and `local claimable, setClaimable = React.useState(false)`.
- Guarded as in `BottomLeft.luau`: `if RunService:IsRunning() then React.useEffect(..., {}) end`. The effect runs its body in `task.spawn` with `pcall`, calls `GetQuests()` (promise handled as in `QuestCard`: `res:andThen(refresh)` or direct), then `conn = QuestService.QuestsUpdated:Connect(refresh)`. Cleanup disconnects `conn` if set.
- `refresh(quests)`: `claimable = true` when any entry has `Completed == true and Claimed ~= true`, else false, via `setClaimable`.
- Render: the `Quests` child becomes a slot `Pane` (`ClassName = "Frame"`, `AspectRatio = 7` (NormalButton's wrapper ratio, so the slot is exactly the pill and the dot lands on the pill's corner, not on empty container space), `Native = { BackgroundTransparency = 1, Size = BUTTON_SIZE, LayoutOrder = 1 }`) holding:
  - `Button = c(NormalButton, { Icon = "", Position = UDim2.fromScale(0.5, 0.5), Size = BUTTON_SIZE, Color = Styles.GREEN_MID, Text = "Quests", OnClick = <unchanged> })`. `Position` is required: NormalButton's wrapper is anchored (0.5,0.5) with default Position (0.0244846, 0.46814), which outside a UIListLayout would put the pill half off the slot to the left.
  - `ClaimDot = if claimable then c(Pane, { ClassName = "Frame", CornerRadius = Styles.CORNER_FULL, Stroke = { Color = Styles.OFFWHITE, Thickness = 2 }, Native = { Name = "QuestClaimDot", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Styles.GREEN_BADGE, BackgroundTransparency = 0, Position = UDim2.fromScale(0.94, 0.1), Size = UDim2.fromOffset(px(16), px(16)), ZIndex = 5 } }) else nil`
- The slot carries `LayoutOrder`; `NormalButton` gets no `LayoutOrder`. Exported props (`CurrentPage`, `SetCurrentPage`, `QuestsOpen`, `OnToggleQuests`) are unchanged.

## 6. UI spec
Dot: 16 px scaled by `usePx`, circular, `GREEN_BADGE` fill, 2 px `OFFWHITE` stroke, inside the Quests button's top-right corner. The button keeps its place and size at 844x390. No animation, sound or spring.
Style review at 844x390 (computed from source): px scale floors at 0.75, so the dot is 12 px; BottomRight is 148 x 25 px at x 484-632, the pill (aspect 7) 148 x 21 px; dot centre at about x 623, y 363, so its right edge (about 631) stays left of the 0.75-width jump zone (633) and it overhangs the pill top by about 4 px, which is the badge intent. The dot is a new visual pattern under STYLE rule 0, built under the DEC-053 delegation from existing tokens only; contrast note: the green dot sits on a green (`GREEN_MID`) pill and relies on the `OFFWHITE` ring to read, see Open items.

## 7. Studio checks (batched by Prime for Jack; workers do not run Studio)
- S1: Start a shift, let the "Serve 5 Customers" quest be active, serve 3 customers. Expected: one toast `Serve 5 Customers: 3/5`.
- S2: Serve a 4th customer. Expected: no second halfway toast.
- S3: Serve the 5th customer. Expected: the quest-complete toast from GAMEPLAY-QUEST-NUDGES only; no halfway toast.
- S4: Right after S3, with the quest completed and unclaimed, expected: green dot on the Quests button, visible on an 844x390 phone.
- S5: Claim the quest in Quests. Expected: dot disappears.
- S6: Rejoin the same day after S1 (3/5 saved). Expected: serving the 4th customer does not repeat the 3/5 toast (flag persisted).

## 8. Asset prerequisites
None. No sound, model or instance is required.

## 9. Serve-path note
`AdvanceQuest` is reached from the serve path. This packet adds only `task.defer` and `pcall` after the existing writes, no wait, `:await()`, DataStore or Marketplace call. `GAMEPLAY-SERVE-QUEST-YIELD` owns the caller side.

Open items: HARD-STOP none. Additive data: `Quests.ActiveQuests` entries gain `HalfwayPinged`; entries without it read as not pinged.
- PENDING JACK (style review, confirm at S4, not blocking): the claimable dot is a new visual pattern (STYLE rule 0) made from `GREEN_BADGE` + `CORNER_FULL` + the NormalButton `OFFWHITE` stroke 2. On the `GREEN_MID` Quests pill green-on-green may read weakly. Keep GREEN_BADGE (default), or Jack names another existing token; agents pick no other colour.

## Summary
- Server: `AdvanceQuest` posts one halfway toast per quest per day (Target >= 4, threshold ceil(Target/2)) via task.defer and pcall.
- Persisted flag `HalfwayPinged` prevents repeats and survives rejoin.
- Client: green dot on the Quests button while a completed quest is unclaimed.
- STYLE.md has no dot pattern; the dot uses the existing `GREEN_BADGE` token with `Pane` (D7, fallback named in the brief).
- No economy, claim or reroll change; no sound; no new file. Runtime checks S1-S6 are for Jack.
