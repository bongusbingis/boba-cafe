---
id: ONBOARD-NICK
title: Nickname prompt moves from first join to the end of the first shift, with Skip; remove stray print
priority: P1
role: Mason
worker_tier: haiku-ok
release_gate: before
depends_on: [SHIFT-END]
status: READY
source_commit: 098175c
read_scope: [src/server/Modules/DataService/PlayerSetup.luau, src/shared/UI/Components/Dialogs/TextInputPrompt.luau, src/server/Modules/ShiftService.luau (ShiftEnding signal and its summary.First field only), src/shared/Configuration/ShiftConfig.luau, src/server/Modules/ProgressionService.luau (line near 142, the ShiftEnding:Connect precedent only), src/shared/UI/Components/Buttons/PromptButton.luau]
write_scope: [src/server/Modules/DataService/PlayerSetup.luau, src/shared/UI/Components/Dialogs/TextInputPrompt.luau]
invariants: [serve-path no-yield: the ShiftEnding listener runs inside ShiftService:_endShift, which the serve chain reaches, so the listener only disconnects and calls task.delay (no yield, no service call, no DataStore); the PlayerSetup functions already run in task.spawn (DataService/init.luau:82-84) so the profile-time code may yield; ShiftService.luau is read-only in this packet; profile fields: no rename, no removal (Nickname and Playtime.FirstJoin are used as they are); DEC-013 (existing PromptButton and PromptTextBox only); DisplayName fallback is the existing behaviour]
acceptance: [a new profile shows no nickname prompt on join, the prompt appears about 8 s after the first shift ends (first shift = summary.First) and only when the shift card is closed, the prompt has Submit and Skip, Skip and an empty Submit leave Nickname unchanged and do not re-prompt, a whitespace-only Submit re-prompts with the existing invalid text, a second join never prompts again, the print line is gone from TextInputPrompt.luau, gate passes with no new Selene or StyLua findings in the two files]
checks: [scripts/gate.sh src/server/Modules/DataService/PlayerSetup.luau src/shared/UI/Components/Dialogs/TextInputPrompt.luau, rojo build default.project.json -o <scratchpad>/rojo-nick.rbxl]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/ONBOARD-NICK
forbidden: [see WORKER-PRIMER section 8, editing ShiftService.luau or ProfileTemplate.luau, adding a profile field, changing the 15-character limit, the filter, or the invalid-text copy, editing any other Dialog component, editing DialogService]
---

Rules: [WORKER-PRIMER](_meta/WORKER-PRIMER.md). Gate and evidence rules are there and are not repeated here.

## Source excerpt
O1 (review, HEAD c77e20c)
- What: Nickname after the first shift, with Skip (keeps DisplayName; still once per profile)
- Why: Design rule 1; revival plan 4.1 already says this
- Files: DataService/PlayerSetup.luau, Dialogs/TextInputPrompt.luau
- Effort: S
- Risk: Low
- Tag: JACK (join/play flow)

O4 (review, HEAD c77e20c)
- What: Remove the stray print in TextInputPrompt.luau:49
- Why: Output noise
- Files: TextInputPrompt.luau
- Effort: XS
- Risk: None
- Tag: OBVIOUS

