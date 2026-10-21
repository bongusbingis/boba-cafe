# BIG-B1-EXT verification (B1-EXT-VERIFY, gauge, 2026-10-21, branch uhweifh, commit 0b75279)

## Per-file verdicts (all PASS)
- `src/shared/Configuration/CustomerConfig.luau`: two appended ORDER_POOL entries match the
  P2 E3 exact block verbatim (Key/Label, Weight 8 + PROPOSED comment, MinLevel via
  `Progression.MIN_LEVEL_BY_ITEM`, Sized, OrderItem Category/Item/CustomInfo). Pool keys now
  exactly 7: Classic Milk Tea Boba, Regular Coffee, Fudge Brownie, Taro Syrup,
  Strawberry Syrup, Espresso, Mango Syrup. No Hot Cocoa / Strawberry Tapioca pool entry
  (remaining "Hot Cocoa(s)" hits are pre-existing PAY_TABLE/PATIENCE category aliases).
- `src/server/Tests/CustomerService.spec.luau`: append-only; 5 PickOrder cases + NewDrinksAt
  case match P2 E3 verbatim (L6 exclusion sweep, L7 Espresso, L7 Strawberry-below-Espresso,
  L8 Mango, L8 Espresso, ladder 7->{Espresso} / 8->{Mango Boba} / 6->{}).
- `src/server/Tests/RecipeBookContent.spec.luau`: one-line narrow
  (`Unlocks at` -> `Unlocks at Level 2`) + 3 appended cases match P3 E2 verbatim.
  `Content.luau` / `init.luau` untouched, as specified (data-driven, no edit needed).
- `packets/_meta/ECONOMY-LEDGER.md` (+2 rows): packet says the author (not builder) adds
  weight rows; present in commit, harmless.
- Not touched (per packet): Rules, ProgressionService, Menu, Progression, CustomerService/init,
  Npc, ActivityScript.server.luau (never opened), place content.

## Gap vs packet extension
- None functional. Minor evidence nits: `gate.txt` records selene 0 / stylua exit 0 / rojo
  built to b1ext.rbxlx but does not name the checked files; no per-packet summary.md existed
  (this file fills that). TestEZ recorded UNVERIFIED, which both packets permit without Studio.

## Gates re-run (read-only)
- `stylua --check` on all three committed files via wsl env: exit 0 (this session).
- Selene/rojo taken from gate.txt (not re-run; Studio not run per instructions).

## PATIENCE-RAMP CustomerConfig prerequisite: NOT CLEAR (lease ordering)
- PATIENCE-RAMP write_scope includes `CustomerConfig.luau` + `CustomerService.spec.luau`;
  TRIAGE-DEC058 states CustomerConfig is leased to B1-EXT: run PATIENCE-RAMP after B1-EXT
  (or move its 3 constants into Rules). No content conflict (extension never touches the
  PATIENCE_* block), but PATIENCE-RAMP's own `depends_on` omits B1-EXT, so Prime must
  enforce the order. Espresso/Mango need no new patience values (reuse Coffees / Boba Teas).
