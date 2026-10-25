# M4-UI-REF evidence

Studio "jacks project" (89999123284040), Edit mode only. No Play, no TestEZ, no save, no repo/script edits.

## Real client mount (`src/client/Modules/App/AppEntry.luau`)
ScreenGui (unnamed, parented to PlayerGui): `ResetOnSpawn=false`, `ZIndexBehavior=Sibling`, `IgnoreGuiInset=true`, `DisplayOrder` default (0).
React tree: `App` -> Pane(full) > `Pages` Pane > `Page` (spring wrapper, 0.8x0.8, scale 0.6->0.8) > page module; HUD sibling.
Second ScreenGui `Priority` (`AppDialogs.luau:252`): `DisplayOrder=100`, `ResetOnSpawn=false`, ZIndexBehavior left DEFAULT (Sibling), IgnoreGuiInset default (false). Hosts `dialogHolder` (ButtonPrompt etc.).
All captures used the AppEntry properties, with `Pane(full) > Pages > Page` wrapper as in App.

## Staleness
Checksummed (djb2, CR stripped) all 106 scripts under `ReplicatedStorage.Shared.UI` in Studio vs `src/shared/UI`: all identical. Configs not mounted, not checked.

## Screenshots (this folder)
1. `01-OpenableMenu-tabbed.jpg`: `Components/Core/OpenableMenu`, props `TitleText="Example Menu"`, `TitleColor=Styles.GREEN`, 3 Pages (First/Second/Third) with a TextLabel body, `OnClose=noop`. Shows title tab, red X, side tab column (selected tab outlined), pattern bg. No backdrop.
2. `02-ButtonPrompt.jpg`: `Components/Dialogs/ButtonPrompt`, `Title="Notification"`, `Text="Do you want to continue?"`, Buttons Yes (`Styles.GREEN`) / No (`Styles.ROSE`). No backdrop.
3. `03-Shop-composite-Featured-PARTICLES-body.jpg`: Shop composite (see BLOCKED), default page Featured. The real Featured page is a stub: empty grid and a hard-coded title "Particles" (`Pages/Shop/Featured.luau`). That is repo state, not a mount artifact.
4. `04-Shop-composite-Currency-tab.jpg`: same composite, `DefaultPage="Currency"`: category headers, price rows with Robux icon, scrollbar.
5. `05-DailyRewardsDialog-backdrop-over-panel.jpg`: `Dialogs/DailyRewardsDialog`, Status Day 3 CanClaim, VIP off, `OnClose=noop`. The whole screen AND the panel are dimmed: the backdrop draws OVER the panel.

## BLOCKED (partial)
`Pages/Shop` cannot be required in Edit mode: `Pages/Shop/RandomCosmeticsPurchase.luau:22` calls `Knit.GetService("CapsuleService")` at module top level ("Cannot call GetService until Knit has been started"); `Pages/Shop/init.luau:48` requires it. Searched: required each Shop child individually, only RandomCosmeticsPurchase fails. Captures 3 and 4 are therefore a composite: real `OpenableMenu` + the real Shop page modules with the exact PAGES table (keys, labels, colors) copied from `Pages/Shop/init.luau`, except the Nametags page content replaced by an empty Frame. This is a lens approximation, not the real Shop module. Opening other tabs was not captured (Edit mode, no clicking).

## Backdrop order per menu
- OpenableMenu (Shop, Inventory, Menu pages): no backdrop at all. Nothing dims behind them (`App.luau`/`Page.luau` have none).
- ButtonPrompt: no backdrop in it or in `AppDialogs`.
- DailyRewardsDialog: `Backdrop` TextButton, black, BackgroundTransparency 0.5, `ZIndex=50`, Size (5,5) scale, Position offset (0,-36), sibling of `ModalPage` (a `Page` Pane at default ZIndex 1) under a full-size Frame. With `ZIndexBehavior=Sibling` it renders OVER the modal (capture 5). That is the backdrop bug: the backdrop must be behind (lower ZIndex than ModalPage or ZIndex 0/-1 with the modal above).
- CapsuleOpening (`Core/CapsuleOpening.luau:135`): `Darken` Frame, ZIndex -1 inside the opening Pane, intended behind. Not mounted.

## Reusable building blocks
- Panel shell (title tab, X, green border, pattern, side tabs): `Components/Core/OpenableMenu` (uses `PageTitle`, `Buttons/CloseButton`, `SideButtons`, `Pane`; base images 13438173851 / 13438184024 / 13438518368).
- Title tab: `Components/PageTitle`. Close X: `Components/Buttons/CloseButton`.
- Side tab button: `Components/Buttons/HudTabButton` (Selected = outline, per-page ButtonColor/TextColor, e.g. ROSE, GOLD).
- Page open spring wrapper: `Components/Core/Page`.
- Small dialog panel (9-slice 13473433246, border, ribbon title): inline in `Dialogs/ButtonPrompt`; ribbon = `Buttons/Banner`; buttons = `Buttons/PromptButton` (Color, Disabled, Size).
- Shop row/category headers, price rows: `Pages/Shop/ShopCategory` (Currency/Points pages); cards: `Buttons/ShopCard`, `ShopItem`.
- Backdrop: inline in `Dialogs/DailyRewardsDialog` (no shared component). Banner title/X in that dialog are its own (rendered via Banner/CloseButton variants; not verified).
- Pills (VIP 2x etc.): inline in `DailyRewardsDialog`; not visible in capture 5 (VIP off).

## Cleanup
After the last run: `_LensPreview` nil, StarterGui children 1 (`UIArchive`, same as before), ReplicatedStorage children 7 (same as before). `_G.LensRoot` cleared. Not saved.
