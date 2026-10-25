# PHONE-RECON evidence (read-only, Edit mode, "jacks project" 89999123284040, studio id 61656dd1-f47b-4841-8129-49fdd50aa760)

No edits, no Play, no TestEZ, no temp instances created. Only repo writes: this folder.

## 1. BobaPhone tree
`StarterGui.UIArchive.OldUI.BobaPhone` (ScreenGui, Enabled=true, ResetOnSpawn=false, DisplayOrder 0). OldUI also holds `DoNotPublish` (ScreenGui) and `__REACT_PHONE`.
- `ModifyDeviceSize` (LocalScript): on touch + AbsoluteSize.Y < 500, moves phone Frame to right/bottom, size (0.5,0,1,26).
- `Frame` (black rounded phone body, AnchorPoint .5,1; Size {0.3,0},{1,-20}; Pos {0.5,0},{1,-70}; UIAspectRatioConstraint, UISizeConstraint)
  - `TopFrame` (status-bar notch)
  - `Screen`
    - `AppsHandler` (LocalScript, 48 lines): home-icon -> app open/close with a 0.3s slide tween on `Apps`; enables/disables scripts flagged by a `DisableScript` BoolValue.
    - `Home` (ImageLabel, bg asset 8261032060): `TimeHandler` (LocalScript, 29 lines), `Date`/`Time` labels, `Applications` (UIGridLayout) with 8 icon buttons:
      **Boba**, Subs, Web, Jokes, Games, Chat, Gifts, Event ("Easter"). Only Boba, Web, Chat, Jokes have a matching frame under `Apps`; Subs, Games, Gifts, Event have none.
    - `Apps` (Frame, starts size {1,0},{0,0}): children `Boba`, `Web`, `Chat`, `Jokes`, `Word Of The Day` (copy of Jokes), `CloseApps` (ImageButton), UIAspectRatioConstraint.

**"Boba" app = `Screen.Apps.Boba`** (ImageLabel, Visible=false until opened):
- `Bottom` tab bar (3 ImageButtons, UIListLayout): Home, Order, History. No scripts are wired to them (tab switching is not implemented; History has no frame).
- `Menus` folder: `Home` (greeting "Hi, xSa_m" hard-coded, empty Center), `Order` (the real app), `PopUp` (ImageButton backdrop with `ItemOptions` and `SelectList` frames).
- `Order`: `Top` (title + `Buttons.Menu` / `Buttons.MyOrder` toggles), `Center.Menu` (ScrollingFrame of category rows; `Template` = category title + horizontal ScrollingFrame of item cards with ViewportFrame + name), `Center.MyOrder` (`OrderFrame` list with `Template` rows: ItemName, RemoveItem X, InfoFrameTemplate lines; `Button` "Place Order").
- `PopUp.ItemOptions`: ScrollingFrame with templates `SelectTemplate` (segmented picker, e.g. Size), `RequiredSelectionTemplate` (tap opens SelectList, e.g. Syrup Flavor), `OptionsTemplate` (toggle, e.g. Ice, Whipped Cream); "Add Item" button. `PopUp.SelectList`: scrolling list of colored choice buttons.

Retired apps (all dropped per DEC-040): Web (AppHandler 7 lines, looks like a loading-skeleton stub), Chat, Jokes, Word Of The Day, plus the 4 icons with no frame.

## 2. Scripts under BobaPhone (path relative to `StarterGui.UIArchive.OldUI`)
Saved in `legacy-src/`. Retired-app scripts (Chat/Jokes/WOTD, 5 files, ~1,200 lines) were read for references only and NOT saved verbatim (retired by DEC-040); say so if the Architect wants them.

