# NPC-LOOK: NPC appearance, animations, dialogue; barista uniform
Model: sonnet   Studio: no   Depends on: M1.4e, IMPORT-V4 (dialogue), RIG-1 (imported assets)   Size: M

## Goal
NPCs look like the 10 dev-place customers, wave on arrival, look confused on a wrong drink, idle while waiting, and speak v4's lines. Baristas wear the Default uniform while clocked in. Settled by DEC-015 Q25 and the bonus line.

## Read (only these)
- `src/server/Modules/CustomerService/Npc.luau` lines 85-120 (`buildNpcModel`), 139-300 (bubble, `new`, states), and the wrong-serve hook added by M1.4e (grep `Wrong`)
- `src/server/Modules/CustomerService/init.luau`: the serve handler written by M1.4e (grep `ServePrompt`)
- `src/shared/Configuration/CustomerDialogue.luau` (whole)
- `tasks/REVIVAL-001/RIG-1/evidence.md`: child names of `NPCStorage.Animations`, `KitchenStorage.Assets` uniforms, and whatever lists `SharedStorage.NPCs`
- `src/server/Modules/ShiftService.luau` lines 36-62 and 86-100

## Write scope
- `src/server/Modules/CustomerService/Npc.luau`
- `src/server/Modules/CustomerService/init.luau` (hook calls only)
- `src/server/Modules/UniformService.luau` (new)

## Steps
1. **Look (Q25).** In `buildNpcModel`, replace the empty `HumanoidDescription` with a random child of class `HumanoidDescription` from `ReplicatedStorage.SharedStorage.NPCs` (resolve with `WorldPath.waitFor`, once at start; cache the list). Use `Players:CreateHumanoidModelFromDescription(desc:Clone(), Enum.HumanoidRigType.R15)`. If the folder has no descriptions, keep the current default body and `warn` once. Karen (`SharedStorage.NPCStorage.Karen`) is NOT used in M1; leave a comment `-- Karen: M2 variant`. Remove the `PENDING JACK Q25` comment.
2. **Animations.** Load the imported `NPCStorage.Animations` children named `Wave`, `Confused`, `Idle` onto the NPC `Animator` (`Humanoid:LoadAnimation` is deprecated: use `Animator:LoadAnimation`). `Idle` loops from `AtCounter` until `Leaving`. `Wave` plays once on reaching `AtCounter` (arrival). Expose `Npc.PlayConfused(self)` that plays `Confused` once; M1.4e's Wrong-serve branch calls it. A missing animation is skipped silently (DEC-015 Q23 style: missing stays silent, no substitutes). Every play inside `pcall`.
3. **Dialogue.** On arrival show one random `Greeting` line from `CustomerDialogue.Default` in the bubble as a second text line for 3 s; on a Wrong serve show one `WrongOrder` line for 3 s; on leaving (Happy or Sad) show one `Leaving` line for 3 s. Reuse the bubble's existing text style (Styles tokens already used in `buildBubble`). No new colours.
4. **Uniform.** New Knit service `UniformService`: subscribes to `ShiftService.ClockedInChanged`. On clock-in, record the character's `Shirt`/`Pants` templates (`ShirtTemplate`, `PantsTemplate`; create the instance if absent and remember that it was created), then set them to the templates of `SharedStorage.KitchenStorage.Assets.S_DefaultUniform` (`Shirt`) and `P_DefaultUniform` (`Pants`). On clock-out restore the recorded values (destroy instances that were created). On `CharacterAppearanceLoaded`/`CharacterAdded` while clocked in, apply again. On player leave, drop the records. All in `pcall`; a missing uniform asset warns once and skips.
5. `stylua` then `gate` on the three files.

## Done when
- The gate passes (RUNBOOK step 3).
- `grep -n "PENDING JACK Q25" src` returns nothing.
- Visuals and animations are UNVERIFIED; M1.6 captures them.

## Checks to run
- RUNBOOK step 3. Studio and Lens: NOT RUN.

## STOP-AND-ASK
- `NPCStorage.Animations` lacks `Wave`, `Confused` or `Idle` as instances: list what is there and ask.

## Evidence
`tasks/REVIVAL-001/NPC-LOOK/evidence.md` (add M1.6 capture steps: an NPC arriving, a wrong serve, a barista clocking in and out).
