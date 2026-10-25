---
id: NOTIF-HINTS
title: Remove seven false lines from the rotating HINTS toast list
priority: P1
role: Mason
worker_tier: haiku-ok
release_gate: before
depends_on: [GAMEPLAY-TOASTS]
status: READY
source_commit: 098175c
read_scope: [src/shared/UI/Components/Core/Hud/SmallNotification.luau]
write_scope: [src/shared/UI/Components/Core/Hud/SmallNotification.luau]
invariants: [client-only UI, no serve path touched, HINTS entries are data only (no logic change), the 60 s rotation loop and the Push API are unchanged, DEC-013 (no new token)]
acceptance: [HINTS holds exactly the 12 entries listed under "Exact strings" in the order given, no other line of SmallNotification.luau changes, gate passes with no new Selene or StyLua findings in SmallNotification.luau]
checks: [scripts/gate.sh src/shared/UI/Components/Core/Hud/SmallNotification.luau, rojo build default.project.json -o <scratchpad>/rojo-notif.rbxl]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/NOTIF-HINTS
forbidden: [see WORKER-PRIMER section 8, editing any other line of SmallNotification.luau (GAMEPLAY-TOASTS and SOUNDS own the rest), adding or rewording any hint, adding a new hint]
---

Rules: [WORKER-PRIMER](_meta/WORKER-PRIMER.md). Gate and evidence rules are there and are not repeated here.

## Source excerpt
N4 (review, HEAD c77e20c)
- What: Hint copy cleanup: drop the false lines (Staff points, Barista donation role, ranked or promoted, Celebrity tab, Fun Pass, "auto hatch"); keep group, like/favourite, inventory, hatch steps, quests and explore
- Why: False advice erodes trust
- Files: SmallNotification.luau:41-61
- Effort: XS
- Risk: Low
- Tag: JACK (copy about products and rewards)

## Decisions made
- D1: Delete exactly the seven entries listed under "Entries to delete". Rationale: each one names a product, role or rank path that the plan retires or that no longer exists (Q-G9, DEC-053).
- D2: The Boba Bucks purchase entry (entry 2 under "Entries to delete") is deleted in full, not reworded. Rationale: rewording would be new copy, and that hint is not restored without Jack's words.
- D3: All other entries stay, character for character, including their trailing spaces. Rationale: the packet changes no copy it did not have to.
- D4: The rotation is unchanged. The list shrinks from 19 to 12 entries, so each hint shows about every 12 minutes. Rationale: the loop reads `#HINTS` implicitly through `for _, hint in HINTS`, so no code change is needed.

- D5 (FEEDBACK-VOICE 7): hints rotate only when the toast queue is empty. The rule is built by GAMEPLAY-TOASTS step 4 (hint loop skips its turn while a toast is active or queued, or a non-hint toast started under 20 s ago); this packet changes no code for it. The welcome toast is a non-hint toast, so hints stay silent behind it. Hints make no sound (SOUNDS).

## Entries to delete (match the text exactly)
1. `Interested in being a Celebrity? Check out the Celebrity tab in our Shop!`
2. `Can't wait any longer? Purchase Boba Bucks or Staff points in our Shop! ` (trailing space)
3. `Want to become an instant staff member? Purchase the Barista donation role in our Shop above!`
4. `Need access to our fun water items? Rent our Fun Pass in our Shop!`
5. `Want to get promoted as a Barista? Work to gain points!`
6. `How to get promoted? When you reach a certain amount of points you will be automatically ranked!`
7. `Is hatching taking too long? Purchase the auto hatch product!`

## Exact strings (HINTS after the edit, in order; 12 entries)
1. `Join our group for a FREE pet!`
2. `Having fun? Be sure to leave a like and favorite on our game!`
3. `Join our group for 20 Boba Bucks!`
4. `Want exclusive perks and items? Check out our Shop located above! ` (trailing space)
5. `Can't find the pet or trail purchases you made? Check the inventory tab above! ` (trailing space)
6. `Boba Cafe is owned by Flez_ent!`
7. `Want to become one of the top pet owners? Play our game and earn Boba Bucks every minute!`
8. `Need help? Find one of our moderation staff members around the cafe!`
9. `Want to know more about updates? Join our communications server for more information!`
10. `To hatch your pet, go to your inventory, click capsules, choose a capsule, and click hatch!`
11. `Don't forget to explore the island!`
12. `Complete quests and unlock new badges!`

## Exact numbers and names
- Unchanged: `HOLD_DURATION`, `SPRING_SLIDE`, `SPRING_FADE`, the 60 s wait in the HINTS loop.

## Signatures and insertion points
- Only the body of `local HINTS = { ... }` (SmallNotification.luau, currently lines 41-61). Delete the seven lines in "Entries to delete". Do not touch any other line.

## UI spec
- None. Text-only edit to a data table.

## Studio checks (batched by Prime for Jack)
- S1: Wait for the hint rotation (60 s per entry). Expected: none of the seven deleted lines appears in any hint toast over at least 12 minutes of play.
- S2: Trigger a serve toast during play. Expected: the serve toast still shows and is not replaced by a hint mid-hold (GAMEPLAY-TOASTS behaviour, unchanged here).

## Asset prerequisites
- None.

Open items: none

## Summary
- Deletes seven false hint lines from SmallNotification.luau HINTS.
- Keeps 12 entries, in order, with trailing spaces as they are.
- No logic, token, or timing change.
- Depends on GAMEPLAY-TOASTS (same file).
- Gate: scripts/gate.sh on SmallNotification.luau; rojo build. Hints show only on an empty queue (D5, GAMEPLAY-TOASTS).
- Runtime rotation is unverified until Studio check S1 runs.
