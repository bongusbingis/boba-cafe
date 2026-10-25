---
id: NPC-REACTIONS
title: NPC reactions: Wave on served leave, Confused at yellow patience, leaving lines by outcome
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [SERVE-FEEDBACK, SERVE-PAYPOPUP]
status: READY
source_commit: 098175c
read_scope:
  - src/server/Modules/CustomerService/Npc.luau (ANIMATION_NAMES, Npc.Leave, Npc._playTrack, Npc.PlayConfused, Npc._say, Npc._waitOutPatience)
  - src/shared/Configuration/CustomerDialogue.luau
  - src/server/Modules/CustomerService/init.luau (_onServeTriggered, the single npc:Leave("Served") call)
write_scope:
  - src/server/Modules/CustomerService/Npc.luau
  - src/shared/Configuration/CustomerDialogue.luau
  - src/server/Modules/CustomerService/init.luau (ONLY the one call npc:Leave("Served") gains a second argument)
invariants:
  - serve-path no-yield (WORKER-PRIMER 1): nothing yields between the serve guards and the payout in _onServeTriggered. This packet adds no code before the payout. The only init.luau edit is the argument of npc:Leave("Served"), which already runs after the payout, and Leave stays non-yielding (no task.wait, no WaitForChild, no service calls).
  - DEC-008: Wave and Confused are existing tracks; missing tracks are skipped silently, no substitute.
  - No UI, no economy values.
acceptance:
  - A served customer plays the Wave track once as it leaves (non-Karen, or Karen after a Perfect).
  - A customer plays Confused once when patience first reaches Yellow or lower, never twice per customer.
  - Served leaves say one of the six served lines; PatienceOut leaves say exactly "Wow... Ok...".
  - Karen after a Perfect says a served line; Karen after a Close or a walkout keeps her existing Karen.Leaving lines and the existing stomp.
  - Leave still returns without yielding and still calls Release and OnLeft in the same order.
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/CustomerService/Npc.luau src/shared/Configuration/CustomerDialogue.luau src/server/Modules/CustomerService/init.luau'"
  - rojo build default.project.json -o <scratchpad>/out.rbxlx
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/NPC-REACTIONS
forbidden: [WORKER-PRIMER 8, any edit to init.luau beyond the Leave argument, adding animations or sounds, changing PatienceState thresholds]
---

Primer: `_meta/WORKER-PRIMER.md` (rules, gate, evidence). Not repeated here.

## Source excerpt
S6 (review, HEAD c77e20c): What: NPC thanks you: play the existing Wave track on Leave("Served"). Why: The customer acknowledges you; it costs nothing. Files: Npc.luau Leave (after payout). Effort: XS. Risk: Low. Tag: OBVIOUS.

S7 (review, HEAD c77e20c): What: Leaving lines by outcome: served lines vs walkout lines, using existing lines only (split in 7, Q-G6). Why: "Wow... Ok..." after a perfect drink undercuts the moment; Karen threatening corporate after a Perfect is wrong. Files: CustomerDialogue.luau, Npc._say. Effort: XS. Risk: Low. Tag: JACK (content).

C2 (review, HEAD c77e20c): What: Impatience reaction: the NPC plays Confused once at yellow, and the bubble patience bar is already coloured. Why: Customer body language instead of UI-only urgency. Files: Npc._waitOutPatience (server, not on the serve path). Effort: XS. Risk: Low. Tag: OBVIOUS (existing animation; Karen-only "stomp" precedent).

