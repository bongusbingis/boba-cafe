---
id: SHIFT-STARS-SOUND
title: Star jingle on the end-of-shift card: one to three rising notes by star count
priority: P2
role: Mason
worker_tier: haiku-ok
release_gate: after
depends_on: [GAMEPLAY-PROGRESS-CALLOUTS, SHIFT-END]
status: READY
source_commit: 098175c
read_scope: [src/shared/UI/Components/Core/Hud/ShiftCard.luau, src/shared/Utility/WorldPath.luau, src/client/Modules/AppDialogs.luau, src/server/Modules/ShiftService.luau]
write_scope: [src/shared/UI/Components/Core/Hud/ShiftCard.luau (playStarJingle helper and the ShiftEnded handler only)]
invariants: [client UI only (no serve path, no server file), skip silently when the sound is missing (never error, never block the card), no new token, component or visual, no economy change]
acceptance:
  - When ShiftEnded delivers a summary with Stars = N (1 to 3), the client plays N notes at PlaybackSpeed 1.0, 1.2599, 1.4983 with 0.2 s between notes.
  - Stars 0 or a missing Stars plays nothing.
  - A missing SoundService.SFX.UI.StarNote (and UISounds fallback) plays nothing and raises no error.
  - No new Styles token, component, sound file or instance is created by code.
checks: [scripts/gate.sh on ShiftCard.luau (Selene, StyLua --check, no new findings); rojo build default.project.json -o <path outside repo>]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/SHIFT-STARS-SOUND
forbidden: [WORKER-PRIMER 8, creating or cloning a sound asset in Rojo or the place file, substituting SFX.UI.Success or any other sound for StarNote, editing ShiftService.luau or any server file, editing AppDialogs.luau]
---

Worker rules: link `.review/agent-workflow/tasks/REVIVAL-001/packets/_meta/WORKER-PRIMER.md` (sections 1-10). Source commit 098175c. Anchor by symbol name.

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- H2 (review, HEAD c77e20c): What: Star jingle on the card (1-3 rising notes). Why: The session-end moment deserves audio. Files: client; needs authored sounds. Effort: XS + Studio. Risk: Low. Tag: JACK.

## 2. Decisions made
- D1 One sound asset is requested: `SoundService.SFX.UI.StarNote`, one short rising note, authored by Jack. Rationale: a single note sound is reused at pitch steps, so Jack authors one file, not three.
- D2 Note k (k = 1, 2, 3) plays `StarNote` with `PlaybackSpeed = STAR_NOTE_SPEEDS[k]`. Rationale: 1.0, 2^(4/12) and 2^(7/12) are the root, major third and fifth, so three stars sound like a rising chord arpeggio.
- D3 The number of notes equals `Stars` (clamped 1 to 3). Rationale: the review text says 1 to 3 notes by star count.
- D4 Notes are spaced `STAR_NOTE_GAP = 0.2` seconds in a `task.spawn`. Rationale: short enough to read as a jingle, long enough to hear each note.
- D5 Each note is a `Clone()` of the authored sound, so overlapping playback is never cut off. Clones are removed with `Debris:AddItem(note, 3)`.
- D6 Lookup mirrors `AppDialogs.playUiSound`: `SFX.UI.StarNote` first, then `UISounds.StarNote`. A missing sound plays nothing (silent skip). Rationale: DEC-054 and the brief; never a substitute sound.
- D7 The jingle fires from the existing `ShiftEnded` listener, after `setSummary(newSummary)`. Rationale: the card and the sound appear together; no new remote.
- D8 Status READY: the code is inert until Jack authors `StarNote`. Rationale: the brief sets this status for H2.

## 3. Exact strings
None. No text is added.

## 4. Exact numbers
- `STAR_NOTE_SPEEDS = { 1, 1.2599, 1.4983 }` (index = note number)
- `STAR_NOTE_GAP = 0.2` (seconds)
- `STAR_NOTE_MAX = 3`
- `STAR_NOTE_LIFETIME = 3` (Debris seconds)

