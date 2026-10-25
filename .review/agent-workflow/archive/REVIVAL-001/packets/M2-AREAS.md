> **Prime override (DEC-021):** the Rigger proposes the desert wall line with one capture for Jack, and builds only after Jack says yes.

# M2-AREAS: limit where a new player goes (Rigger)
Model: sonnet (Rigger lane)   Studio: yes   Depends on: M2-PROGRESS (player attribute `Level`)   Size: M

## Goal
The cafe is open from the start. The break areas look closed with a sign until Level 3. The far desert cannot be walked to. Nothing existing is deleted. Settled by DEC-011 (Q20), DEC-005, design §8.

## Read (only these)
- `M1.2/design.md` lines 411-422 (§8)
- `AGENTS.md` "Boundaries" (place content needs a Rigger and exact paths)
- `src/client/Modules/KitchenController.luau` lines 1-60 (client controller shape to copy)
- `src/shared/Configuration/ProfileTemplate.luau` (no edit; `Level` exists after M2-PROGRESS)
- Studio (read-only first): `workspace` top level, `workspace.Assets`, `workspace.OldScriptables` (names only, to find the break areas)

## Write scope
- `src/client/Modules/AreaController.luau` (new)
- Place file (Studio, `BuiltBy = "M2-AREAS"` on every new instance): `ReplicatedStorage.AreaLimits.BreakGates` (new folder of invisible gate parts and sign templates), `workspace.Assets.AreaLimits.DesertWalls` (new folder)
- No other files. Never delete or move existing instances.

## Steps
1. **Studio (once).** Find the entrances of the break areas listed in §8: rooftop pool, basement lounge, outdoors including Sakura Island, the pool and slide, and the canoes. For each entrance create one `Part` in `ReplicatedStorage.AreaLimits.BreakGates`, named `Gate_<Area>`: `Transparency = 1`, `CanCollide = true`, `Anchored = true`, sized to fill the doorway or path, attribute `BuiltBy = "M2-AREAS"`. Add a child `SurfaceGui` facing the cafe side with one `TextLabel` "Break Area · opens at Level 3" using `Styles` colours (`OFFWHITE` text, `Styles.FONT_FREDOKA`, `TextScaled`). Record every part's CFrame and size in the evidence. If an entrance is not a clear doorway or path, STOP-AND-ASK (below).
2. **Desert walls.** Propose the boundary line only (list of wall segments: CFrame and size, drawn on a capture) in the evidence. Do NOT build until Jack approves the line (design §8). After approval, build the segments under `workspace.Assets.AreaLimits.DesertWalls` (`Transparency = 1`, `CanCollide = true`, `Anchored = true`, `BuiltBy`), server-side, permanent.
3. **AreaController.luau (client).** `Knit.CreateController`, `Name = "AreaController"`. On start: wait for `ReplicatedStorage.AreaLimits.BreakGates` (10 s `WorldPath.waitFor`-style deadline; if missing, warn once and do nothing: the player must never be blocked or kicked). Function `refresh()`: if `LocalPlayer:GetAttribute("Level") or 1 < 3`, clone every gate into `workspace.AreaLimitsLocal` (create it) once; else destroy that folder. Connect `LocalPlayer:GetAttributeChangedSignal("Level")` to `refresh`. Constant `OPEN_LEVEL = 3` at the top (Q20; design §5.3 L3).
4. The server does no check for the break areas: design §8 says a player who slips past is harmless. (The packet request mentioned a server check; the design says no. Recorded in evidence.)
5. Save the place (File > Save to Roblox). Never publish. `stylua` then `gate` on `AreaController.luau`.

## Done when
- With `Level < 3` a player is stopped at every break-area entrance and sees the sign; at Level 3 the gates vanish without rejoining.
- The desert cannot be entered (after Jack's approval of the line).
- Nothing existing was deleted or moved; new instances carry `BuiltBy`.
- Gate passes on `AreaController.luau`.

## Checks to run
- RUNBOOK step 3 and the Studio steps above. Never Play-test (DEC-019). Test for Jack: join on a fresh profile, walk to the pool, reach L3, walk again.

## STOP-AND-ASK
- Desert boundary line: Jack must approve the proposed segments before they are built.
- An entrance of a break area is not a clear path or doorway, or an area named in §8 is not found in the place: BLOCKED, report what was searched (DEC-008).
- Does the "Cafe" zone include the basement stairs (needed to reach the lounge) and the pool deck? Ask Jack if a gate would trap a player.

## Evidence
`tasks/REVIVAL-001/M2-AREAS/evidence.md` (RUNBOOK step 5). Include every created instance path.
