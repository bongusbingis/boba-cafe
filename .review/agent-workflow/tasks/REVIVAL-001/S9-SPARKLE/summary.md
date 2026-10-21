# S9-SPARKLE — evidence summary

Perfect-serve sparkle, server side, in `Npc.Leave` only (branch `uhweifh`).

## Change

`src/server/Modules/CustomerService/Npc.luau` (+26 lines, no other files):

- In `Npc.Leave`, when `grade == "Perfect"`: resolve the shared template with
  `WorldPath.find` (synchronous, no yield), clone it, parent the burst to the
  NPC `Head` (fall back to `Root`), `Emit(30)`, `Debris:AddItem(burst, 3)`.
- Missing template or wrong class: skip silently with one `warn`, never build
  a substitute.
- Supporting scaffolding in the same file only: `Debris` service local,
  `SPARKLE_COUNT = 30` / `SPARKLE_CLEANUP_SECONDS = 3` (same numbers as
  `Spill`), one `sparkleWarned` flag.

No client changes, no sounds, no economy. `ActivityScript.server.luau`
untouched. Nothing committed or pushed; no Studio/Play/TestEZ run (DEC-019).

## Verification

- `gate src/server/Modules/CustomerService/Npc.luau` → PASS (see
  `gate-output.txt`): selene new=0, stylua ok, rojo build ok.
- `git diff` on `Npc.luau` shows only the Perfect branch plus its scaffolding.

## Studio checks for Jack (batched)

- Serve a Perfect: short sparkle burst at the NPC head; serve a Close: none.
- Temporarily rename `CleanlinessStorage.Sparkles`: serve still works, one
  warn, no errors.