## Decisions made
- D1 (O1): The nickname prompt is no longer shown at join. It is shown once the first shift ends. Rationale: Q-G3 (Jack), design rule 1.
- D2 (O1): The trigger is the existing server signal `ShiftService.ShiftEnding` (GoodSignal, fires `(player, summary)`, pattern already used at ProgressionService and CapsuleService). The listener acts only when `summary.First == true`. Rationale: `First` is `Completed == 0`, which is true only for the first shift of a profile; no ShiftService edit is needed, and no client signal can write the profile.
- D3 (O1): The listener disconnects once the prompt has been requested (not when it gives up on a still-open card), so the prompt is shown once per profile. Rationale: "still once per profile".
- D4 (O1): The prompt is shown `ShiftConfig.CARD_SECONDS_FIRST` (8) seconds after the signal, and only when the shift card is closed: if the player attribute `ShiftCardOpen` (set by SHIFT-END D11) is still true, retry every 1 s up to `CARD_WAIT_SECONDS` (30), then skip and keep the hook for the next ShiftEnding. Rationale: FIRST-5-MIN ordering rule 1; the prompt never covers the card.
- D5 (O1): Skip is a second button labelled `Skip` on the TextInputPrompt. Pressing it resolves with `""`. Rationale: dialogs resolve with data only (DialogService), so Skip is a string sentinel; Nickname stays `""` and the player keeps DisplayName.
- D6 (O1): On the server, a result of `nil` or `""` is a skip (no write, no re-prompt). A whitespace-only string keeps the existing invalid-nickname re-prompt. Rationale: an empty Submit and Skip are the same intent; whitespace is an error as today.
- D7 (O1): The listener is registered only inside the first-join branch (`FirstJoin == 0`), so existing profiles are never prompted. Rationale: "still once per profile"; profiles that joined before this change keep their behaviour.
- D8 (O1): The 15-character limit, filter, invalid-text copy and the `chooseNicknameRecursive` retry loop are unchanged. Rationale: no copy or rule change in this packet.
- D9 (O4): The line `print(textRef.current)` is deleted. Rationale: stray debug output.
- D11 (O1): While the prompt is pending or open the server sets `player:SetAttribute("NicknamePending", true)` and clears it (nil) on Skip, a successful Submit, give-up or player leave. SHIFT-END's capsule nudge waits on it. Rationale: the nudge must come after the prompt closes (FIRST-5-MIN rule 2).
- D10 (O1): `Skip` is shown only when the caller passes `SkipText`. The Roleplay Name prompt is the only caller that passes it. Rationale: no other dialog changes look.

## Exact strings
- Title: `Roleplay Name` (unchanged)
- Text: `Choose a roleplay nickname. This cannot be changed later, so choose wisely!` (unchanged; the code builds it as today through `formatBrackets`)
- PlaceholderText: `player.DisplayName` (unchanged)
- SkipText: `Skip`
- Invalid re-prompt texts: unchanged (`|Invalid nickname. Please try again.|`, `|Nickname must be 15 characters or less.|`, `|Nickname contains filtered content. Please try again.|`, `|An unexpected error occurred. Please try again.|`)

## Exact numbers
- Delay before the prompt: `ShiftConfig.CARD_SECONDS_FIRST` (8, existing value; read it, do not copy the number).

## Signatures and insertion points (anchor by symbol)
### PlayerSetup.luau
1. Top of file: add `local ShiftConfig = require(ReplicatedStorage.Shared.Configuration.ShiftConfig)` after the `Knit` require.
2. In the first function (the one with the comment `---> nickname setup`), keep the `MostRecentJoin` stamp and the `FirstJoin ~= 0` early return exactly. Keep `proxy.Data.Playtime.FirstJoin = current`.
3. Delete the line `task.delay(3, chooseNicknameRecursive)`.
4. Directly after `proxy.Data.Playtime.FirstJoin = current`, and after the local `chooseNicknameRecursive` definition, add:
```
task.defer(function()
	local ok, err = pcall(function()
		local connection
		local gaveUp = false
		connection = Knit.GetService("ShiftService").ShiftEnding:Connect(function(shiftPlayer, summary)
			if shiftPlayer ~= player or not (summary.First or gaveUp) then
				return
			end
			player:SetAttribute("NicknamePending", true)
			task.delay(ShiftConfig.CARD_SECONDS_FIRST, function()
				local waited = 0
				while player.Parent ~= nil and player:GetAttribute("ShiftCardOpen") == true and waited < CARD_WAIT_SECONDS do
					task.wait(1)
					waited += 1
				end
				if player.Parent == nil or player:GetAttribute("ShiftCardOpen") == true then
					gaveUp = true -- the hook stays for the next shift end
					player:SetAttribute("NicknamePending", nil)
					return
				end
				connection:Disconnect()
				chooseNicknameRecursive()
			end)
		end)
	end)
	if not ok then
		warn("[PlayerSetup] Nickname hook failed:", err)
	end
end)
```
   Define `local CARD_WAIT_SECONDS = 30` with the other locals. In `chooseNicknameRecursive`, clear `NicknamePending` in the skip branch, the success branch and the final failure branch, but not in the invalid-text re-prompt.