## 5. Signatures and names
- `local function playStarJingle(stars: any)` in `ShiftCard.luau`, placed after `buildLines` and before the `---> Component` marker.
- Sound path: `{ "SFX", "UI", "StarNote" }` and fallback `{ "UISounds", "StarNote" }`, through `WorldPath.find(SoundService, path)`.
- Services and requires added to `ShiftCard.luau`: `local SoundService = game:GetService("SoundService")`, `local Debris = game:GetService("Debris")`, `local WorldPath = require(Shared.Utility.WorldPath)` (the `Shared` local already exists in the file).

## 6. Code shape
```lua
local function playStarJingle(stars: any)
	if typeof(stars) ~= "number" then
		return
	end
	local count = math.clamp(math.floor(stars), 0, STAR_NOTE_MAX)
	if count < 1 then
		return
	end
	task.spawn(function()
		for index = 1, count do
			pcall(function()
				local sound = WorldPath.find(SoundService, { "SFX", "UI", "StarNote" })
					or WorldPath.find(SoundService, { "UISounds", "StarNote" })
				if sound and sound:IsA("Sound") then
					local note = sound:Clone()
					note.PlaybackSpeed = STAR_NOTE_SPEEDS[index]
					note.Parent = sound.Parent
					note:Play()
					Debris:AddItem(note, STAR_NOTE_LIFETIME)
				end
			end)
			if index < count then
				task.wait(STAR_NOTE_GAP)
			end
		end
	end)
end
```
ShiftEnded handler, in the existing `React.useEffect` that connects `ShiftService.ShiftEnded`:
```lua
local conn = Knit.GetService("ShiftService").ShiftEnded:Connect(function(newSummary)
	setSummary(newSummary)
	playStarJingle(if typeof(newSummary) == "table" then newSummary.Stars else nil)
end)
```
Constants block (top of file, after `local BORDER_IMAGE = ...`):
```lua
local STAR_NOTE_SPEEDS = { 1, 1.2599, 1.4983 } -- PlaybackSpeed for note 1, 2, 3 (root, major third, fifth)
local STAR_NOTE_GAP = 0.2
local STAR_NOTE_MAX = 3
local STAR_NOTE_LIFETIME = 3
```

## 7. UI spec
No visual change. The card and its rows are unchanged.

## 8. Studio checks (batched by Prime for Jack; workers do not run Studio)
- S1: With no `StarNote` in `SoundService.SFX.UI`, end a shift. Expected: the card appears as today, no error in Output.
- S2: Author `SoundService.SFX.UI.StarNote` (Jack). End a shift with 1 star. Expected: one note.
- S3: End a shift with 2 stars. Expected: two notes, the second higher and spaced about 0.2 s.
- S4: End a shift with 3 stars. Expected: three rising notes.
- S5: Check the Explorer during a jingle. Expected: clones appear in `SFX.UI` for about 3 s and are removed.

## 9. Asset prerequisites
- Sound: `SoundService.SFX.UI.StarNote` (a `Sound`, short rising note). Authored in the place file, not in Rojo. Requested from Jack.
- Fallback folder: `SoundService.UISounds.StarNote` (existing fallback pattern; optional).
- Missing sound: silent skip, no error, no warning.

## 10. Dependency note
`ShiftCard.luau` has three planned writers: GAMEPLAY-PROGRESS-CALLOUTS (buildLines), SHIFT-END (H4) and this packet. This packet must run after both. SHIFT-END is now in `packets/` and listed in depends_on.

Open items:
- HARD-STOP 1: Jack, author `SoundService.SFX.UI.StarNote` (answer: yes or no). Until it exists the code is inert and status stays READY.

## Summary
- Adds `playStarJingle(stars)` to ShiftCard: plays 1 to 3 clones of one sound at PlaybackSpeed 1.0, 1.2599, 1.4983, 0.2 s apart.
- Called from the existing ShiftEnded listener right after the summary is set.
- Sound lookup mirrors `AppDialogs.playUiSound`; a missing sound is skipped silently.
- Requested asset: `SoundService.SFX.UI.StarNote` (Jack). No substitute sound is used.
- Client UI only; no server, economy or serve-path change; no visual change.
- Runtime checks S1-S5 are for Jack.
