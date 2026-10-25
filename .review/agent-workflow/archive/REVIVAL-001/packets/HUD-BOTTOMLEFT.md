---
id: HUD-BOTTOMLEFT
title: Bottom-left HUD: Bucks pop and count-up, hide Points, Clock Out confirm
priority: P1
role: Mason
worker_tier: haiku-ok
release_gate: before
depends_on: []
status: READY
source_commit: 098175c
read_scope: [src/shared/UI/Components/Core/Hud/BottomLeft.luau, src/shared/UI/Components/Dialogs/ButtonPrompt.luau, src/shared/UI/Styles.luau, src/shared/UI/Components/Pane.luau, src/client/Modules/AppDialogs.luau (DialogController.new, Fire, the TweenService pattern at lines 46-48 and 98-128 only), docs/STYLE.md (sections 9.5 and 1.4 only)]
write_scope: [src/shared/UI/Components/Core/Hud/BottomLeft.luau]
invariants: [client-only UI, no serve path or server file touched, DEC-013 (existing tokens only, no new Styles entry), Points stays in the currency state and listeners (hidden, not deleted), runtime-only work gated by RunService:IsRunning(), story-preview branch of toggleClockedIn unchanged]
acceptance: [Bucks button pops when BobaBucks rises and not on the first load, Bucks number counts from the previous value to the new one over 0.4 s, no Points button is rendered, Clock Out opens a ButtonPrompt and only "Clock Out" sends SetClockedIn(false), Clock In sends SetClockedIn(true) with no prompt, gate passes with no new Selene or StyLua findings in BottomLeft.luau]
checks: [scripts/gate.sh src/shared/UI/Components/Core/Hud/BottomLeft.luau, rojo build default.project.json -o <scratchpad>/rojo-hud.rbxl]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/HUD-BOTTOMLEFT
forbidden: [see WORKER-PRIMER section 8, editing Styles.luau or Pane.luau, editing ButtonPrompt.luau or AppDialogs.luau, deleting the Points data or its ListenToChange, changing NormalButton.luau (wrap instead)]
---

Rules: [WORKER-PRIMER](_meta/WORKER-PRIMER.md).

## Source excerpt
S4 (review, HEAD c77e20c)
- What: Bucks counter pulse: the Bucks NormalButton does a scale pop (existing Pane Scale + SPRING_STANDARD) when BobaBucks increases
- Why: Ties "+5" to "my money went up"
- Files: BottomLeft.luau
- Effort: XS
- Risk: Low
- Tag: OBVIOUS (the existing press-scale pattern, STYLE 9.5)

S5 (review, HEAD c77e20c)
- What: Count-up of the Bucks number over 0.4 s instead of a jump
- Why: Small, classic money feel
- Files: BottomLeft.luau
- Effort: XS
- Risk: Low
- Tag: OBVIOUS (it is text, but confirm with Prime that a number tick is not a "new pattern")

O5 (review, HEAD c77e20c)
- What: Hide Points on the HUD (plan 4.5 retires Points as a currency)
- Why: One less meaningless number
- Files: BottomLeft.luau
- Effort: XS
- Risk: Low
- Tag: JACK (already in plan; confirm)
M4 (review, HEAD c77e20c)
- What: Bottom-left stack height: Clock Out sits in the main stack and one mistap clocks you out mid-shift (the shift resets: _states[player] = nil). A confirm via ButtonPrompt ("Clock out? Your shift progress resets.")
- Why: Prevents a frustrating accidental loss
- Files: BottomLeft.luau
- Effort: XS
- Risk: Low
- Tag: OBVIOUS (existing dialog type)

## Decisions made
- D1 (S4): The Bucks button sits in a transparent Pane Frame that takes `Scale = bucksPop.Scale`; NormalButton does not change. Pop = 1.07 to 1 with `Styles.SPRING_STANDARD`; the pop runs only when the balance rises from a known previous value. Rationale: Pane Scale is the documented path (STYLE 9.5); 1.07 is the existing hover value.
- D2 (S5): Count-up 0.4 s Quad Out on a temporary NumberValue (the TweenService pattern at AppDialogs.luau:47), on every balance change, integer, no separator. Rationale: existing pattern, no new easing or format.
- D3 (O5): The Points NormalButton child is deleted; `currency.Points`, its ListenToChange and the Shop route stay. Rationale: the plan retires the display, not the data.
- D4 (M4): Clock Out (the `clockedIn == true` branch) opens a ButtonPrompt through DialogController; Clock In does not. Confirm "Clock Out" is `Styles.GOLD_MID` on the left, "Cancel" is `Styles.RED` on the right (STYLE 7: cancel/negative on the right; Sell/Cancel precedent). Title is Title Case `Clock Out?` (STYLE 7). Rationale: the confirm guards the only destructive action in the stack; colours already exist.
- D5 (style review): the BucksWrap slot copies NormalButton's wrapper ratio (`AspectRatio = 7`) so it stays one 22 px pill tall in the 60 px CurrencyPanel (without it the slot is 152 x 60 px and the stack grows 38 px), and the inner NormalButton gets `Position = UDim2.fromScale(0.5, 0.5)` because its wrapper is anchored (0.5,0.5) with a default Position of (0.0244846, 0.46814), which outside a UIListLayout would push the pill half off the slot to the left.