| Script | Lines | Saved | References |
|---|---|---|---|
| BobaPhone.ModifyDeviceSize | 10 | yes | UserInputService |
| ...Screen.AppsHandler | 48 | yes | TweenService, `Apps.CloseApps`, `DisableScript` BoolValues |
| ...Screen.Home.TimeHandler | 29 | yes | `ReplicatedStorage.ReplicatedValues.ClientTimeDisplay` (missing in this place); also has a bug: `while wait(3600)` runs forever before the Time code; `GetPropertyChangedSignal` is called with a function arg (wrong) |
| ...Apps.Boba.Menus.Order.PhoneMenuController (ModuleScript) | 380 | yes | `ReplicatedStorage.Boba` (missing) -> `Boba.Packages.Maid`, `Boba.Packages.ReplicaController`, `Boba.Shared.FoodService.FoodTable`, `Boba.Shared.ViewportProvider`; replica class `PhoneServiceReplica`; submit `PhoneServiceReplica:FireServer("PlaceMobileOrder", order)` |
| ...Apps.Boba.Menus.Order.MenuHandler (LocalScript) | 361 | note only (`MenuHandler.NOTE.md`) | older duplicate of the above; undeclared globals `FoodService`, `ViewportProvider`, `PhoneEvent`; submit `PhoneEvent:FireServer("BobaApp","Order",Order)` |
| ...Apps.Web.AppHandler | 7 | no | none (has `DisableScript` BoolValue child) |
| ...Apps.Chat.AppHandler / PhoneChatController | 205 / 207 | no | `ReplicatedStorage.RemoteStorage.PhoneEvent/PhoneFunction` (missing), SocialService:PromptGameInvite, replica `PhoneServiceReplica` |
| ...Apps.Jokes (and "Word Of The Day") AppHandler / PhoneJokesController | 254 / 302 each | no | `RemoteStorage.PhoneEvent/PhoneFunction` ("PhoneAdmin", "FilterText", "JokesApp" GetJokes/NewJoke/ArchiveJoke), replica `JokesServiceReplica` |

None of `ReplicatedStorage.Boba`, `RemoteStorage`, `ReplicatedValues`, `FoodService`, `ViewportProvider`, `PhoneEvent`, `PhoneServiceReplica` exist anywhere in this place (full DataModel name scan). The legacy server side (PhoneService / replica) is also absent. The legacy phone is non-functional as it sits.

## 3. Boba app ordering flow (from PhoneMenuController)
1. Open: Home icon -> `Apps` slides up, Boba frame shown. The Order page is the working page (tab bar Home/Order/History is not wired).
2. Menu tab: for each category in `FoodTable` (LayoutOrder, Color) a row; each item (`Items[name]`, `View` = {Model, Direction, ModelDistance}) is a card rendered with `ViewportProvider(viewport, model, direction, distance)`.
3. Tap item -> `AddItemToOrder(category, item)` builds the popup from the item's `Select` (segmented, first value default), `RequiredSelection` (a SelectList popup shown immediately, e.g. syrup/tapioca flavor; entries have `Color`, `LayoutOrder`), `Options` (boolean toggles, default = table value). If the item has none, it is added directly.
4. "Add Item" -> `AddToOrder`: max **3** items (silent no-op beyond), a My Order row shows name (Select values prefixed), `Type: value` lines for RequiredSelection, "+ X"/"- NO X" for toggled Options, with an X to remove.
5. My Order tab -> "Place Order" -> `PhoneServiceReplica:FireServer("PlaceMobileOrder", CurrentOrder)` where each entry is `{Item=<name>, DefaultInfo=<whole FoodTable entry>, CustomInfo=<choices>}`; then the list is cleared.
6. Status / pickup display: NONE in the phone (no response handling, no order-status UI; History tab empty). Pickup is in-world (status screens) legacy-side.
Menu data source: `Boba.Shared.FoodService.FoodTable`. No prices anywhere in the phone UI.

## 4. `__REACT_PHONE`
Path `StarterGui.UIArchive.OldUI.__REACT_PHONE` (name has one underscore between REACT and PHONE). ModuleScript, **0 bytes / empty source, no children**. See `react-port/NOTE.md`. BLOCKED: there is no port to inspect. React libs available for the port: `ReplicatedStorage.Packages.React`, `ReactRoblox`, `ReactSpring` (jsdotlua react 17.2.1; the repo already uses React in `src/shared/UI`).