5. In the `:andThen(function(nickname)` body, make the first check:
```
if nickname == nil or nickname == "" then
	return -- Skip, or an empty Submit: keep DisplayName
end
```
   The existing `typeof(nickname) ~= "string" or nickname:gsub(" ", "") == ""` check stays as the next check and keeps its re-prompt.
6. Keep `CreateDialog(player, "TextInputPrompt", {...})` call shape; add `SkipText = "Skip"` to its props table.

### TextInputPrompt.luau
1. Props: add `SkipText: string?` to the props type (next to `PlaceholderText`).
2. Delete the line `print(textRef.current)`.
3. Layout when `props.SkipText` is nil: unchanged sizes (textbox 0.75 wide, Submit 0.25 wide). When it is set: textbox `UDim2.fromScale(0.5, 0.77)`, Submit `UDim2.fromScale(0.2, 0.77)`, and a third element.
4. LayoutOrder: textbox `1`, Submit `2`, Skip `3` (replace `math.huge`; the visual order is unchanged). Set it on every case.
5. Skip element, added to `buttonElements` only when `props.SkipText` is set:
```
c(PromptButton, {
	Text = props.SkipText,
	Size = UDim2.fromScale(0.2, 0.77),
	Color = Styles.CORAL,
	LayoutOrder = 3,
	OnClick = function()
		if closeFnRef.current then
			closeFnRef.current()
		end
		props.OnResolution("")
	end,
})
```
6. Submit with `SkipText` set: the existing OnClick is unchanged (it resolves `textRef.current`, which may be nil; the server handles nil as skip).

## UI spec
- Sizes and order as in insertion point 3. Buttons row keeps `HorizontalAlignment Center`, `Padding 0.05`, `Size (0.9, 0.4)`.
- Skip colour `Styles.CORAL` (style review: STYLE 3.3, CORAL = dismiss/leave as on ActionPrompt "Close" and "Leave Queue"; a `GRAY` fill is the disabled look in PromoCodes and would read as an inactive button). Skip is rightmost (STYLE 7, negative on the right). With `Color` passed, PromptButton strokes CORAL lerp black 0.15, thickness 3.
- Phone 844x390 (computed): the panel is height-bound at 0.4 x 390 = 156 px, width 156 x 2.23 = 348 px; button row 0.9 = 313 px. 0.5 + 0.2 + 0.2 plus two 0.05 gaps = exactly 1.0 of the row, so nothing overflows; Submit and Skip are about 63 x 48 px, "Submit" scales to about 14 px. Do not widen any element (the row is full).

## Studio checks (batched by Prime for Jack)
- S1: Join with a new profile. Expected: no Roleplay Name prompt on join.
- S2: Finish the first shift (5 customers as barista). Expected: the first-shift card shows, then about 8 s later the Roleplay Name prompt with a text box, Submit and Skip.
- S3: Press Skip. Expected: prompt closes; the profile Nickname is "" (check in profile); the overhead shows the DisplayName.
- S4: Rejoin and finish a second shift. Expected: no prompt.
- S5 (new profile): empty Submit acts as Skip; three spaces re-prompt with "Invalid nickname. Please try again."
- S6 (new profile): type `Ana` and press Submit. Expected: Nickname "Ana" in the profile, overheads show Ana.

## Asset prerequisites
None. Open items: none

## Summary
- Nickname prompt moves from join to 8 s after the first shift ends, only when the shift card is closed; sets NicknamePending so the capsule nudge waits.
- Skip button (SkipText prop); Skip and empty Submit keep DisplayName and never re-prompt; whitespace re-prompts.
- Files: PlayerSetup.luau and TextInputPrompt.luau only; stray print removed; no profile field.
- Runtime flow is unverified until Studio checks S1-S6 run.
