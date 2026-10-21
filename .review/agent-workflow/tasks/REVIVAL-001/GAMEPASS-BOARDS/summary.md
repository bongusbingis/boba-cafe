# GAMEPASS-BOARDS — Gamepass & Donation Advertisement Boards Migration and Wiring

## Scope Executed
1. Migrated 12 advertisement board models from `workspace.OldScriptables.AdvertisementsFolder.Gamepasses` into `workspace.Assets.GamepassBoards`.
2. Migrated the `Donate!` advertisement board model from `workspace.OldScriptables.AdvertisementsFolder.Products` into `workspace.Assets.GamepassBoards`.
3. Stripped legacy scripts, duplicate SurfaceGuis, ClickDetectors, and Configuration folders from all 13 models. All geometry remains anchored.
4. Extracted canonical templates into `ReplicatedStorage.SharedStorage.GamepassBoardTemplates`:
   - `HeaderGui` (Title, Subtitle labels)
   - `BodyGui` (Description, Icon, Robux Price badge, Purchase button)
   - `DonationGui` (ScrollingFrame with product buttons)
5. Tagged each model with attributes:
   - "Faster Walkspeed" -> `PassId = 12385742`
   - "Instant Brewing" -> `PassId = 12385760`
   - "VIP" -> `PassId = 12385781`
   - "Barista" -> `PassId = 6202153`
   - "Staff Intern" -> `PassId = 15243046`
   - "MopWhack" -> `PassId = 219651106`
   - "Fun Pass" -> `PassId = 219651061`
   - "Rainbow Pack" -> `PassId = 29083693`
   - "Korblox" -> `PassId = 219651161`
   - "Headless Head" -> `PassId = 219651224`
   - "UnlimitedStock" -> `PassId = 219650999`
   - "Celebrity" -> `PassId = 0` (unassigned/inactive)
   - "Donate!" -> `BoardType = "Donation"`
6. Created `src/client/Modules/GamepassBoardController.luau` (Knit Controller):
   - Dynamically mounts `HeaderGui` and `BodyGui` or `DonationGui` onto the `Part` and `Union` of each board.
   - Built with full `StreamingEnabled` resilience (asynchronous part streaming, attribute wait, concurrent board initialization).
   - Gamepass boards: fetches live Robux pricing via `MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)`, populates description & icon from `src/shared/Configuration/Gamepasses.luau`, connects both the SurfaceGui purchase button and a physical model `ClickDetector` to prompt gamepass purchase.
   - Donation board: populates 12 donation tier buttons (5, 10, 20, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000 Robux), sets live pricing, layout ordering, and connects clicks to `MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)`.

## Verification & Gates
- StyLua: Clean (`stylua --check src/client/Modules/GamepassBoardController.luau` passed).
- Selene: 0 errors, 0 warnings (`selene src/client/Modules/GamepassBoardController.luau` passed).
- Gate script: `bash scripts/gate.sh src/client/Modules/GamepassBoardController.luau` -> `GATE: PASS`.
- Rojo Build: Built cleanly to temp rbxl without issues.
- Studio Play Mode Runtime Verification:
  - All active gamepass boards mounted `HeaderGui`, `BodyGui`, `ClickDetector`, live prices (e.g. VIP 399, Kitchen Leader 999, Faster Walk Speed 89, etc.), and descriptions.
  - Celebrity (PassId 0) remained unmounted/inactive as intended.
  - Donation board mounted `HeaderGui` ("Donations" / "Thank you for your support!") and `DonationGui` with 12 ordered donation buttons with correct pricing.
  - Zero controller runtime errors or warnings in Studio logs.