## 5. Phone Tool
FOUND: `ReplicatedStorage.ToolsStorage."Boba Phone"` (Tool). RequiresHandle=false, CanBeDropped=false, no Handle/mesh, empty TextureId and ToolTip, Grip CFrame set (0.5,-0.062,0.008,...). One child: `LocalScript` (16 lines, saved as `legacy-src/ToolsStorage.Boba_Phone.LocalScript.luau`): waits for `PlayerGui.BobaPhone` and sets `.Enabled` true on Equipped / false on Unequipped. Not a Rojo path (place content). StarterPack is empty (0 children), so nothing gives it to players today; `ToolsStorage` has ~100 tools (food, floaties, etc.). Searched whole DataModel for Tool/HopperBin and names containing "phone": only this one. No other phone Tool.
Note: the Tool script expects the ScreenGui named `BobaPhone` directly under PlayerGui, but the gui sits in `StarterGui.UIArchive.OldUI` (an archive, probably not cloned to PlayerGui; check how UIArchive is handled).

## 6. Asset ids used by the Boba app (all `rbxassetid` images; no meshes or sounds in the app)
- Phone shell: Home bg 8261032060
- Boba tab bar icons: Home 8267151132, Order 8267206830, History 8267150291
- Menu category row decoration 5150079965; order-row remove X 5017723314
- Popup selector / option / required-selection / select-list rounded bg: 5150445362
- Home icons: Boba 5634393881, Subs 8261190497, Web 8261164391, Jokes 8265686238, Games 8265727394, Chat 8265756341, Gifts 8265827640, Event 9368023125
- Fonts: GothamSSm, FredokaOne. Colors: accent orange 255,104,5; greys 48/128/204.
Item cards use ViewportFrames of models from the (missing) FoodTable `View.Model`; current equivalents are in `ReplicatedStorage.SelectorModels` via `Shared.Ordering.Menu`.

