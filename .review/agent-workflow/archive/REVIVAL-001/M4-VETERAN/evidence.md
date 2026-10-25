RESULT: PASS
Files changed:
- src/server/Modules/BadgeService.luau
- src/client/Scripts/PlayerOverheads.client.luau
- src/server/Tests/BadgeService.spec.luau

Gate check output:
```
PASS  src/server/Modules/BadgeService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/client/Scripts/PlayerOverheads.client.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/BadgeService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

Notes on behavior:
- `BadgeService.luau`:
  - Defined `LEGACY_BADGES` array exposing all 14 pre-revival badge IDs: Welcome (2124469255), MetTheOwner (2124491880), MetTheCoOwner (2124640228), MetADeveloper (2124640227), FirstQuest (2124640229), FirstStaff (2124640230), Celebrity (2124640231), SakuraIsland (2124640232), TreasureChest (2124774045), ShinyPet (2124774046), HalloweenEvent (2124837610), Slipped (2150110926), FirstPaycheck (2150110897), LevelUp (2150110948). Also exposed as `Service.LEGACY_BADGES`.
  - Added `CheckVeteranStatusAsync(player: Player): boolean`: iterates legacy badges and checks `UserHasBadgeAsync` wrapped in `pcall`. On true, sets `player:SetAttribute("IsVeteran", true)`, updates badge ownership cache, and returns true. Short-circuits if `IsVeteran` attribute is already true. Supports mockable `Service._badgeService` for unit testing.
  - Connected `CheckVeteranStatusAsync(player)` in a spawned task on `Players.PlayerAdded` (and existing players on `KnitStart`).
- `PlayerOverheads.client.luau`:
  - Updated `refreshTitle()` to read `player:GetAttribute("IsVeteran") == true` alongside `player:GetAttribute("LevelTitle")`.
  - Formats title text per specification: `"Veteran • " .. levelTitle` if both exist, `"Veteran"` if veteran only, `levelTitle` if level title only, or `""` if neither.
  - Listens to both `GetAttributeChangedSignal("LevelTitle")` and `GetAttributeChangedSignal("IsVeteran")`, cleanly disconnecting both connections on `titleLabel.Destroying`.
- `BadgeService.spec.luau`:
  - Unit tests verifying the 14 pre-revival badge IDs in `LEGACY_BADGES`.
  - Unit tests verifying `CheckVeteranStatusAsync` for legacy badge owners, non-owners, error handling / pcall safety, short-circuiting on existing attribute, and edge-of-list detection.
  - Unit tests verifying overhead title text formatting combinations.