## Signatures and insertion points (anchor by symbol)
1. Constants block: add `local TweenService = game:GetService("TweenService")`, `local ReactSpring = require(Packages.ReactSpring)` (as SmallNotification.luau does), `local COUNT_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)`, `local POP_SCALE = 1.07`, `local CLOCK_OUT_TITLE = "Clock Out?"`, `local CLOCK_OUT_TEXT = "Your shift progress resets."`.
2. Inside the component, after `local currency, setCurrency = React.useState(...)`:
```
local bucksPop, bucksPopApi = ReactSpring.useSpring(function()
	return { Scale = 1, config = Styles.SPRING_STANDARD }
end)
local shownBucks, setShownBucks = React.useState(0)
local prevBucksRef = React.useRef(nil :: number?)
React.useEffect(function()
	local target = currency.BobaBucks
	local prev = prevBucksRef.current
	prevBucksRef.current = target
	if not RunService:IsRunning() then
		setShownBucks(target)
		return
	end
	if prev ~= nil and target > prev then
		bucksPopApi.start({ from = { Scale = POP_SCALE }, to = { Scale = 1 }, config = Styles.SPRING_STANDARD })
	end
	local counter = Instance.new("NumberValue")
	counter.Value = prev or 0
	local changed = counter.Changed:Connect(function(v)
		setShownBucks(math.floor(v + 0.5))
	end)
	local tween = TweenService:Create(counter, COUNT_TWEEN, { Value = target })
	tween:Play()
	return function()
		tween:Cancel()
		changed:Disconnect()
		counter:Destroy()
	end
end, { currency.BobaBucks })
```
3. Move the existing `task.spawn(... SetClockedIn(wantClockedIn) ...)` body unchanged into a local `sendClockedIn(wantClockedIn: boolean)`. Replace `toggleClockedIn` with:
```
local function toggleClockedIn()
	local wantClockedIn = not clockedIn
	if not RunService:IsRunning() then
		setClockedIn(wantClockedIn) -- story preview
		return
	end
	if clockedIn then
		local prompt = Knit.GetController("DialogController").new("ButtonPrompt", {
			Title = CLOCK_OUT_TITLE,
			Text = CLOCK_OUT_TEXT,
			Buttons = {
				{ Text = "Clock Out", Color = Styles.GOLD_MID },
				{ Text = "Cancel", Color = Styles.RED },
			},
		})
		prompt:Fire():andThen(function(choice)
			if choice == "Clock Out" then
				sendClockedIn(false)
			end
		end)
		return
	end
	sendClockedIn(true)
end
```
4. Replace the `Bucks = c(NormalButton, {...})` child with:
```
BucksWrap = c(Pane, {
	ClassName = "Frame",
	Scale = bucksPop.Scale,
	AspectRatio = 7, -- NormalButton wrapper ratio (D5)
	Native = { BackgroundTransparency = 1, Size = BUTTON_SIZE, LayoutOrder = 4 },
}, {
	Bucks = c(NormalButton, {
		PlusButton = true,
		Icon = "rbxassetid://13382286492",
		Position = UDim2.fromScale(0.5, 0.5), -- D5: wrapper is anchored (0.5,0.5)
		Size = UDim2.fromScale(1, 1),
		Color = Styles.GREEN_LIGHT,
		Text = shownBucks,
		OnClick = function()
			props.SetCurrentPage(UI.Pages.Shop, "Currency")
		end,
	}),
}),
```
5. Delete the whole `Points = c(NormalButton, {...})` child. Nothing else in the block changes.

## Studio checks (batched by Prime for Jack)
- S1: New join shows the balance with no pop. S2: a serve counts Bucks up over about 0.4 s and pops.
- S3: No Points button; Bucks still opens Shop Currency. S4: Clock Out then Cancel keeps the label; Clock Out in the dialog flips to Clock In and resets the shift; Clock In shows no dialog.
- S5: 844x390 phone aspect: Shift, Recipe Book and Bucks fully visible; the Bucks pill is the same height as Recipe Book and left-aligned with it (D5), and the pop does not shift the stack.

Open items: none (no asset needs; UI uses existing tokens only, phone 844x390 stays bottom-left)
## Summary
- BottomLeft.luau only: Bucks pop and count-up; Points hidden (data kept); Clock Out confirm.
- Client-only, no server, profile or asset change. Runtime unverified until Studio checks run.
