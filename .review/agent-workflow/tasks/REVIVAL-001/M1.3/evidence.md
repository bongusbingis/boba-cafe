RESULT: PASS

# REVIVAL-001 / M1.3a + M1.3b (Mason)

Scope: M1.3a and M1.3b only, as written in M1.2/design.md section 9, implementing M1.1/design.md sections 2, 4, 6.4 and the 23 cases. M1.3c/d not touched. Not committed. No Studio run. TestEZ is still pending (one batched Gauge pass).

## Source state

- HEAD: `92f6144` (working tree is dirty with other agents' uncommitted edits).
- sha256 of the 5 write-scope files, after the last edit:

```
09e1ac6bdaddbbc6b57d02e709a73ec1d4c7881d7b832f8414ac4e001e0cb607  src/shared/Ordering/OrderSpec.luau            (new)
1b0b2e646ce79de70ac81569b53db710852f1085ef5401a99898e19084ff29db  src/server/Tests/OrderSpec.spec.luau          (new)
93687cc66e3cc19f60441faec607065449146745a36e706866e5a8a591774a22  src/shared/Ordering/Menu.luau                 (+6 lines)
4fb716ba989989ce6fedd942eaf9051c170363a1fc90183863040bfbf3dbffe3  src/shared/UI/Pages/MobileOrder/init.luau     (NOT edited by me)
300afd07cf7596c52e4294ed22da9410dc42b8c768aa2031d466f91743e2717c  src/shared/UI/Pages/Ordering/init.luau        (NOT edited by me)
```

## What changed

- `src/shared/Ordering/OrderSpec.luau` (new, `--!strict`, 296 lines). Exports types `Grade` and `OrderSpec`, and `FromMenuItem`, `FromOrderItem`, `Match`, `PickTools` exactly as the M1.1 section 2 signatures and section 4 rules. `Menu` is required lazily (pcall, warn once) inside `FromOrderItem`, so the rest of the module is usable without `SelectorModels`.
- `src/server/Tests/OrderSpec.spec.luau` (new). 54 `it` blocks: the 23 M1.1 cases (named `case 1` to `case 23`) plus extras: FromOrderItem on the 3 slice items and a MobileOrder-shaped order item (forged `DefaultInfo` is ignored), reject paths, Menu `ServeItem` data. Cases 19 to 23 and the FromOrderItem block use the real `Menu` (as `OrderService.spec` does); if Menu cannot load, only those fail.
- `src/shared/Ordering/Menu.luau`: `ServeItem` added to `Custom Boba` ("Boba"), `featuredMatcha` ("Boba"), Mochis > `Orange Cream` ("Orange Mochi"), Others > `Cup` ("Clear Cup"), plus a 2-line comment. No prices, sizes or other data changed.
- `MobileOrder/init.luau` and `Pages/Ordering/init.luau`: **no edit needed.** `Category = selectedCategory` (MobileOrder line 204) and `Category = selCategory` (Ordering line 233) are already in the working tree as part of other agents' uncommitted order-hardening edits (they are in `git diff` against HEAD, not in HEAD). I left those files byte-identical. Note: if that other work is reverted or not committed, M1.3b's Category part goes with it.

## Gate

`scripts/gate.sh` on the 5 files:

```
PASS  src/shared/Ordering/OrderSpec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/OrderSpec.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/shared/Ordering/Menu.luau  selene new=0 (baseline[HEAD]=1 now=1)  stylua=ok
PASS  src/shared/UI/Pages/MobileOrder/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=pre-existing stylua drift
PASS  src/shared/UI/Pages/Ordering/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=pre-existing stylua drift
PASS  rojo build -> $TMPDIR/gate-build.rbxl
GATE: PASS
```

## Out-of-Studio sanity run (not the acceptance test)

`lune` is not in the project manifest (`lune` shim fails), so I ran the installed binary directly (`~/.rokit/tool-storage/lune-org/lune/0.10.5/lune`) with a throwaway harness in the session scratchpad (not in the repo). It loads the real `Menu.luau` (Instances faked by a proxy), the real `OrderSpec.luau`, and the real spec file under a minimal describe/it/expect shim.

- Result: `passed=54 failed=0`.
- Negative check: mutating the Iced comparison made 3 tests fail, so the harness is not vacuous.
- This does NOT replace TestEZ in Studio (the shim is mine; real `Menu` Instances and TestEZ's `expect` were not exercised). M1.3a/b acceptance ("passes in TestEZ (Gauge)") stays UNVERIFIED until the batched pass.

## Pending-Jack constants

None. The 23 cases and the FromOrderItem checks do not depend on Q3 (Blender/Lid/sizes) or Q14 (attribute-based gates). Match does not read any Blender or Lid attribute. If Q3 makes the Blender required, that is the `Blended=true` delta already noted in M1.2 for M1.3c.

## Interpretations I made (not covered by the M1.1 text; none affects the 23 cases)

1. `Iced` / `Sugar`: an absent choice takes the `def.Options` default (as the M1.1 text says). A present non-boolean value is rejected with `nil, "Iced"` (or `"Ice"` / `"Sugar"`), following "any invalid input returns nil, field". The M1.1 sentence "must be a boolean; otherwise use the default" could also be read as "non-boolean falls back to the default". The server's existing `buildOrderItem` already rejects non-boolean options, so both readings behave the same on its output. Easy to flip in `readOption` if you want the other reading.
2. `PickTools` with exactly one spec and an empty candidate list returns `nil, "Wrong", {"Missing"}` (there is no first candidate to Match against). Zero specs returns `{}, "Perfect", {}`.
3. `FromOrderItem` treats a nil `CustomInfo` as `{}` (same as `buildOrderItem`); a non-table is `nil, "CustomInfo"`. Failure reasons from `FromOrderItem` may also be `"Category"`, `"Item"`, `"Menu"`.
4. `Label` = `Size .. " " .. def.ItemName` for Drinks, `def.ItemName` for Grabs (the staff-screen format; only `Select.Size` exists in the current Menu). Syrup and tapioca are not in the label, so spec A's label is "Medium Custom Boba".
5. `Kind` is "Drink" only when `def.Select.Size` is a table; the Matcha Tea Boba and Cup are therefore Drinks and Hot Cocoa is a Drink with Size "Mug".

## Risks and notes for later tasks

- `Match` on a Grab item only checks `Item`. A Grab spec ignores `Size` even if a tool carries one (per section 4, step 2).
- This task set only the 4 `ServeItem` fields the design lists. For every launch item, the `Item` attribute a station writes (M1.3c) must equal `ServeItem or ItemName` from the Menu. I did not check the recipe side (UNVERIFIED).
- `OrderService.buildOrderItem` (M1.3d scope) does not call `FromOrderItem` yet.
