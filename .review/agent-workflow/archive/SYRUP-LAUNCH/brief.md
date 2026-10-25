# SYRUP-LAUNCH — all 19 station syrups player-orderable (session 2026-10-22)

Direct Jack request ("I want to use the available content").

Change: `src/shared/Ordering/Menu.luau` `LAUNCH_CHOICES["Syrup Flavor"]`
8 -> 19 (added Strawberry Banana, Coconut, Chocolate Banana, Thai Milk Tea,
Watermelon, Lychee, Green Tea, Raspberry, Cherry, Guava, Dragon Fruit).
Every added flavor has a working dispenser (server clones all
Recipes.Syrups; all 19 models confirmed in the dev place).

Deliberately untouched (needs Jack tuning/approval):
- NPC ORDER_POOL still orders 4 syrups (pool weights are probabilities).
- LAUNCH_CHOICES tapioca still 4 of 10 (same one-list treatment available).
- Rejection specs unaffected (Almond/pumpkin cases still off-menu).

Gate: PASS (Selene new=0, StyLua ok, rojo build ok). TestEZ run is Jack's (DEC-019).

## Provisionals, 2026-10-22 (both, per Jack)
- Tapioca LAUNCH_CHOICES 4 -> all 10 (stations + dev-place models already exist).
- ORDER_POOL +18 entries (15 syrups, 3 tapioca-on-classic), all Weight 1:
  weight 1 is forced by the CLASSIC_MIN_SHARE law (test-pinned at every
  level; 18 newcomers at weight 2 would drop classics to ~0.58 at L15).
  Newcomers will be rare until Jack tunes weights/share.
- MIN_LEVEL_BY_ITEM +11 keys (Coconut/Green Tea 3, Strawberry Banana/Lychee 4,
  Chocolate Banana/Thai 9, Watermelon/Raspberry 10, Cherry/Guava/Dragon 12).
- Specs updated to the bigger pool: CustomerService ladder (NewDrinksAt 3/8),
  RecipeBookContent (L7/L8 rewrites + L15 test), OrderService rejection case
  (Pumpkin Paradise is launch now; unknown "Rainbow" tapioca instead).
- Gate re-run on all six files: PASS. TestEZ run is Jack's (DEC-019).
- Executed data cross-checks (PowerShell over real file contents): 25 pool
  entries, unique keys/labels, every MinLevel ref resolves to a Progression
  key, worst classic share 0.649 at L15+ (law holds), per-level label lists
  match the updated specs exactly, all 19 launch syrups + 10 tapiocas
  confirmed in Menu and Recipes, Rainbow absent from launch.
- TestEZ itself NOT run here: Studio is in Edit mode and Play/TestEZ runs
  are Jack's per DEC-019 (agents author/save only).