## Decisions made
- D1. `Npc.Leave(self, reason: string, grade: string | nil)` gains an optional third parameter. Rationale: Npc has no other way to know the grade; optional keeps Destroy and _run callers unchanged.
- D2. `thanked = reason == "Served" and (self.Variant ~= "Karen" or grade == "Perfect")`. Rationale: Q-G6 says Karen after a Perfect uses the served lines; Karen after a Close keeps the stomp (Confused, played by init) and her own lines.
- D3. When `thanked`: play Wave (`self:_playTrack("Wave", false, Enum.AnimationPriority.Action)`) and say kind `"LeavingServed"`. Otherwise (walkout, Karen Close): say kind `"Leaving"` and play nothing new. `"Despawned"` still says nothing and plays nothing. Rationale: one branch, existing helpers.
- D4. Wave plays while the NPC walks to Exit (no hold added in `_run`). Rationale: no new waits; Wave is Action priority so it overrides the walk pose for its length.
- D5. CustomerDialogue splits the pools: `Default.Leaving` keeps only "Wow... Ok..."; new `Default.LeavingServed` holds the six served lines in current order; `Karen.Leaving` unchanged; new `Karen.LeavingServed` is the same six strings as `Default.LeavingServed`. Rationale: `_say` already picks the pool by Variant, so Karen needs no special code in `_say`.
- D6. C2: in `Npc._waitOutPatience`, a local `confusedPlayed = false`. Inside the branch that computes `remaining` (the non-Scripted branch), after `_setPatienceBar`, if `not confusedPlayed` and `Rules.PatienceState(remaining / self.PatienceTotal) ~= "Green"` then set `confusedPlayed = true` and call `self:PlayConfused()`. Rationale: "Yellow or lower" also covers a first observation that skips Yellow (pause correction); Scripted NPCs never tick so they never play it.
- D7. Call site: `npc:Leave("Served")` in `CustomerService:_onServeTriggered` becomes `npc:Leave("Served", grade)`. `grade` is the local already validated as "Perfect" or "Close". Nothing else in init.luau changes.
- D8. Animation validation: `ANIMATION_NAMES = { "Wave", "Confused", "Idle" }` in Npc.luau already lists both tracks. `resolveAssets` only checks that `ReplicatedStorage.SharedStorage.NPCStorage.Animations.<name>` exists and `IsA("Animation")`; the AnimationId is NOT validated in code. `_playTrack` wraps LoadAnimation and Play in pcall and skips when the Animation is missing, so a bad id is silent. Wave (AtCounter greeting in `_run`) and Confused (Wrong serve in init) already ship, so validation is not changed. Rationale: no guess on assets; id correctness is checked by Jack in Studio (S1, S2, S4 below).

- D9. Voice (FEEDBACK-VOICE 2, beat 4): the wave and leaving line happen on leave and make no sound; the walkout line stays exactly `Wow... Ok...`. Rationale: no sound for NPC reactions.

## Exact strings
`Default.LeavingServed` (verbatim, this order; keep the curly apostrophe in the last line as in the source):
"Cya later!", "Goodbye!", "Bye!", "Thanks, see ya!", "Later!", "I’m out, have a good one!"
`Default.Leaving` = { "Wow... Ok..." }
`Karen.LeavingServed` = the same six strings. `Karen.Leaving` = the existing seven lines, unchanged.
The file header comment gains one line: "LeavingServed = after a served order; Leaving = walkout (PatienceOut)."

## Exact numbers
None added. No tuning constants. SPEECH_SECONDS (3) unchanged.

## Signatures and event names
- `function Npc.Leave(self: Npc, reason: string, grade: string?)`
- Leave body order after the edit: Left guard, `self.Left = true`, `_setState("Leaving")`, `_stopTrack("Idle")`, then if `reason ~= "Despawned"`: compute `thanked`, `if thanked then self:_playTrack("Wave", false, Enum.AnimationPriority.Action) end`, `self:_say(if thanked then "LeavingServed" else "Leaving")`; then `self._ctx.Release(self)`, `self._ctx.OnLeft(self, reason)`.
- If the Npc type declares Leave, update its signature to match.
- No new remotes, attributes, signals or profile fields.

## UI spec
None. The line shows in the existing OrderBubble Speech label via `_say`.

## Studio checks (Jack, batched)
- S1: Serve a normal NPC a Perfect drink. Expect the customer waves once while leaving and says one of the six served lines, never "Wow... Ok...".
- S2: Let a normal NPC wait until its bar turns yellow. Expect one Confused animation, not repeated as the bar goes red. Then let it walk out: expect exactly "Wow... Ok..." and no Wave.
- S3: Serve a Karen a Perfect: served line and Wave. Serve a Karen a Close: stomp and a Karen line, no Wave. Let a Karen walk out: a Karen line.
- S4: Output shows no new warnings. If Wave or Confused does nothing, read the AnimationId of `ReplicatedStorage.SharedStorage.NPCStorage.Animations.Wave` and `.Confused` and report to Prime (HARD STOP 1 territory).
- S5: Serve payout, toast and "+N" popup timing are unchanged versus before the packet.

## Asset prerequisites
Existing instances only: `ReplicatedStorage.SharedStorage.NPCStorage.Animations.Wave`, `.Confused`, `.Idle` (place file, not Rojo). If missing the code skips silently (already the behavior). Not verified in Studio during packet writing.

Open items: none

## Summary
- Npc.Leave takes the serve grade; served leaves wave and use new LeavingServed lines.
- Walkouts keep only "Wow... Ok..."; Karen after a Perfect counts as served, after a Close keeps stomp and her lines.
- Confused plays once when patience first leaves Green, in _waitOutPatience (off the serve path).
- One-argument edit in CustomerService/init.luau (Leave call, after payout); no yields added.
- AnimationIds are not code-validated (existence check only); Jack verifies in Studio.
- Lease note: adds a tiny write to init.luau; must follow SERVE-PAYPOPUP and precede PATIENCE-RAMP.