## 7. Legacy -> current mapping
| Legacy | Current |
|---|---|
| `Boba.Shared.FoodService.FoodTable` | `ReplicatedStorage.Shared.Ordering.Menu` (`src/shared/Ordering/Menu.luau`): module named `FoodService`, exports `FoodTable` (same shape: LayoutOrder, Color, Items[name] with ItemName, View, Select, RequiredSelection, Options) and `IsLaunchItem`. Server only accepts launch items |
| `Boba.Shared.ViewportProvider` | no equivalent found by name; MobileOrder/Ordering pages render item views some other way (Architect to check `src/shared/UI`) |
| `PhoneServiceReplica:FireServer("PlaceMobileOrder", order)` / `PhoneEvent "BobaApp","Order"` | `Knit.GetService("OrderService"):CreateOrder(Players.LocalPlayer.UserId, request):expect()`; request = array of `{Category, Item, CustomInfo}`; result `{Success: boolean, Message: string?}` |
| `PhoneServiceReplica` / `ReplicaController` | not needed (Knit); `ReplicaController` exists in Packages but is unrelated |
| `Boba.Packages.Maid` | `Packages.Janitor` (no Maid in Packages) |
| order status / pickup | `OrderService.Client.QueueUpdated`, `Announcement`, in-world status screens; MobileOrder page already handles submit |
| 3-item cap | server allows 1-4 (`ORDER_MIN_ITEMS=1`, `ORDER_MAX_ITEMS=4`), 5s debounce, one open order per player |
| `ClientTimeDisplay` (ReplicatedValues) | none; use os.date/os.time |
| chat / jokes / admin / FilterText | retired, no equivalent needed |
| register prompt opening the ordering page | `TopBar.luau` ~L58-88: ProximityPrompt "Use Ordering System" on `workspace["Ordering System"].Computers` children -> `Pages.Ordering`; DEC-040 disables it |
Rojo: `default.project.json` manages only `ReplicatedStorage.Shared`, `Packages`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`. BobaPhone, UIArchive, ToolsStorage, SelectorModels and Networking are place content (need Studio + Rigger lease).

## Port risks (real work)
1. `__REACT_PHONE` is empty: the "starting point" does not exist in this place. Must ask Jack (resave/resync) or rebuild from the legacy tree.
2. `CustomInfo`/request shape: legacy sends `DefaultInfo` blobs; `CreateOrder` takes `{Category, Item, CustomInfo}` and validates against `IsLaunchItem` + server menu. Only launch-menu items orderable, so the phone menu must be filtered to launch items.
3. Legacy behaviour has no result handling; current needs Success/Message errors, debounce, one-open-order, 1-4 item cap (legacy 3).
4. No status/pickup UI in the phone; History tab never built. Decide scope (PENDING JACK).
5. Legacy tab bar is unwired, Home page greeting hard-coded ("xSa_m"), date hard-coded; fonts/colors/assets differ from `docs/STYLE.md` (DEC-013 vs DEC-040 conflict: legacy look vs current tokens; needs Jack).
6. Tool: no Handle, script depends on a gui named `BobaPhone` in PlayerGui; must be granted to every player (StarterPack empty; Tool lives in place content, not Rojo).
7. Item card visuals depend on viewport rendering of `SelectorModels`; ViewportProvider missing.
8. Mobile: ModifyDeviceSize hack for touch; MobileOrder page already exists in React as the closest reusable base.
9. Many UI assets are legacy image ids (possible ownership/permission issues in this experience).
BLOCKED: `__REACT_PHONE` source (empty); `ReplicatedStorage.Boba` / FoodService legacy server code (absent).

## Chunked React port (DEC-043)
Recon (read-only, Edit mode, studio 61656dd1, "jacks project"). Full-DataModel scan for names containing "REACT": only two modules exist; `OldUI.__REACT_PHONE` from section 4 is gone (replaced by the chunks).

### Modules
| Path (under `StarterGui.UIArchive.OldUI.BobaPhone.Frame`) | Bytes (#Source) | Lines | Legacy subtree |
|---|---|---|---|
| `__REACT_TOPFRAME` | 774 | 25 | `Frame.TopFrame` (status-bar notch) |
| `__REACT_SCREEN` | 175,905 | 3,444 | `Frame.Screen`: root, `Home` (icon grid, date/time), `Apps` containing Boba (tab bar, Menus Home/Order/PopUp), Web, Chat, Jokes, Word Of The Day, `CloseApps`, `UIAspectRatioConstraint` |

Not chunked: the phone body `Frame` itself (black rounded body, UIAspectRatioConstraint/UISizeConstraint), `ModifyDeviceSize`, and no popups/tab bar as separate modules. Tab bar and popups are inside `__REACT_SCREEN` (lines 563-663 tab bar, 1031-1378 PopUp). Apps in `__REACT_SCREEN`: Boba lines 549-1380 (832), Web 1382-1660 (retired; closeApps 1636-1656 and aspect 1658-1660 are shell), Chat 1662-2019, Jokes 2021-2731, Word Of The Day 2733-3443. Home icons Subs/Games/Gifts/Event exist only as hidden buttons (Visible=false) on Home.

### Saved (react-port/)
- `__REACT_TOPFRAME.luau` (whole module, verbatim)
- `__REACT_SCREEN.shell-home.luau` (lines 1-541 root + Home, `apps` wrapper, closeApps, aspect constraint; Boba/retired app bodies elided and marked)
- `__REACT_SCREEN.boba-app.luau` (lines 549-1380, the whole Boba app incl. tab bar, Home, Order, PopUp ItemOptions/SelectList)
Retired apps (Web, Chat, Jokes, WOTD) listed only; the full source stays in Studio.

### Generated code characterization
- Compile: `loadstring` returns a function for both modules (no syntax errors, not truncated, balanced; ends with `})`).
- NOT runnable as-is: the source is a single bare expression `c("Frame", {props}, {children})` with NO `return`, NO `require`, NO React import, and `c` is an undefined free global (presumably a createElement alias the plugin expected to be prepended). Zero hooks, zero state, zero events. Children passed as a name-keyed table (`boba = c(...)`), so keys double as React keys.
- Does not use `React.createElement`/`Roact.createElement`/`React.Event` anywhere; nothing about React path or version. To use it: add `local React = require(ReplicatedStorage.Packages.React); local c = React.createElement` plus `return function() return <expr> end`, and translate property names.
- Static tree only. Properties are raw Instance property dumps: Enum.* values, `Font.new(...)`, `FontFace`, `UICorner` per-corner radii, `TileSize`, `SizeConstraint`, `BorderColor3 = Color3.fromRGB(27,42,53)` defaults, `Visible=false` templates. `c("Folder", nil, {...})` for `menus`. Props like `ScaleType`, `SliceCenter`, `SliceScale`, `AutoButtonColor` are valid for createElement; `Disabled=true` on script stubs is not meaningful.
- Scripts are empty stubs only: `c("LocalScript")` x7 (appsHandler, timeHandler, menuHandler [Disabled], 4 AppHandlers), `c("ModuleScript")` x4 (phoneMenuController etc.), one `BoolValue` (disableScript). No logic survived; behaviour must come from the legacy scripts in `legacy-src/`.
- Images: 56 `http://www.roblox.com/asset/?id=` strings (+2 `rbxassetid`-matching hits), legacy URL form. Same ids as section 6 (Home bg 8261032060, tab icons 8267151132/8267206830/8267150291, row deco 5150079965, remove X 5017723314, rounded bg 5150445362, scroll bar 4983877983 and 1912796145). New in this dump: scroll-bar Mid/Top/Bottom images 4983877983, 1912796145.
- Sizing: mixed. Layout is mostly scale (`UDim2.fromScale`) with offsets for popup rows and Order rows (`UDim2.new(1,-10,0,40)`, `fromOffset(100,100)` for icon buttons, `fromOffset(30,30)` toggles). Root `Screen` is `UDim2.new(1,-16,1,-16)`. Aspect handled by `UIAspectRatioConstraint 0.483` under `Apps` only. Fonts: GothamSSm (Bold/Medium/Heavy), FredokaOne. 63 TextScaled labels (13 UITextSizeConstraint).
- Class counts: Frame 101, UICorner 101, TextLabel 59, ImageButton 51, ImageLabel 49, UIStroke 26, UITextSizeConstraint 13, UIListLayout 12, UIAspectRatioConstraint 9, UIGradient 8, TextBox 9 (all in Chat/Jokes/WOTD), ScrollingFrame 7, ViewportFrame 1, UIGridLayout 1, UISizeConstraint 1.

### Dropped or degraded vs legacy
- Boba `Order` item card `ViewportFrame` exists only as the empty Template (no Camera/WorldModel/CurrentCamera); item rendering was always runtime (`ViewportProvider`), so nothing lost, but still must be rebuilt.
- Dropped/changed: Boba root has no `Image`; phone body `Frame` (black body, UISizeConstraint), `TopFrame` constraints and the `BobaPhone` ScreenGui settings are outside the chunks. `Screen` root has no `UICorner`/aspect constraint of its own (aspect is under `Apps`). Tab-bar Home and History buttons are `Visible=false` (as legacy). `Hi, xSa_m` and `December 15, 2021 / 11:00 AM` are hard-coded placeholders. All behaviour scripts are empty.
- No TextBoxes in the Boba app (TextBoxes only in retired Chat/Jokes/WOTD).

### Port quality / main work
Faithful, complete, static visual dump of both the shell and the Boba app, including all templates (category row, item card, My Order row, ItemOptions Select/RequiredSelection/Options, SelectList) in their hidden `Visible=false` template form. Work to do: (1) wrap each chunk as a real React component (`React.createElement` + `return`), (2) flatten templates into data-driven components (menu from `Shared.Ordering.Menu`, launch items only), (3) rebuild all logic (tab switch, popups, 1-4 item cap, `OrderService:CreateOrder`, ViewportFrame item cards), (4) replace hard-coded greeting/date/time, (5) map legacy fonts/colors/offset sizing to `docs/STYLE.md` tokens (DEC-013) or get Jack's decision, (6) decide the shell body (phone Frame) which was not chunked.
