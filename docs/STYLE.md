# boba-cafe UI Style Spec

This is the replication spec for every player-facing UI in the Rojo tree. It is derived from source, not from screenshots. Its job: an agent that has never seen the game UI can build a page, dialog, HUD element, toast or billboard that matches the existing ones, using only what already exists.

Citation format: `U:` means `src/shared/UI/`. `client/` and `server/` mean `src/client/` and `src/server/`. Every rule carries `file:line` so it can be re-checked. Line numbers are as of commit `cbf5271` plus the uncommitted M1.5cd edits in `KitchenController.luau`, `AppDialogs.luau` and `SettingsConfig.luau`. Anything not determinable from source is marked `UNVERIFIED (source only)`.

## 0. The governing rule

**Replicate, never invent.** (DEC-013; `AGENTS.md` "UI replicates the existing style exactly".)

1. Use only the tokens in `U:Styles.luau` and the components and patterns catalogued here.
2. A new token, component, visual pattern, font, colour, radius, spring, asset or layout convention needs **Jack's approval** first.
3. If no existing pattern fits the thing you must build, **stop and ask**. Do not pick "the closest" and ship. Do not add a token to `Styles.luau` on your own (this replaces the earlier advice to add tokens freely).
4. When the code disagrees with itself (section 9), copy the **dominant** pattern named there, not an outlier. If you are touching a file that holds an outlier, leave it alone unless asked.
5. Legacy UI authored in the place file (for example the spill board template cloned in `client/Modules/SpillController.lua:196-206`, and any StarterGui content) is outside Rojo and outside this spec. `UNVERIFIED (source only)`.

Do-not-copy list (exists in source but is not a model): `U:Pages/MobileOrder/init.luau` (mounted only by a story, uses zero Styles tokens), `U:Pages/Shop/_Featured.luau` (unreferenced), `U:Components/Buttons/FlavorCard.luau` (unreferenced), `U:Components/Decoration/FloatingErrorText.luau` (unreferenced), `U:Pages/Ordering/PlayerSelectPage.luau` (unreferenced), and `U:Components/Core/Hud/OrderTicket.luau` (declared a prototype, see 6.6).

---

## 1. Tokens

### 1.1 Palette (`U:Styles.luau`, values at lines 6-31)

| Token | RGB | Used for (as the code uses it) |
| --- | --- | --- |
| `GREEN` | 143,169,127 | **Primary brand.** Page/tab titles (`U:Pages/Shop/Currency.luau:49`, 21 uses), menu title banner (`U:Components/Core/OpenableMenu.luau:122`), purchase button fill (`U:Components/Buttons/PurchaseButton.luau:59`), ShopCategory item rows default (`U:Pages/Shop/ShopCategory.luau:118`), dialog title banners (`U:Components/Dialogs/ButtonPrompt.luau:131`), HUD top bar fill (`U:Components/Core/Hud/TopBar.luau:105,141`), order-ticket header (`U:Components/Core/Hud/OrderTicket.luau:243`), "Equipped" banner (`U:Pages/Inventory/InventoryComponent.luau:101`), submit/confirm buttons (`TextInputPrompt.luau:56`, `InventoryComponent.luau:218`), NPC bubble stroke and patience-full fill (`server/Modules/CustomerService/Npc.luau:159,187`). |
| `GREEN_MID` | 138,173,125 | Clock In button when clocked out (`U:Components/Core/Hud/BottomLeft.luau:331`), promo Submit button (`U:Pages/Menu/PromoCodes.luau:18`). |
| `GREEN_DEEP` | 99,129,91 | Selected-tab outline (`U:Components/Buttons/HudTabButton.luau:71`), order-ticket item name (`OrderTicket.luau:120`), promo body text (`PromoCodes.luau:16`), PromptSelection sub-text (`U:Components/Dialogs/PromptSelection.luau:421`), NPC bubble text (`Npc.luau:168`). |
| `GREEN_LIGHT` | 150,189,136 | **Secondary brand.** Dialog description text (`ButtonPrompt.luau:93`), panel border tint (`OpenableMenu.luau:146`, `ButtonPrompt.luau:123`), inactive side-tab text (`OpenableMenu.luau:89`), SideButtons panel tint (`U:Components/SideButtons.luau:26`), Bucks button (`BottomLeft.luau:364`), settings category tint (`U:Pages/Menu/Settings.luau:29`), shop row header default (`ShopCategory.luau:135`), ShopItem default (`U:Components/Buttons/ShopItem.luau:32`), queue status text (`U:Components/Core/Hud/OrderQueue.luau:129`). |
| `GREEN_DIM` | 136,170,122 | Default `PromptButton` fill (`U:Components/Buttons/PromptButton.luau:21`), ActionPrompt stroke (`ActionPrompt.luau:134`), PromptSelection stroke and default choice fill (`PromptSelection.luau:19,376`), ordering Submit button (`U:Pages/Ordering/RightPanel.luau:193`), order-ticket outline (`OrderTicket.luau:231`). |
| `GREEN_TEXT` | 159,189,140 | Defined (comment "topbar text labels") but **unused anywhere**. Do not use. |
| `GREEN_BADGE` | 72,199,116 | "Best Value" banner (`U:Pages/Shop/RandomCosmeticsPurchase.luau:96`), promo success text (`PromoCodes.luau:122`). |
| `ROSE` | 255,182,193 | Featured shop tab fill (`U:Pages/Shop/init.luau:30`), Sell button (`InventoryComponent.luau:189`). |
| `ROSE_MID` | 230,145,165 | Staff Guide card fill (`U:Pages/Recipes/init.luau:78`), shift-timer button (`BottomLeft.luau:324`). |
| `ROSE_DEEP` | 180,80,100 | Featured tab text (`Shop/init.luau:31`), Staff Guide button (`BottomLeft.luau:340`), Recipes scrollbar and selected-tab outline (`Recipes/init.luau:43,121`). |
| `ROSE_TEXT` | 110,50,65 | Unused outside the unreferenced `_Featured.luau`. Do not use. |
| `GOLD` | 255,215,37 | Celebrity tab fill (`Shop/init.luau:37`), Rename button (`InventoryComponent.luau:193`), hidden-stat value (`U:Pages/Menu/Statistics.luau:62`), kitchen guidance highlight and beam (`client/Modules/KitchenController.luau:170,185`), dialog-choice pulse (`client/Modules/AppDialogs.luau:113`). |
| `GOLD_MID` | 255,185,30 | Clock Out button (`BottomLeft.luau:331`), hidden-stat label (`Statistics.luau:61`), NPC patience "Yellow" (`Npc.luau:201`). |
| `GOLD_DEEP` | 188,132,0 | Celebrity tab text (`Shop/init.luau:38`), highlight outline (`KitchenController.luau:171`). |
| `GOLD_BADGE` | 232,234,121 | Selected required-selection card outline (`U:Pages/Ordering/RequiredSelectionPage.luau:44`). |
| `RED` | 255,87,90 | Close-button disc (`U:Components/Buttons/CloseButton.luau:68`), cancel/negative buttons (`InventoryComponent.luau:219`, `SizeOptionsPage.luau:282`), error text (`PromoCodes.luau:122`), NPC patience "Red" (`Npc.luau:202`). |
| `CORAL` | 255,107,107 | Dismiss/leave buttons (`ActionPrompt.luau:92`, `OrderQueue.luau:138`), Points button (`BottomLeft.luau:352`), `NormalButton` border fallback (`NormalButton.luau:62`). |
| `CREAM` | 253,240,190 | Only use: NPC order bubble background (`Npc.luau:150`). |
| `GRAY` | 180,180,180 | Muted text (hints `Pets.luau:119`, empty states `Purchases.luau:88`, `PlayerSelectPage.luau:32`), separators (`OrderTicket.luau:186`), disabled button fill (`PromoCodes.luau:19`), text-input field fill (`TextInputPrompt.luau:41`), NPC patience track (`Npc.luau:177`). |
| `OFFWHITE` | 250,250,250 | Light surfaces and stroke: dialog panels (`ActionPrompt.luau:140`, `PromptSelection.luau:381`), Staff Guide stroke (`Recipes/init.luau:71`), `NormalButton` stroke (`NormalButton.luau:46`), HUD label text (section 1.4). |

Tier colours are data, not Styles tokens (`src/shared/Configuration/InventoryItemDefinitions/Tiers.luau`): Basic 190,190,190; Uncommon HSV(0.388889,0.6,0.784314); Rare 80,150,255; Epic 180,80,255; Legendary 255,185,30; Special 255,150,40. Components read them as `InventoryItemDefinitions.Tiers[tier].Color` (`U:Components/Buttons/ItemCard.luau:312`).

Menu category colours are data in `src/shared/Ordering/Menu.luau` (for example `TOP_MENU_COLOR` 139,199,104 at line 12). They are applied as `Color = data.Color` on cards (`U:Pages/Ordering/CategoryPage.luau:26`). Do not copy them into new UI.

### 1.2 Derived tints (the only sanctioned way to make a new shade)

Derive a shade from an existing token with `Color3:Lerp`, exactly as the code does:

| Derivation | Where |
| --- | --- |
| Stroke = fill lerped 15% to black (`props.Color:Lerp(Color3.new(0,0,0), 0.15)`), thickness 3 | `PromptButton.luau:35`, `PromptTextBox.luau:31`, `PageTitle.luau:37` |
| Label stroke = fill lerped 30% to black, thickness 1 | `U:Components/Buttons/ActionButton.luau:92` |
| ShopItem hover = base lerp black 0.12; press = 0.22 | `ShopItem.luau:33-34` |
| ShopCategory item = `Color` lerp black 0.175; sub-header = item lerp black 0.08; sub-option = item lerp white 0.04 | `ShopCategory.luau:118-120` |
| Card background for pet/shop = tier colour lerp white 0.2 | `ItemCard.luau:363` |
| Locked collection card = tier colour lerp black 0.6 | `U:Pages/Inventory/Collection.luau:81` |
| Tier group label stroke = tier colour lerp black 0.5 | `U:Components/CapsuleTierGroup.luau:79` |

### 1.3 Fonts

| Token | Value | Use |
| --- | --- | --- |
| `Styles.FONT_FREDOKA` | `rbxasset://fonts/families/FredokaOne.json` (`Styles.luau:2`) | **Everything**: 114 uses. Titles, labels, buttons, body, prices. |
| `Styles.FONT_DENKONE` | `rbxasset://fonts/families/DenkOne.json` (`Styles.luau:3`) | Secondary/accent only: stat labels (`Statistics.luau:86`), PromptSelection sub-text (`PromptSelection.luau:417`), capsule hint (`U:Components/Core/CapsuleOpening.luau:205`), floating error text, rich-text body inside the Staff Guide (`Recipes/Content.luau`, `<font face="DenkOne">`). |

No other font appears in the styled UI. Other families that exist in source (SourceSansPro, Nunito, GothamSSm) are outliers, see section 9.

### 1.4 Text colour rules

- Text on a coloured fill (buttons, banners, cards, rows): `Color3.new(1, 1, 1)` (49 uses, for example `PurchaseButton.luau:76`, `ShopItem.luau:86`, `ShopCategory.luau:71`).
- HUD chrome labels: `Styles.OFFWHITE` (`TopBar.luau:170-182` tab text, `NormalButton.luau:86`, `BottomLeft.luau:296`, `SmallNotification.luau:240`, `OrderTicket.luau:214,261`).
- Page and section titles on the page background: `Styles.GREEN`. Hints and empty states: `Styles.GRAY`. Dialog body: `Styles.GREEN_LIGHT`.
- Black text (`Color3.new()`) appears only on the light ordering-terminal panel (9 uses, for example `RightPanel.luau:113`) and on FlavorCard.
- Rich-text emphasis colours: gold `#f5c242` for `[bracketed]` text, red `#fa2545` for `|piped|` text (`client/Modules/AppDialogs.luau:130-133`).

### 1.5 Text size

Text is `TextScaled = true` almost everywhere. Control the maximum with `Pane`'s `MaxTextSize` (adds a `UITextSizeConstraint`, `U:Components/Pane.luau:158-162`; text labels only). Values in use:

| MaxTextSize | Where |
| --- | --- |
| 18 | SelectionCard default (`U:Components/Buttons/SelectionCard.luau:105`) |
| 20 | FlavorCard default (`FlavorCard.luau:58`), PlayerCard name (`PlayerCard.luau:121`) |
| 24 | PromptButton label (`PromptButton.luau:74`), PromptSelection choice label (`PromptSelection.luau:212`) |
| 25 | search box (`PlayerSelectPage.luau:88`), notepad (`Ordering/init.luau:409`), order description (`OrderItem.luau:110`) |
| 26 | OrderQueue status (`OrderQueue.luau:120`) |
| 28 | ActionPrompt description (`ActionPrompt.luau:164`) |
| 30 | ButtonPrompt and TextInputPrompt description (`ButtonPrompt.luau:85`, `TextInputPrompt.luau:105`) |
| `px(18)` | ShopCategory sub-row text (`ShopCategory.luau:76`) |

Fixed `TextSize` (non-scaled) is used only in: OrderTicket 13 and 15 (`OrderTicket.luau:89,121,262`), PromoCodes 14/16/20 (`PromoCodes.luau:32,49,113,124`), CapsuleTierGroup 18 (`CapsuleTierGroup.luau:74`), Recipes `px(35)` (`Recipes/init.luau:58`), Settings `px(11)` subtitle (`Settings.luau:332`). Copy the one of those that sits next to what you are extending.

### 1.6 Corner radii

Tokens (`Styles.luau:34-37`): `CORNER_FULL` (1,0), `CORNER_PILL` (0.4,0) **unused**, `CORNER_BUTTON` (0.2,0), `CORNER_CARD` (0.06,0). `Pane` accepts a `UDim` or a bare number (number becomes `UDim.new(n, 0)`, `Pane.lua:119-124`). Values by role as the code uses them (details and counts in 9.4):

| Role | Value | Where |
| --- | --- | --- |
| Circle / pill (toggle, item card, small chips, NormalButton) | 1 | `ItemCard.luau:372`, `NormalButton.luau:44`, `Settings.luau:92`, `PromoCodes.luau:250` |
| Dialog button / text box | 0.25 | `PromptButton.luau:33`, `PromptTextBox.luau:29`, `PromoCodes.luau:205` |
| Purchase button | `CORNER_BUTTON` 0.2 | `PurchaseButton.luau:40` |
| Action button | 0.1 | `ActionButton.luau:61` |
| Tab button | 0.5 | `HudTabButton.luau:67` |
| Card / stat / guide panel | `CORNER_CARD` 0.06 | `SelectionCard.luau:82`, `Statistics.luau:68`, `Recipes/init.luau:69` |
| ActionPrompt panel | 0.05 | `ActionPrompt.luau:132` |
| Celebrity info box | 0.2 | `Celebrity.luau:74,105` |
| NPC bubble | `CORNER_BUTTON` | `Npc.luau:155` |
| Order ticket (HUD) | 6 px | `OrderTicket.luau:229,247` |

### 1.7 Strokes

| Role | Colour | Thickness | Where |
| --- | --- | --- | --- |
| Dialog panel (ActionPrompt) | `GREEN_DIM` | 5 | `ActionPrompt.luau:133-136` |
| Dialog panel (PromptSelection) | `GREEN_DIM` | 4 | `PromptSelection.luau:375-378` |
| Choice button | `GREEN_LIGHT` | 2 | `PromptSelection.luau:177-180` |
| Dialog button (when `Color` given) | fill lerp black 0.15 | 3 | `PromptButton.luau:34-37` |
| NormalButton | `OFFWHITE` | 2 | `NormalButton.luau:45-48` |
| Selected HUD/side tab | `GREEN_DEEP`, `ApplyStrokeMode.Border` | 3 | `HudTabButton.luau:69-73` |
| Staff Guide card | `OFFWHITE` | 3.5 | `Recipes/init.luau:70-73` |
| Staff Guide selected tab | `ROSE_DEEP` | `px(5)` | `Recipes/init.luau:120-123` |
| Item card (tiered, active) | tier colour | 3 | `ItemCard.luau:373` |
| Tier group box | tier colour | 3 | `CapsuleTierGroup.luau:87` |
| Selected option card | `GOLD_BADGE`, Border | 3 | `RequiredSelectionPage.luau:43-47` |
| Card text outlines | black (default) | 1.5 | `ItemCard.luau:173,199,244,285` |
| Order ticket outline | `GREEN_DIM` | 1 | `OrderTicket.luau:230-233` |
| NPC bubble | `GREEN` | 2 | `Npc.luau:158-161` |
| Guidance pulse | `GOLD`, Border | 4 | `AppDialogs.luau:46,112-116` |
| Ordering notepad | white, Border | 5 | `Ordering/init.luau:343-347` |

Text-stroke properties used instead of a `UIStroke`: SelectionCard `TextStrokeTransparency 0.55` (`SelectionCard.luau:115`), PlayerCard `0` (`PlayerCard.luau:131`), PromptSelection `0.5` (`PromptSelection.luau:222`).

### 1.8 Padding and spacing

All as UDim; most are scale. The recurring values:

| Value | Role | Where |
| --- | --- | --- |
| `UIPadding` 0.02 each side | Grid page inset | `Passes.luau:51-56`, `Featured.luau:38-43`, `Collection.luau:167-172`; `InventoryComponent.luau:355-360` uses top 0.01 |
| `CellPadding (0.043, 0.03)`, `CellSize (0.212, 0.288)` | Shop/inventory item grid | `Passes.luau:46-50` and 5 more copies (9.6) |
| `CellPadding (0.039, 0.065)`, `CellSize (0.199, 0.35)` | Ordering option grid | `ItemPage.luau:22-26`, `RequiredSelectionPage.luau:20-24` |
| `CellPadding (0.025,0.025)`, `CellSize (0.47,0.17)` | 2-column stat grid | `Statistics.luau:130-137` |
| List `Padding` 0.02 scale | Between category blocks | `Currency.luau:65`, `FoodMenu.luau:87`, `Purchases.luau:71` |
| List `Padding` 0.05 scale | Horizontal button rows | `ShopItem.luau:61`, `ButtonPrompt.luau:104`, `TextInputPrompt.luau:124`, `CategoryPage.luau:19` |
| List `Padding` `UDim.new(0, 20)` | Capsule row and tier stack | `Pets.luau:136,145` |
| List `Padding` `px(3)` | Rows inside a category | `ShopCategory.luau:126`, `Settings.luau:255` |
| Between settings cards | `UDim.new(0, 10)` | `Settings.luau:490` |
| Item row inner padding | top/bottom 4, left/right 8 px | `OrderTicket.luau:106-111` |
| Row left inset | `0.03` scale (ShopItem), `px(10)`/`px(26)` (sub-rows) | `ShopItem.luau:65-67`, `ShopCategory.luau:62` |

### 1.9 Shadow, gradient, blur

There is no drop-shadow component. The only shadow is a duplicated, offset text label (`FloatingErrorText.luau:221-235`, offset +0.02/+0.02, colour 76,0,0, transparency 0.24 base; unreferenced). The only gradient is that component's three-stop vertical red `UIGradient` (`FloatingErrorText.luau:240-247`, rotation 90). `Pane` supports `Gradient` and nothing else mounts one. Do not add shadows or gradients.

### 1.10 Layering (ZIndex and DisplayOrder)

- App `ScreenGui`: `ZIndexBehavior = Sibling`, `ResetOnSpawn = false`, `IgnoreGuiInset = true`, default `DisplayOrder` (`client/Modules/App/AppEntry.luau:22-26`).
- Dialog `ScreenGui` "Priority": `DisplayOrder = 100`, `ResetOnSpawn = false`; it sets neither `IgnoreGuiInset` nor `ZIndexBehavior` (`AppDialogs.luau:251-257`). Its holder frame has `ZIndex = math.huge` (`AppDialogs.luau:203`).
- ZIndex values seen: 2 (14 uses, the default for label-over-fill, for example `ActionButton.luau:57`), 3, 4, 5 (close button, `CloseButton.luau:59`), 6, 10 (HUD ticket and queue, `OrderTicket.luau:227`, `OrderQueue.luau:83`; banner, `Banner.luau:28`), 11, and the PromptSelection block 50 (overlay), 60 (panel), 61-63 (content). Banner back image is `-2`, Darken overlay `-1`, shop image `0`.
- Rule: chrome behind content = 0 or negative; content = 2+; HUD overlays = 10; modal block = 50-63 inside the Priority gui.

### 1.11 Image assets (all `http://www.roblox.com/asset/?id=` unless noted)

| Asset | ID | Role | Where |
| --- | --- | --- | --- |
| Title tab back / back inner / front / front inner | 13438330502 / 13438349330 / 13438222034 / 13438230247 | Page title ribbon | `PageTitle.luau:29,36,45,52` |
| Side panel | 13438617189 | Tab column | `SideButtons.luau:25` |
| Menu base / border / pattern | 13438173851 / 13438184024 / 13438518368 | Page frame; pattern at `ImageTransparency 0.9` | `OpenableMenu.luau:134,145,167` |
| Close disc / inner | 13438417284 / 13438418840 | Close button | `CloseButton.luau:56,67` |
| Banner back / front | 13369767169 / 13369762471 | Ribbon title | `Banner.luau:33,43` |
| Dialog panel (9-slice, `SliceCenter Rect(104,96,408,416)`) / border | 13473433246 / 13382163077 | Dialog and queue chrome | `ButtonPrompt.luau:67,71,122` |
| NormalButton border / plus | 13382243228 / 13382300733 | HUD button | `NormalButton.luau:61,112` |
| Points icon / Bucks icon / timer icon / capsule | rbxassetid 13391365805 / 13382286492 / 8184068342 / 6073658218 | HUD currency and hatch | `BottomLeft.luau:283,322,350,362` |
| HUD top bar time pod / border / base / border | 13407992271 / 13408001982 / 13407950658 / 13407901910 | Top bar | `TopBar.luau:104,114,140,151` |
| Shop row header / footer | 13465572823 / 13465749908 | Category header and footer slices | `ShopCategory.luau:134,161`, `Settings.luau:46-47` |
| Card background | 13866611257 | FlavorCard / PlayerCard, tint 217,217,217 | `PlayerCard.luau:32-33` |
| Toast panel (9-slice `SliceCenter Rect(256,256,256,256)`) | rbxassetid 2018256936 | Toast | `SmallNotification.luau:38,204` |
| Toast default icon | rbxassetid 138404484604568 | Toast | `SmallNotification.luau:224` |
| Loading spinner | rbxassetid 5634393881 | Pages while loading | `InventoryComponent.luau:589`, `Settings.luau:542` |
| Rotating spotlight | rbxassetid 127221443901777 | Capsule reveal | `BackgroundSpotlight.luau:38` |
| Remove (x) | 13934199293 | Order row remove | `OrderItem.luau:29` |
| Checkbox / fill | 13752189617 / 13752240807 | Ordering add-ons | `AddonCheckbox.luau:31-32` |
| Ordering terminal base / top / bottom / notepad toggle | 13675614099 / 13675646315 / 13675645871 / 13927899272 | Ordering page chrome | `Ordering/init.luau:443,462,499,486` |
| Placeholder avatar | `rbxasset://textures/ui/GuiImagePlaceholder.png` | Fallback | `PlayerCard.luau:50` |

Use `http://www.roblox.com/asset/?id=` for the existing chrome IDs (41 uses) and `rbxassetid://` for icons added later (25 uses); either form loads. Item and capsule images come from `InventoryItemDefinitions` data.

---

## 2. Layout and scaling

### 2.1 Scale approach

- **Scale first.** Size and position with `UDim2.fromScale` and `AspectRatio`, so a component keeps proportions at any resolution. Offsets are used only for fixed hairlines (`UDim2.new(1,0,0,1)` dividers, `OrderTicket.luau:188`), HUD fixed sizes (`BottomLeft.luau:258` button row 60 px high, `OrderTicket.luau:226` 190 px wide) and text insets.
- **`UIScale` for animation, `Pane`'s `Scale` prop** (`Pane.luau:137-139`). Hover/press and open/close animate `UIScale`, not `Size`.
- **`AspectRatio`** on the outer frame of anything with a fixed look: pages `OpenableMenu` 1.347 (`OpenableMenu.luau:111`), order queue and button prompt 2.23008 (`OrderQueue.luau:77`, `ButtonPrompt.luau:49`), action prompt 0.937 (`ActionPrompt.luau:110`), staff guide 0.75 (`Recipes/init.luau:68`), ordering terminal 1.53648 (`Ordering/init.luau:432`), NormalButton wrapper 7 (`NormalButton.luau:32`), HUD top bar 6.5443 and 11.5077 (`TopBar.luau:98,137`), all round things 1.
- **`UISizeConstraint`** for HUD/dialog min and max pixel sizes: top bar 390-590 wide (`TopBar.luau:188-191`), order queue 210-330 x 105-165 (`OrderQueue.luau:86-89`), button/text prompt 200-440 wide, min height 122 (`ButtonPrompt.luau:57-60`), action prompt 200-380 wide, min height 180 (`ActionPrompt.luau:118-121`).
- **`usePx`** (`U:Hooks/usePx.luau`) for pixel values that must grow with the screen. Reference resolution 1280x832 (`usePx.luau:7`), scale = geometric mean of both axes (`DOMINANT_AXIS 0.5`, line 35), floored at `MIN_SCALE 0.75` (line 34), debounced 0.2 s on viewport change (lines 64-67). API: `px(n)` rounds, `px.even`, `px.floor`, `px.ceil`, `px.scale` (lines 74-93). Use it for pixel-based heights and gaps, as `ActionPrompt.luau:80` (`px(BUTTON_HEIGHT)`, `BUTTON_HEIGHT = 50`), `Settings.luau:36-40`, `ShopCategory.luau:36`, `Ordering/init.luau:298` (`usePx()(125)` card size).

### 2.2 Device handling

- **There is no phone/tablet layout switch.** The only device branch in the UI is `UserInputService.TouchEnabled` in `ItemCard.luau:22`: price label always visible on touch (`ItemCard.luau:310`), and the shop image does not dim on hover on touch (`ItemCard.luau:320`). Everything else relies on scale, aspect ratio and `usePx`.
- The phone-shaped ordering page `U:Pages/MobileOrder/init.luau` is not mounted anywhere (only `Stories/MobileOrder.story.luau:11`). Do not treat it as the phone pattern.
- Tablet: no code. `UNVERIFIED (source only)`.
- Phone legibility of the HUD (bottom-left button row 60 px, `BottomLeft.luau:258`), thumbstick overlap, and the Roblox top bar overlap with the HUD top bar (`TopBar.luau:94-96`, anchored at y -0.001 of an `IgnoreGuiInset` gui): `UNVERIFIED (source only)`.

### 2.3 Safe area, insets, topbar

- App gui is `IgnoreGuiInset = true` (`AppEntry.luau:25`): origin is the physical screen top. No code reads `GuiService` insets or `SafeAreaCompatibility`.
- The Priority (dialog) gui leaves `IgnoreGuiInset` at its default (`false`), so its origin sits below the top bar. `PromptSelection` compensates by positioning its click-catcher at `UDim2.fromOffset(0, -36)` (`PromptSelection.luau:364`). Other dialogs do not compensate. A new full-screen overlay inside the Priority gui must do the same.

### 2.4 Where things sit

| Surface | Anchor and position | Size | Source |
| --- | --- | --- | --- |
| Page (and Page-wrapped dialogs) | anchor (0.5,0.5), pos (0.5,0.5) | Frame `fromScale(0.8,0.8)` with `UIScale 0.8` at rest (effective 0.64 of the screen, derived) | `Page.luau:70-77`, `Page.luau:24-27` |
| HUD root | anchor (0.5,0.5) | (1,1) | `Hud/init.luau:24-29` |
| Top bar | anchor (0.5,0), pos (0.5,-0.001) | (0.377911,0.106612), aspect 6.5443, 390-590 px | `TopBar.luau:92-98,188-191` |
| Bottom left stack | anchor (0,1), pos (10 px, 0.985) | width 0.3, auto height | `BottomLeft.luau:224-232` |
| Bottom right | anchor (1,1), pos (0.981,0.981) | (0.175,0.3); currently empty | `BottomRight.luau:40-45` |
| Order ticket | anchor (1,1), pos (0.99,0.92) | 190 px wide, auto height | `OrderTicket.luau:219-228` |
| Order queue | anchor (0.5,1), pos (0.5,0.92) | (0.265,0.175), aspect 2.23008 | `OrderQueue.luau:75-84` |
| Toast | inside bottom-left currency column, LayoutOrder -6 | full column width, height springs 0 to 135 px | `SmallNotification.luau:184-194`, `BottomLeft.luau:306-319` |
| Dialogs (button/text) | pos (0.5 + OffsetX, 0.5) | (0.6,0.4), aspect 2.23 | `ButtonPrompt.luau:47-55` |
| Dialog (action) | pos (0.5 + OffsetX, 0.5 - yOffset/1000) | (0.65,0.65), aspect 0.937 | `ActionPrompt.luau:106-116` |

`OffsetX` (a scale added to x) shifts a dialog sideways so it does not cover the page behind it; inventory passes `0.1` (`InventoryComponent.luau:200,221,245`).

### 2.5 Lists, grids, scrolling

- **Scrolling frame, tab content** (the default for any list inside a page): `Active = true`, `AutomaticCanvasSize = Y`, `CanvasSize = UDim2.new()`, `ScrollBarImageColor3 = Color3.new()`, `ScrollBarThickness = 5`, `ScrollingDirection = Y`, `BackgroundTransparency = 1`. Position `(0, 0.112)`, size `(1, 0.888)` under the title (`Currency.luau:53-63`, `Purchases.luau:127-137`). Grid pages use size `(1.02, 0.888)` and `ScrollBarImageTransparency = 1` (`Passes.luau:94-105`).
- **Category list**: vertical `UIListLayout`, `Padding 0.02` scale, `SortOrder LayoutOrder`, spacer `Frame` `LayoutOrder = math.huge` size `(1,0.05)` at the end (`Currency.luau:64-85`).
- **Item grid**: `UIGridLayout` with the shop constants in 1.8, items given `LayoutOrder`; on-sale items sort first, off-sale items after (`Passes.luau:44-77`).
- **Wrapping tier box**: `UIListLayout` Horizontal, `Wraps = true`, `HorizontalFlex = SpaceEvenly`, cell `UDim2.fromOffset(px(90), px(90))` (`CapsuleTierGroup.luau:88-95`, `Pets.luau:24,58`).
- **Order of siblings**: always set `LayoutOrder`; the code assigns ordinals from `nextOrderFunctionFactory` (`U:Utility/nextOrderFunctionFactory.luau`, used at `Credits.luau:39`, `BottomLeft.luau:41`) or explicit numbers (`BottomLeft.luau:326-369`).
- **Loading state**: hide the grid (`Visible = not isLoading`) and show a centred spinner image at size `(0.175,0.175)` with `SizeConstraint RelativeXX`, rotated by a clock binding through `easeInOutBack` over `SPIN_PERIOD 1.4` s (`InventoryComponent.luau:575-597`, `Settings.luau:25-47,536-553`). Empty state: a `GREEN` title-style label at 0.4 transparency saying `You don't have any <things>!` (`InventoryComponent.luau:598-609`) or a `GRAY` line (`Purchases.luau:88`). Large grids load in batches of 16 every 0.05 s (`InventoryComponent.luau:326-327`).

---

## 3. Component catalogue

Conventions common to all components: `local c = React.createElement`; services and `Packages`/`Shared`/`UI` resolved at top via `WaitForChild`; section comments `---> dependencies`, `---> components`, `---> styles`, `---> constants`, `---> private`, `---> public` (for example `U:Components/Buttons/ActionButton.luau:22-39`). A component is a function taking one `props` table and returning a React tree. Every interactive component tracks `isHovering` and `isPressing` with `React.useState` and feeds them into `ReactSpring.useSpring`.

### 3.1 `Pane` (`U:Components/Pane.luau`)

Base wrapper for Frame, ImageLabel, TextButton, TextLabel, ImageButton, ScrollingFrame, TextBox (`ClassName` defaults to `"Frame"`, line 111). A forwardRef component. Always sets `BorderSizePixel = 0` and `BackgroundTransparency = 1` unless `Native.BackgroundTransparency` is given (lines 112-116).

| Prop | Effect | Line |
| --- | --- | --- |
| `Native` | raw properties merged over the defaults (`joinDicts`) | 117 |
| `CornerRadius` | `UDim` or number, adds `UICorner` | 119-124 |
| `Stroke` | table of `UIStroke` props | 141 |
| `Padding` | `{PaddingTop, PaddingBottom, PaddingLeft, PaddingRight}` UDims | 151-156 |
| `ListLayout` | `UIListLayout` props; `SortOrder` forced to `LayoutOrder` | 125-126 |
| `GridLayout` (+`GridLayoutAspectRatio`) | `UIGridLayout`, same forced sort order | 127-134 |
| `Gradient` | `UIGradient` props | 135 |
| `Scale` | `UIScale` (number or spring binding) | 137-139 |
| `AspectRatio` | number or props table, adds `UIAspectRatioConstraint` | 103-108,143 |
| `AutomaticSize` | forwarded | 114 |
| `MaxTextSize` | `UITextSizeConstraint`, only when `ClassName == "TextLabel"` | 158-162 |
| `OnHover`, `OnLeave` | `MouseEnter`, `MouseLeave` | 86-89 |
| `OnClick` | `Activated` | 96 |
| `OnPress` | `MouseButton1Down` (falls back to `OnRelease`) | 93-94 |
| `OnRelease` | `MouseButton1Up` | 95 |
| `OnChange` | `{"PropertyName", fn}` via `React.Change` | 99-101 |

Mouse events other than hover are attached only when `OnClick` or `OnRelease` is set (line 85). `MaxTextSize` does nothing on a `TextBox` (lines 158-159), yet `PromptTextBox` passes it (`PromptTextBox.luau:59`).

```lua
c(Pane, {
	ClassName = "Frame",
	ListLayout = { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0) },
	Native = { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
}, { ... })   -- U:Pages/Shop/Celebrity.luau:162-174
```

Raw `c("Frame", ...)` is also used in pages (188 raw vs 85 `Pane` in `Pages/`, 38 vs 107 in `Components/`). Components prefer `Pane`; page-level text titles and scrollers use raw instances. Follow the file you are editing.

### 3.2 Page shell

**`Page`** (`U:Components/Core/Page.luau`) animates its content in and out. Props: `IsVisible`, `OnClosing(callback)`, `PageContent`. Spring `{mass 1, tension 2500, friction 100}` (lines 31-35). Opens from position `(0.5,0.65)` scale `0.6` to `(0.5,0.5)` scale `0.8` (lines 24-27,56-59). On mount it hands its reverse animation to `OnClosing` (lines 60-67). Container: `Size (0.8,0.8)`, anchor (0.5,0.5), `UIScale` = spring (lines 70-77). No sound (the call is commented out, line 55). Used by `App` for every page and by dialogs that want the same pop (`ActionPrompt.luau:201`, `ButtonPrompt.luau:137`, `TextInputPrompt.luau:156`, `CapsuleOpening.luau:27`).

**`OpenableMenu`** (`U:Components/Core/OpenableMenu.luau`) is the tabbed page frame used by Shop, Inventory and Menu.

| Prop | Default |
| --- | --- |
| `Name` | `"MenuWrapper"` |
| `AspectRatio` | `1.347` |
| `TitleText` | `"Menu"` |
| `TitleColor` | `Styles.GREEN` |
| `HidePattern` | false |
| `Pages` | list of `{Key, Label, Content, LayoutOrder?, ButtonColor?, ButtonTextColor?}` |
| `DefaultPage` | first page |
| `SideButtonsProps` | forwarded to `SideButtons` |
| `OnClose` | none |

Anatomy (back to front): `PageTitle` ribbon, `CloseButton`, `Base` image (anchor (0.5,1), size (1,0.880631), asset 13438173851) holding a `GREEN_LIGHT`-tinted `Border` (size (0.971,0.955)) and a clipped `Container` (size (0.949833,0.923274)) with the faint pattern, a `Frames` content area (pos (0.272521,0.5), size (0.707747,0.939058), clips) and the `SideButtons` column (`OpenableMenu.luau:109-188`). Side tab = `HudTabButton` size `(0.85,0.095)`, `BackgroundColor` default `OFFWHITE`, text default `GREEN_LIGHT`, `Selected` when its key is current (lines 84-94). Special tab colours: Featured `ROSE`/`ROSE_DEEP`, Celebrity `GOLD`/`GOLD_DEEP`, "My Collection" `GOLD`/`GOLD_DEEP` (`Shop/init.luau:30-38`, `Inventory/init.luau:48-49`).

```lua
return c(OpenableMenu, { TitleText = "Shop", TitleColor = Styles.GREEN, DefaultPage = landingPage.Key, Pages = PAGES,
	OnClose = function() props.ClosePage() end })   -- U:Pages/Shop/init.luau:64-72
```

**`PageTitle`** (`U:Components/PageTitle.luau`): `Text`, `Color`. Four stacked ribbon images, back inner tinted `Color` lerped black 0.15, front inner tinted `Color`, white Fredoka `TextLabel` size (0.85,0.591) (lines 21-69). Frame pos (0.0384615,0), size (0.436455,0.189189).

**`SideButtons`** (`U:Components/SideButtons.luau`): tinted panel image (default `GREEN_LIGHT`), pos (0.0193662,0.5), size (0.230634,0.939058), vertical list `Padding 0.05`, top padding 0.035 (lines 19-40).

**`CloseButton`** (`U:Components/Buttons/CloseButton.luau`): prop `OnClick`. Fixed pos (0.98077,0.147523), size (0.0919732,0.123874), ZIndex 5; image disc plus `RED` inner plus white "X" label. Press 0.9, hover 1.15 (line 31).

### 3.3 Buttons

All buttons: `AutoButtonColor = false`, spring from `Styles.SPRING_STANDARD`, hover and press via `Pane` events, `OnLeave` clears both flags.

| Component | Path | Props (default) | Fill / stroke / radius | Label | Hover / press |
| --- | --- | --- | --- | --- | --- |
| `PromptButton` | `Buttons/PromptButton.luau` | `Text`, `Color` (`GREEN_DIM`), `Size` (0.47,0.77), `LayoutOrder`, `Disabled`, `OnClick` | fill = Color; stroke 3 = Color lerp black 0.15 only if `Color` passed; radius 0.25 | white Fredoka, scaled, wrapped, max 24, size (0.85,0.6) | hover 1.07, press 0.93; disabled: scale 1, bg transparency 0.45, text 0.35, `Active=false`, no click |
| `ActionButton` | `Buttons/ActionButton.luau` | `Text`, `Color`, `Size` (0.167673,1), `Position`, `AnchorPoint` (0.5,0.5), `LayoutOrder`, `ZIndex` (2), `OnClick` | solid fill, radius 0.1, no button stroke | white label, size (0.85,0.47), `UIStroke` = Color lerp black 0.3, thickness 1 | hover 1.05, press 0.95 |
| `PurchaseButton` | `Buttons/PurchaseButton.luau` | `Title`, `Price` (string), `LayoutOrder`, `OnClick` | `GREEN`, `CORNER_BUTTON`, size (0.235229,1) | two white labels: title at y 0.2 (h 0.250944), price at y 0.6 (h 0.32) | hover 1.05, press returns to 1 |
| `ShopItem` | `Buttons/ShopItem.luau` | `Label`, `Price`, `Color` (`GREEN_LIGHT`), `LayoutOrder`, `OnClick` | square row, size (0.981,0.065) `RelativeXX`, left pad 0.03, horizontal list pad 0.05 | label 0.685698 wide left aligned; price 0.234582 right aligned, text `"\u{e002} " .. Price` | colour lerp black 0.12 hover, 0.22 press (no scale) |
| `HudTabButton` | `Buttons/HudTabButton.luau` | `Text`, `TextColor3` (white), `Size` (0.334,1), `BackgroundColor` (`OFFWHITE`, transparent if omitted), `LayoutOrder`, `Selected`, `OnClick` | radius 0.5; `Selected` adds Border stroke 3 `GREEN_DEEP` | Fredoka scaled, size (1,0.58) | hover 1.1, press 1 |
| `NormalButton` | `Buttons/NormalButton.luau` | `Text`, `Color`, `Icon`, `PlusButton`, `Size` (0.921739,0.0546164), `Position`, `LayoutOrder`, `OnClick`, `OnPlusButtonClick` | wrapper aspect 7; pill (radius 1), `OFFWHITE` stroke 2, fill = Color, tinted border image | `OFFWHITE` text in a (0.92,0.616) container; icon left, plus right | no animation |
| `CloseButton` | see 3.2 | | | | hover 1.15, press 0.9 |
| `PromptTextBox` | `Buttons/PromptTextBox.luau` | `Text`, `PlaceholderText`, `Color` (`GREEN_DIM`), `Size` (0.47,0.77), `LayoutOrder`, `OnTextChange`, `OnClick` | same chrome as PromptButton | `TextBox` white, placeholder 216,216,216 | no scale |

```lua
c(PromptButton, { Text = "Leave Queue", Color = Styles.CORAL, Size = UDim2.fromScale(0.64, 0.38),
	OnClick = function() ... end })    -- U:Components/Core/Hud/OrderQueue.luau:136-145
c(NormalButton, { Size = BUTTON_SIZE, Color = if clockedIn then Styles.GOLD_MID else Styles.GREEN_MID,
	Text = if clockedIn then "Clock Out" else "Clock In", OnClick = toggleClockedIn, LayoutOrder = 1 })   -- BottomLeft.luau:329-335
```

Button colour meaning: green family = go/confirm (`GREEN`, `GREEN_DIM`), `CORAL` or `RED` = dismiss/cancel/leave, `ROSE` = sell, `GOLD` = rename/special. Disabled uses transparency, never a new colour (`PromoCodes` uses `GRAY` fill, `PromoCodes.luau:19`; dialogs use the transparency route, `PromptButton.luau:66,83`).

### 3.4 Cards

**`ItemCard`** (`U:Components/Buttons/ItemCard.luau`) is the one card for items. `NametagCard`, `PetCard`, `ShopCard` re-export it; the variant is picked by props (lines 86-94,126-130).

| Prop | Meaning |
| --- | --- |
| `Name`, `Tier` | identity; tier colour tints stroke, background, tier label |
| `Color` / `Animation` | nametag variant (animated colour swatch; `Animation.Frames` of `{Color, Transparency, Hold, Transition}`) |
| `Model` | pet variant (3D `ViewportModel`, rotation 15, elevation 15, FOV 30, size (1,0.55)) |
| `Image`, `ImageSize` | shop variant (default image size (0.675,0.675)) |
| `Price` (string) | label at y 0.15 (0.5 when shop with banner) |
| `TopBanner` | `{Text, Color}` rendered as a `Banner` size (1.05,0.225) |
| `StackCount` | badge "×N" when > 1 |
| `OffSale` | black 0.4 overlay with "Off Sale"; disables interaction |
| `Equipped`, `ZIndex`, `LayoutOrder`, `Size` (1,1), `OnClick` | |

Anatomy: circular `ImageButton` (`CORNER_FULL`, aspect 1), tier stroke 3 when active (`ItemCard.luau:368-373`); name label y 0.625 with stroke 1.5 (1 for pets); tier label at y 0.75 coloured by tier with black stroke 1.5; count badge `Color3.fromRGB(30,30,30)` 0.25 transparency, top right; price fades in on hover (always shown on touch) via spring `priceOpacity` and a stroke spring `{mass 0.5, tension 15000, friction 150}` (lines 310-327). Hover 1.08 (pet 1.1), press 0.95; pets use `SPRING_CARD`, others `SPRING_STANDARD` (lines 315-322).

```lua
c(ShopCard, { Name = pass.Name, Price = pass.Price, Image = pass.Image, ImageSize = UDim2.fromScale(1, 1),
	OffSale = pass.OffSale, LayoutOrder = layoutOrder })    -- U:Pages/Shop/Passes.luau:69-76
```

**`SelectionCard`** (`Buttons/SelectionCard.luau`): `Text`, `Color`, `Icon?`, `Size?`, `MaxTextSize` (18), `LayoutOrder`, `OnClick`. Transparent button holding a `Frame` of `Color`, radius `CORNER_CARD`, scaled by the spring; optional icon (pos (0.5,0.38), size (0.62,0.52), Fit); label anchored bottom, y 0.97 with icon or 0.75 without, size (0.9, 0.28 or 0.52), white with text stroke 0.55 (lines 79-118). Hover 1.07, press 0.93. Used in ordering (`CategoryPage.luau:24-33`). Selected state is a wrapper Frame with a `GOLD_BADGE` Border stroke 3 (`RequiredSelectionPage.luau:41-61`).

**`PlayerCard`** (`Buttons/PlayerCard.luau`): `PlayerName`, `UserId`, `AvatarImage`, `LayoutOrder`, `OnClick`. Card image 13866611257 tinted 217,217,217, avatar (0.9,0.9), name at y 0.738 with text stroke 0, max 20 (lines 98-135). Hover 1.06, press 0.94. Headshot via `GetUserThumbnailAsync(..., HeadShot, Size352x352)` inside `pcall` (lines 53-67). `FlavorCard` is the same chrome with a black label (unreferenced).

**`Banner`** (`Buttons/Banner.luau`): `Color`, `Text`, `Size`, `Position` (default (0.5,0.21)). Ribbon: `Back` (asset 13369767169, ZIndex -2) and `Front` (13369762471, ZIndex 5) tinted `Color`, white Fredoka label (0,0.5)-anchored, size (1,0.8) (lines 22-62). Frame ZIndex 10.

**`CapsuleTierGroup`** (`U:Components/CapsuleTierGroup.luau`): `Tier`, `LayoutOrder`, `Items`. Label: ` <Tier>  —  <weight>%` or ` <Tier>  —  Event Only` (lines 32-37), size 18, white with tier-dark stroke 2; below, an `ImageButton`-class box with radius 0.06, tier stroke 3, wrapping list (lines 84-109).

**`ViewportModel`** (`U:Components/ViewportModel.luau`): `Model`, `Size`, `LayoutOrder`, `ZIndex`, `ModelRotation` (0), `ElevationAngle` (30), `FieldOfView` (45), `Ambient` (178,178,178), `LightColor` (white), `LightDirection` (-1,-2,-1). Clones the model into a `WorldModel`, camera distance = 2.5 x largest bounding dimension.

### 3.5 Dialogs (`U:Components/Dialogs/`)

Dialogs are looked up **by file name** by `DialogController` (`AppDialogs.luau:154`) and `DialogService` (`server/Modules/DialogService.luau:51-56`). A new dialog type = a new ModuleScript here; but a new *visual* needs approval.

| Dialog | Props | Chrome | Buttons |
| --- | --- | --- | --- |
| `ButtonPrompt` | `Title`, `Text` (rich), `Buttons {Text, Color?}`, `OffsetX`, `OnResolution(text)` | 9-slice panel 13473433246 + `GREEN_LIGHT` border 13382163077 + `Banner` (`GREEN`, size (1.21645,0.371931)) | `PromptButton` row, list `Padding 0.05`, `HorizontalFlex Fill` |
| `TextInputPrompt` | `Title`, `Text`, `PlaceholderText`, `OffsetX`, `OnResolution(text)` | same panel, banner height 0.35 | `PromptTextBox` (`GRAY`, 0.75 wide) + `PromptButton` "Submit" (`GREEN`, 0.25 wide) |
| `ActionPrompt` | `Title`, `Text`, `Buttons {Text, Color?, Disabled?}`, `CloseText` ("Close"), `OffsetX`, `OnResolution(text)` | `OFFWHITE` frame radius 0.05, `GREEN_DIM` stroke 5, `Banner` `GREEN` size (1.21645,0.15) | stacked `PromptButton`s of `px(50)` height, last one "Close" in `CORAL` |
| `PromptSelection` | `Title` ("Select"), `Text`, `Items {Name, Model?, ModelName?, Color?, IsTip?}`, `OffsetX`, `OnResolution(index or nil)` | `OFFWHITE` panel, `GREEN_DIM` stroke 4, black overlay, pop-in spring | round choice buttons (`GREEN_DIM` default fill) in rows of 4 (5 at 10+ items, 6 at 20+) |
| `CapsuleOpening` | `Capsule`, `OnResolution` | wraps `Core/CapsuleOpening` in `Page` | click capsule to reveal, closes 2 s later |

Description text in the first three is `GREEN_LIGHT` (`ButtonPrompt.luau:93`, `ActionPrompt.luau:172`, `TextInputPrompt.luau:113`), RichText on.

All dialogs resolve by calling the `OnResolution` that `DialogController` injects (`AppDialogs.luau:182-194`). Client-driven call:

```lua
local dialog = appDialogs.new("ButtonPrompt", {
	Title = "Sell Item",
	Text = appDialogs.FormatBrackets(`Sell |{displayName}| for {priceText}?`),
	Buttons = { { Text = "Sell", Color = Styles.GREEN }, { Text = "Cancel", Color = Styles.RED } },
	OffsetX = 0.1,
})
dialog:Fire():andThen(function(choice) ... end)      -- U:Pages/Inventory/InventoryComponent.lua:214-229
```

Server-driven: `DialogService:CreateDialog(player, type, props, timeout)` (default timeout 120 s) and `:CreatePromptSelection(player, items, props, timeout)` (`DialogService.luau:50,80`).

Queue behaviour: one dialog on screen at a time, FIFO (`AppDialogs.luau:171-199`). While a kitchen-guided dialog is open, the button whose label equals the guided choice gets a pulsing `GOLD` outline: `UIStroke` named `GuidePulse`, thickness 4, tween 0.6 s Sine InOut, transparency 0 to 0.8, repeat forever with reverse (`AppDialogs.luau:46-48,98-128`). Reuse that exact mechanism for guidance; do not add another highlight style.

### 3.6 HUD pieces (`U:Components/Core/Hud/`)

Section 6 lists the composition; summary:

- **`TopBar`**: time pod (shows literal "12:34 PM", `TopBar.luau:128`; `UNVERIFIED (source only)` whether the time updates, no code updates it) plus three `HudTabButton`s Shop, Menu, Inventory in a `GREEN` base with `OFFWHITE` border (lines 100-185). Also creates the register `ProximityPrompt`s (`ObjectText "Register"`, `ActionText "Use Ordering System"`, `UIOffset (0,25)`, `HoldDuration 0`, lines 66-82).
- **`BottomLeft`**: bottom-aligned column; `CurrencyPanel` with `NormalButton`s in LayoutOrder: shift timer (admins) 0, Clock In/Out 1, Staff Guide 2, Points 3, Bucks 4, with the toast above (lines 306-371). Optional capsule hatch image button with a countdown (lines 269-304).
- **`BottomRight`**: empty container, reserved.
- **`OrderQueue`**: panel + border + `Banner` "Order Queue" + status line + `PromptButton` "Leave Queue" (`CORAL`).
- **`OrderTicket`**: prototype, see 6.6.
- **`SmallNotification`**: toast, see 7.

### 3.7 Decoration

- **`BackgroundSpotlight`** (`Decoration/BackgroundSpotlight.luau`): rotating image 127221443901777, aspect 1, size (1.75,1.75) default, ZIndex 0, one turn per `ANIMATE_TIME 10` s. `Native` merges over defaults.
- **`FloatingErrorText`**: unreferenced; says to render inside a `BillboardGui` (header comment). Random drift/wobble/fade per mount. Not a model.

### 3.8 Page-local components worth reusing

| Component | Path | What it is |
| --- | --- | --- |
| `ShopCategory` | `U:Pages/Shop/ShopCategory.luau` | Header image + `ShopItem` rows + footer; optional expandable sub-rows; props `Title`, `Items {Label, Price?, SubItems?}`, `LayoutOrder`, `Color`, `OnPurchase`. Header slice `Rect(0,0,1019,40)`, size (0.981,0.065) `RelativeXX`, title left aligned (lines 130-155). Used by Currency, FoodMenu, Purchases. |
| `StatCard` | `U:Pages/Menu/Statistics.luau:55-100` | Denk label over Fredoka value; hidden stats show `???` in `GOLD_MID`/`GOLD`. |
| Toggle / Action pill | `U:Pages/Menu/Settings.luau:60-180` | 80x30 px (`px`) pill; knob 34x22; ON `GREEN_LIGHT` track, OFF 170,170,170; label "ON"/"OFF". |
| `SettingCategory` | `Settings.luau:~230-355` | `ShopCategory`-style card with header "SETTING" subtitle. |
| `TopBar` (ordering) | `U:Pages/Ordering/TopBar.luau` | Coloured sub-page bar, "<" back, centred title. |
| `OrderItem`, `AddonCheckbox`, `RightPanel` | `U:Pages/Ordering/` | Ordering-terminal parts (orange theme, 9.1). |

### 3.9 Hooks and utilities

`usePx` (2.1), `useCamera` (current camera), `useEventListener(event, listener, options)`, `usePrevious`, `useLatest`, `Hooks/useClock` (a React **binding** that advances each `PostSimulation`; use with `:map`, as `BackgroundSpotlight.luau:33-47`), `Utility/useClock` (returns a number and re-renders every Heartbeat; used only by `ItemCard.luau:331` and the unreferenced `_Featured`), `joinDicts`, `nextOrderFunctionFactory`, `sizeFromAutomaticSize`, `getScrollVisibleRange`, `mapItemDefsToInventory` (story/preview data).

### 3.10 Sounds

UI sounds come from instances authored in the place (not in Rojo): `SoundService.SFX.UI.<name>` else `SoundService.UISounds.<name>`; a missing sound is skipped silently (`AppDialogs.luau:34-42`, `ActionPrompt.luau:22-30`).

- `Pop1` plays when a dialog is fired/rendered (`AppDialogs.luau:217`; also `ActionPrompt.luau:71`, once per render).
- `Pop2` plays when a dialog resolves (`AppDialogs.luau:222`, `ActionPrompt.luau:67`).
- Nothing else makes a sound: buttons, pages and toasts are silent. The page "woosh" and toast sound are commented out (`Page.luau:55`, `SmallNotification.luau:138-143`). `Notification.SoundEnabled` is accepted but unused.
- Spill sounds use `SoundService.SFX.<name>` (`client/Modules/SpillController.lua:50-56`).

---

## 4. Structure recipes

### 4.1 A new full Page (model: Shop and Inventory)

1. Create `U:Pages/<Name>/init.luau` returning `function(props)`. `App` passes `props.Args` (extra args from `SetCurrentPage(page, ...)`) and `props.ClosePage` (`App.luau:49-59`).
2. Return `c(OpenableMenu, { TitleText, TitleColor = Styles.GREEN, DefaultPage, Pages = PAGES, OnClose = function() props.ClosePage() end })`. Build `PAGES` as `{Key, Label, Content = c(require(script.<Tab>))}`; honour `props.Args[1]` as the landing tab (`Shop/init.luau:53-62`). Do not forget `OnClose`: Menu omits it and its close button does nothing (9.9).
3. Each tab is a function returning a full-size transparent `Frame`: `Title` `TextLabel` first (see 4.1a), then a `ScrollingFrame` (2.5), then the content.
4. Register the page: add a `HudTabButton` in `Hud/TopBar.luau` (`setPage(Pages.<Name>)`, `Text`, `TextColor3 = Styles.OFFWHITE`, `LayoutOrder`) or a `NormalButton` in `BottomLeft` that calls `props.SetCurrentPage(UI.Pages.<Name>, "<tab>")` (`BottomLeft.luau:348-358`). Pressing the same entry again closes the page (`App.luau:36-43`). Opening a second page closes the first, waits `PAGE_SWAP_DELAY 0.025` s (`App.luau:17,28-33`).
5. Add `Stories/<Name>.story.luau` modelled on `Stories/Shop.story.luau` (a 0.7x0.7 centred frame holding the page with `Args`).

**4.1a Tab title (copy exactly, 14 files):** `TextLabel`, `AnchorPoint (0.5,0)`, `BackgroundTransparency 1`, `FontFace Styles.FONT_FREDOKA`, `Position (0.470149,0)`, `Size (0.94,0.09)`, `TextColor3 Styles.GREEN`, `TextScaled true` (`Currency.luau:42-51`). Optional hint line under it: `Position (0.5,0.095)`, `Size (0.94,0.085)`, `GRAY`, scaled (`Pets.luau:112-121`); `FoodMenu` shrinks it to height 0.048 and wraps (`FoodMenu.luau:143-153`).

**Stand-alone page without tabs** (Staff Guide model, `Recipes/init.luau`): `Page` + a card frame (`ROSE_MID`, `CORNER_CARD`, `OFFWHITE` stroke 3.5, aspect 0.75, pos (1.05,0.5), size (0.65,0.85)) with a `TopBar` of two text-button tabs (selected tab gets a `ROSE_DEEP` stroke) and a `ROSE_DEEP`-scrollbar (thickness 10) text scroller of `OFFWHITE` rich text at `px(35)` (lines 34-165). It has no close button; it closes by re-pressing its HUD entry.

### 4.2 A new Dialog (model: ButtonPrompt, AppDialogs)

Use an existing type when possible: confirmation = `ButtonPrompt`, choose-an-action = `ActionPrompt`, pick-one-of-many with images = `PromptSelection`, free text = `TextInputPrompt`, capsule reveal = `CapsuleOpening`.

To show one:
- Client: `Knit.GetController("DialogController").new("<Type>", props):Fire():andThen(function(value) ... end)`.
- Server: `DialogService:CreateDialog(player, "<Type>", props, timeout):await()`; resolution value is the pressed button's text (or index for `PromptSelection`, `nil` on dismiss/timeout/leave).
- Emphasis in `Text`: `[bracketed]` becomes gold, `|piped|` becomes red via `DialogController.FormatBrackets` (client) or `DialogService.FormatBrackets` (server, gold only).

To add a dialog type (needs approval for any new look): copy `ButtonPrompt.luau`, keep the shell: function `(props)`, `closeFnRef = React.useRef(nil)`, build the panel `Frame` with `AnchorPoint (0.5,0.5)`, `Position (0.5 + OffsetX, 0.5)`, an `AspectRatio` and `UISizeConstraint`, then `return c(Page, { IsVisible = true, PageContent = promptElement, OnClosing = function(cb) closeFnRef.current = cb end })`. On any button: call `closeFnRef.current()` first, then `props.OnResolution(value)` (`ButtonPrompt.luau:37-43`). Pickers that need a screen overlay follow `PromptSelection` (own springs, black overlay at transparency 0.5, click-away unless `IsTip`).

Panel bodies: description `GREEN_LIGHT`, scaled, RichText, max 28-30; buttons `PromptButton`; title `Banner` in `GREEN`.

### 4.3 A HUD element (model: OrderQueue; layout rules from TopBar/BottomLeft)

1. File in `U:Components/Core/Hud/<Name>.luau`, function component, header comment, `--!nonstrict` if it talks to Knit.
2. Subscribe in `React.useEffect` guarded by `RunService:IsRunning()` so stories render; snapshot current controller state on mount, connect signals, disconnect in the cleanup (`OrderQueue.luau:51-66`).
3. Return `nil` when there is nothing to show (`OrderQueue.luau:68-71`).
4. Anchor to an edge and size by scale + `AspectRatio` + `UISizeConstraint` (`OrderQueue.luau:75-89`). `ZIndex = 10` for overlay-style pieces.
5. Build the surface with the 9-slice panel + border + `Banner` title when it is a titled card (`OrderQueue.luau:91-165`), or a `NormalButton` row when it is a button.
6. Mount it as a child of `Hud/init.luau` (`Hud/init.luau:46-47`).
7. Do not occupy a corner another piece already uses (2.4); stop and ask if there is no free zone.

### 4.4 A toast / notification

Push with the existing API only (no new toast visual):

- From client code: `Knit.GetController("DialogController"):Toast("<plain text>")` (`AppDialogs.luau:247-249`; example `client/Modules/KitchenController.luau:92`).
- Direct: `SmallNotification.Push({ Text = "...", Image = "rbxassetid://..."? })` (`SmallNotification.luau:76-78`).
- From server: `DialogService:Notify(player, notification)` forwards to the same `Push`.

Behaviour: panel springs open from 0 to 135 px with `{mass 1, tension 280, friction 35}`, waits 0.8 s, fades text in, holds 5 s, fades out, waits 0.35 s, closes, waits 0.9 s; a new push replaces the current one immediately (`SmallNotification.luau:129-179`). Panel is the 9-slice image, inner tinted border `Color3.fromRGB(124,103,89)`, icon `Fit` aspect 1 size (0.55,0.55), centred `OFFWHITE` Fredoka text (lines 197-246). Rotating hint toasts post every 60 s (lines 99-113).

**Payload warning:** the component renders only `Text` (and optional `Image`). Callers that send `Title` and `Description` (`Ordering/init.luau:284-287`, `server/Scripts/PromoCodes.server.luau:172`, `server/Modules/SpillService/Spill.luau:244-247`) produce an empty label. Send `Text`. See 9.8.

Kitchen toast rules (client): cooldown 1.5 s per distinct message (`KitchenController.luau:30,314-316`); wording is "Next: <step label>" (`client/Modules/KitchenGuidance.luau:148`) and "Clock In to use the kitchen. Tap the clock button." (`KitchenController.luau:395`).

### 4.5 A world-space BillboardGui

Three precedents exist; pick by purpose.

| | NPC order bubble | Player overhead | Pet overhead |
| --- | --- | --- | --- |
| Built by | server (`Npc.luau:139-196`) | client script (`client/Scripts/PlayerOverheads.client.luau:99-143`) | client (`client/Modules/Pets/PetFollowerRenderer.luau:260-292`) |
| Size | `UDim2.fromOffset(200,64)` | `UDim2.fromScale(4,2.5)` (studs), `SizeOffset (0,1.125)` | `UDim2.fromScale(3.5,2)` (studs) |
| Surface | card `Frame` `CREAM`, radius `CORNER_BUTTON`, stroke `GREEN` 2 | none, text on transparent | none |
| Text | `FONT_FREDOKA`, `GREEN_DEEP`, scaled, wrapped, inset (8,4) | nickname Denk One; username SourceSansPro Bold; role SourceSansPro italic | Denk One name; SourceSansPro Bold tier line coloured by tier |
| Flags | `AlwaysOnTop true`, `LightInfluence 0`, `MaxDistance 80`, `StudsOffset (0,3.5,0)` | defaults | `AlwaysOnTop false`, `LightInfluence 0`, `MaxDistance` from `PetFollowerRenderer` config |
| Extra | patience bar: track `GRAY`, fill `GREEN`/`GOLD_MID`/`RED` by state (`Npc.luau:174-203,329-330`), pill radius `CORNER_FULL` | | |

Steps for a card-style bubble (the NPC bubble is the only styled one, so replicate it): `BillboardGui` with `Adornee`, offset-sized card `Frame` (`BackgroundColor3 Styles.CREAM`, `BorderSizePixel 0`), `UICorner` `Styles.CORNER_BUTTON`, `UIStroke` `Styles.GREEN` thickness 2, a transparent scaled-text `TextLabel` with `Styles.FONT_FREDOKA` and `Styles.GREEN_DEEP`, progress/patience track `Styles.GRAY` with pill ends. On the server there is no React; build with `Instance.new` as `Npc.lua` does and parent last (`gui.Parent = model`, line 193). For free-floating text with no card, follow the overhead scripts (white text, scaled).

Does the NPC bubble match the documented conventions? Tokens: yes (colours, font, corner radius, stroke all from `Styles`). Differences from the rest of the UI, to keep in mind and not extend without approval: it is pixel-sized (no `usePx`), `CREAM` and `GREEN_DEEP` text appear nowhere else in 2D UI, its stroke is 2 (HUD ticket uses 1), and it has no `UITextSizeConstraint` on scaled text. See 9.10.

World-space adornments (not GUI) use `GOLD`: `Highlight` fill `GOLD`, outline `GOLD_DEEP`, fill transparency 0.65, `AlwaysOnTop` (`KitchenController.luau:34,168-175`); `Beam` colour `GOLD`, width 0.35, transparency 0.35, `FaceCamera`, `LightEmission 0.5`, 20 segments (`KitchenController.luau:35-36,183-195`). `ProximityPrompt`s set `ObjectText`/`ActionText` in Title Case, `RequiresLineOfSight false` (`server/Modules/KitchenService/PromptBuilder.luau:41-45`, `OrderService.luau:897-905`).

---

## 5. Motion

| What | Config | Where |
| --- | --- | --- |
| Standard spring (buttons, hovers, toggle) | `SPRING_STANDARD {mass 1, tension 10000, friction 150}` | `Styles.luau:40` |
| Card spring (pets, `_Featured`) | `SPRING_CARD {mass 1, tension 10000, friction 200}` | `Styles.luau:41` |
| Page open/close | `{mass 1, tension 2500, friction 100}`, (0.5,0.65)/0.6 to (0.5,0.5)/0.8 | `Page.luau:24-35` |
| Page swap delay | 0.025 s | `App.luau:17` |
| Toast slide / fade | slide `{1,280,35}` ("bouncy Back"), fade `{1,10000,150}`; hold 5 s; waits 0.8 / 0.35 / 0.9 | `SmallNotification.luau:63-65,148-165` |
| Shop row expand | `{mass 1, tension 400, friction 36}`, 40 px rows (`px`) | `ShopCategory.luau:23-24,39-54` |
| PromptSelection panel | open `{0.85,430,30}`, close `{0.85,1000,34}`; scale 0.75 to 1, y 0.56 to 0.5; overlay transparency 1 to 0.5; close sends result after 0.15 s | `PromptSelection.luau:20-22,259-290` |
| PromptSelection choice pop | `{0.7,500,20}`, staggered reveal 0.05 s per button | `PromptSelection.luau:145-152`, line 22 |
| Item card price stroke | `{0.5,15000,150}` | `ItemCard.luau:326` |
| Capsule reveal | pop `{1,170,26}` (scale 0.5 to 1, y 0.8 to 0.5); swap `{0.9,200,20}`; resolves 2 s after click | `CapsuleOpening.luau:80-109`, line 157 (Core) |
| Guidance pulse | `TweenService` 0.6 s Sine InOut, infinite reverse | `AppDialogs.luau:47` |
| Spinner | clock-driven `easeInOutBack`, period 1.4 s | `InventoryComponent.luau:329-343` |
| Spotlight | 360 degrees per 10 s | `BackgroundSpotlight.luau:23,43-47` |

Press feedback (scale, the pair is press / hover): see the table in 9.5. Rules from code: animate `UIScale` (via `Pane`'s `Scale`) or colour, never raw `Size`, for hover/press; no elastic bounce on text controls other than the toast slide; clean up per-frame work in the effect's return (`useClock`, `BottomLeft.luau:134-136`); gate runtime-only work with `RunService:IsRunning()` so stories do not error.

---

## 6. HUD composition (what exists today, for the coming UI)

### 6.1 Zones in use
Top centre: time pod and tabs. Bottom left: currency/shift/guide stack and the toast above it. Right-centre-low: order ticket (pos (0.99,0.92), anchored bottom-right). Bottom centre (y 0.92): order queue. Bottom right: reserved, empty. The earlier design target "ticket and card top-left, toasts top-centre" (`.review/.../M1.2/design.md:153`) is a plan, not the code; the code puts toasts at bottom-left and the ticket on the right. Any new element in a different zone needs approval.

### 6.2 Top bar, 6.3 bottom-left, 6.4 queue
See 3.6 and the line ranges there.

### 6.5 Toast
See 4.4.

### 6.6 Order ticket (`U:Components/Core/Hud/OrderTicket.luau`)
Declared "Prototype HUD overlay ... Intentionally unstyled — use plain colours only so this can be skinned later" (header, line 6). It is the one HUD piece built from raw `Frame`/`TextLabel` instances with pixel sizes and fixed `TextSize`, not `Pane`. Structure as it stands:

- Card: anchor (1,1), pos (0.99,0.92), width 190 px, `AutomaticSize Y`, `BackgroundColor3 Color3.fromRGB(245,245,245)`, radius 6 px, `GREEN_DIM` stroke 1, ZIndex 10, vertical list (lines 219-238).
- Header: height 28, `GREEN` fill, radius 6 with a 6 px bottom blocker to square the bottom, text "Order Ticket" `OFFWHITE` `TextSize 15` (lines 241-264).
- Items: each `ItemRow` is an `OFFWHITE` frame with padding 4/8, vertical list gap 2, name `GREEN_DEEP` size 15 left aligned, then customisation lines `GRAY` size 13 (gap 1) in the form `Syrup: Blueberry`, `+ Boba`, `- NO Ice` (lines 74-141, 49-69). A 1 px `GRAY` divider separates items (lines 183-190).
- Footer: when `ReadyNode` exists, `GREEN` bar, text "Ready for Pick Up!" `OFFWHITE` scaled, 20 px high (lines 198-217).
- Data: `Knit.GetController("OrderController")`, `CurrentOrder`, `ReadyNode`, signals `OrderChanged`, `ReadyNodeChanged` (lines 150-172). Renders nothing with no order.

**Rule for extending the ticket (recipe card, step list):** add new sections as further children of the same vertical list using the same primitives: an `OFFWHITE` frame with the 4/8 padding, `FONT_FREDOKA` text, `GREEN_DEEP` for names at size 15, `GRAY` for detail lines at size 13, a 1 px `GRAY` divider between groups, `GREEN` for header or ready bars with `OFFWHITE` text. Do not reskin the ticket into the Pane/image look; that is a new pattern and needs Jack. `UNVERIFIED (source only)`: how the ticket looks at phone scale (it is a fixed 190 px wide).

---

## 7. Copy

- **Casing.** Titles, buttons, tabs, banners and prompt text are Title Case: "Order Ticket", "Order Queue", "Staff Guide", "Clock In", "Clock Out", "Leave Queue", "Add to Order", "Promo Codes", "Food Menu", "Server Info" (`BottomLeft.luau:332,339`, `OrderQueue.luau:137`, `SizeOptionsPage.luau:260`, `Menu/init.luau:32-81`). Status and hint lines are sentence case: "You're next!", "Order full (3/3)", "No purchases found.", "Loading purchases..." (`OrderQueue.luau:40`, `SizeOptionsPage.luau:274`, `Purchases.luau:88,98`).
- **Button verbs.** Plain action verbs: Submit, Cancel, Close, Sell, Rename, Equip, Unequip, Hatch, Open, Yes, No. Cancel/negative on the right and red or coral. Confirm buttons say the action ("Sell"), not "OK".
- **Tone.** Short, friendly, functional. Hints end with a period or exclamation (`Pets.luau:118`, `SmallNotification.luau:42-60`). Errors say what to do next: "Please wait before placing another order.", "You already have an order in progress." (`OrderService.luau:816,847`). Capsule hint: "Your capsule is ready to be hatched!\nClick to open." (`CapsuleOpening.luau:208`).
- **Sentence templates.** Rename help: "Enter a new name. Leave blank to reset. Max %d characters." (`InventoryComponent.luau:236-239`). Confirm: "Sell |name| for [N Boba Bucks]?" (line 216).
- **Emphasis.** `[gold]` for values/names being highlighted, `|red|` for the thing being lost or the error (`AppDialogs.luau:130-133`).
- **Numbers and currency.** Prices and counts are strings with thousands separators: "1,300", "20,000" (`Currency.luau:21-33`). Currency names: "Boba Bucks", "Points" (staff points); stat labels "Boba Bucks Earned". ShopItem prefixes a currency glyph `"\u{e002} "` (`ShopItem.luau:99`); card and capsule prices are stored with a leading space, `" 199"`, `" 150"` (`Passes.luau:27`, `Capsules.luau:13`). `UNVERIFIED (source only)`: whether the leading space stands in for a glyph that did not survive; copy the form already used by the surface you extend. Free-form amounts: "Free w/ Roblox Premium" (`Celebrity.luau:191`).
- **Time.** Hatch and shift timers `MM:SS` (`BottomLeft.luau:52-57`); time played `HH:MM:SS` (`Statistics.luau:32-37`); dates `%b %d` and month headers `%B %Y` (`Purchases.luau:30,38`).
- **Order text.** Variant first then item: "Blueberry Custom Boba"; customisation lines "Syrup: X", "+ Option", "- NO Option" (`OrderTicket.luau:36-69`). Count format `Order (%d/%d):` (`RightPanel.luau:158`).
- **Rich text** in static content uses `<font face="DenkOne">` for answers, `<u>` for section headings, `<i>` for "(Opt.)" (`Recipes/Content.luau`).
- **Tabs and titles.** The tab label and its title normally match ("Currency", "Pets", "Game Passes" being the exception for the tab "Passes", `Passes.luau:89`).

---

## 8. Mapping for the coming UI (closest existing pattern, and where to stop)

| Planned UI | Build from | Stop and ask if |
| --- | --- | --- |
| Recipe card on the HUD order ticket | Extend `OrderTicket` rows (6.6): same primitives, tokens and text sizes | you want images, a new card surface, a new colour or an animation on the ticket |
| NPC order ticket (world) | `Npc.buildBubble` as shipped (4.5): `CREAM` card, `GREEN` stroke, `GREEN_DEEP` Fredoka text, patience bar | you want icons, a second card style or a different size |
| End-of-shift card | A dialog: `ButtonPrompt` with `Title` banner, rich `Text` using `[gold]` values, one or two `PromptButton`s; numbers laid out like `StatCard` (Denk label, Fredoka value, `GREEN_LIGHT`/`GREEN`) | you want a results grid, a new panel look, confetti, or sounds beyond Pop1/Pop2 |
| Shop wiring | Existing `Shop` tabs: `ShopCard` grids, `ShopCategory` rows (`OnPurchase`), `PurchaseButton`; purchase prompt via `MarketplaceService:PromptProductPurchase` as in `BottomLeft.luau:280` | you need a new tab colour, a new card type or a purchase-confirm layout other than `ButtonPrompt` |

Fact for shop wiring: none of the current shop cards or rows have a click handler (`Passes.luau:69-76`, `Pets.luau:85-92`, `Currency.luau:69-79`; `ShopCategory` accepts an optional `OnPurchase` at lines 111,188-190).

---

## 9. Inconsistencies found

Counts are from the whole `src` tree as of the commit above. "Replicate" names the pattern to copy. Outliers are listed so you can recognise them; do not copy them and do not fix them unprompted.

### 9.1 Two visual themes
- Dominant (everything except the ordering terminal and MobileOrder): sage/rose/gold tokens, Fredoka, pill shapes.
- Ordering terminal (light neutral panel with orange accent): `ORANGE = Color3.fromRGB(237,114,47)` literal in 3 files (`AddonCheckbox.luau:30`, `RightPanel.luau:14`, `SizeOptionsPage.luau:12`), `Color3.fromRGB(224,94,88)` in 2 (`Ordering/TopBar.luau:28`, `Ordering/init.luau:33`), `fromRGB(202,202,202)` in 2 (`OrderItem.luau:118`, `RightPanel.luau:170`), plus 230,230,230 / 51,51,51 / 74,74,74 / 25,25,25 (`RightPanel.luau:46`, `Ordering/init.luau:350,389`, `PlayerSelectPage.luau:94`).
- MobileOrder: 8 literal colour constants plus 12 inline (`MobileOrder/init.luau:18-25` and lines 497-1127), 0 `Styles.` uses, Gotham font (27 uses), radii in pixels.
- Replicate: sage/rose/gold tokens for new UI. Edit the ordering terminal only with its own palette (it is its own theme); do not carry orange or neutral grays into new UI.

### 9.2 Hard-coded colours bypassing `Styles` (outside `Styles.luau`, excluding stories)
53 `Color3.fromRGB` literals in 18 files: `MobileOrder` 20, `FloatingErrorText` 7, `_Featured` 5, `Ordering/init` 3, `RightPanel` 3, `Settings` 2 (`:30` 210,230,200 subtitle; `:76` 170,170,170 toggle-off), `ViewportModel` 2 (`:87-88`), and 1 each in `FlavorCard:33`/`PlayerCard:33` (217,217,217 card tint), `ItemCard:261` (30,30,30 count badge), `OrderTicket:223` (245,245,245), `SmallNotification:212` (124,103,89), `Collection:119` (60,60,60), `Ordering/TopBar:28`, `OrderItem:118`, `AddonCheckbox:30`, `PlayerSelectPage:94`, `SizeOptionsPage:12`. Also `Color3.new(0,0,0)` / `Color3.new(1,1,1)` used for overlays, strokes and text (49 white text uses vs 12 `OFFWHITE`, see 9.3). Data files hold more (`Tiers.luau`, `Ordering/Menu.luau`).
- Replicate: a `Styles` token or a lerp of one (1.2). Where no token matches a needed colour, stop and ask.

### 9.3 Light text colour
| Variant | Count | Where |
| --- | --- | --- |
| `Color3.new(1,1,1)` on coloured fills | 49 | buttons, cards, banners, rows |
| `Styles.OFFWHITE` | 11 | HUD chrome: `NormalButton:86`, `BottomLeft:296`, `SmallNotification:240`, `OrderTicket:214,261`, `TopBar:170-182`, `Recipes/init:57,130,149` |
| `Color3.new()` black | 9 | ordering terminal, FlavorCard |
- Replicate: white for text on a coloured control; `OFFWHITE` for HUD chrome and toast text.

### 9.4 Corner radius per role
- Full/pill: literal `1` or `UDim.new(1,0)` 10 times (excluding MobileOrder and `_Featured`) vs token `CORNER_FULL` 2 (`ItemCard:372`, `Collection:127`). Same value. Replicate: use the token `CORNER_FULL`.
- Button radius takes five values: 1 (`NormalButton:44`), 0.5 (`HudTabButton:67`), 0.25 (`PromptButton:33`, `PromptTextBox:29`, `PromoCodes:205`), 0.2 (`PurchaseButton:40` via `CORNER_BUTTON`), 0.1 (`ActionButton:61`). Replicate: the radius of the component you are extending; for a new dialog button use `PromptButton`.
- Card radius: 0.06 (`CORNER_CARD` x4 plus `CapsuleTierGroup:86`) dominant; outliers 0.05 (`ActionPrompt:132`), 0.2 (`Celebrity:74,105`), 6 px (`OrderTicket:229,247`).
- `CORNER_PILL` (0.4) is unused; only `_Featured:249` uses 0.4 as a literal.

### 9.5 Hover / press scale
| Press / hover | Components |
| --- | --- |
| 0.93 / 1.07 | `PromptButton:27`, `SelectionCard:50` |
| 0.94 / 1.06 | `FlavorCard:50`, `PlayerCard:69`, `PromptSelection` choice (0.93/1.06, `:146`) |
| 0.95 / 1.05 | `ActionButton:53` |
| 0.95 / 1.08 (pet 1.1) | `ItemCard:315` |
| 0.9 / 1.15 | `CloseButton:31` |
| 1 / 1.1 (no shrink) | `HudTabButton:36` |
| 1 / 1.05 (no shrink) | `PurchaseButton:34` |
| colour only | `ShopItem:39` |
- Replicate: copy the pair of the nearest sibling component. For a new dialog-style button use 0.93/1.07 via `PromptButton`; for a new card use 0.94/1.06 or `SelectionCard`'s. Do not invent a new pair.

### 9.6 Duplicated blocks (copy-paste instead of a shared component)
- Tab page title block: 14 copies with the identical geometry (list in 4.1a); 3 pages differ: `Statistics.luau:167-175` (left-aligned, pos (0,0), size (1,0.09)), `Credits.luau:45-49` and `ServerInfo.luau:104-108` (Fredoka 0.1-high label inside a list, with Denk One for sub-labels). Replicate the 14.
- Item grid constants `CellSize (0.212,0.288)`, `CellPadding (0.043,0.03)`, 0.02 padding: 6 copies (`Passes:46-56`, `Featured:33-43`, `Particles:31-41`, `DirectCosmeticsPurchase:34-44`, `Collection:162-172`, `InventoryComponent:350-360` with top 0.01). Replicate the 0.02 version.
- Scroll area geometry: `(0,0.112)/(1,0.888)` list pages (`Currency:58-62`, `Purchases:132-136`); `(0,0.112)/(1.02,0.888)` grid pages (6 files); `(0,0.148)/(1,0.852)` `FoodMenu:160-164`; `(0,0.1)/(1,0.9)` `PromoCodes`, `Settings:526-540`; whole-page scroller `Pets`, `RandomCosmeticsPurchase`. Replicate by page type: list = first, grid = second.
- Close button: component `CloseButton` (pos (0.98077,0.147523), animated) used by `OpenableMenu`; inline re-implementation with a different position (0.936353,-0.0389084), size (0.094,0.144) and no animation at `Ordering/init.luau:569-608`. Replicate the component.
- Dialog chrome: image panel (`ButtonPrompt`, `TextInputPrompt`, `OrderQueue`, 3) vs plain `OFFWHITE` frame with stroke (`ActionPrompt` stroke 5, `PromptSelection` stroke 4, 2). Replicate: image panel for confirm/text prompts and titled cards, plain frame for action lists and pickers.
- Banner size in panels: height 0.371931 (`ButtonPrompt:132`, `OrderQueue:163`), 0.35 (`TextInputPrompt:151`), 0.15 (`ActionPrompt:127`). Replicate per parent.
- Spinner and `easeInOutBack`: duplicated in `InventoryComponent:329-343` and `Settings:25-47`.
- Unique customisation line helper duplicated 5 times (`OrderTicket:50`, `Ordering/init:52`, `MobileOrder:54`, `Stories/Ordering:40`, `OrderItem` consumer).

### 9.7 Scrollbar
- Thickness 5: 21 uses (dominant); 4: `PromoCodes:127`, `Settings:533`, `_Featured:438`; 10: `Recipes/init:42`.
- Colour: black `Color3.new()` 24 uses; `ROSE_DEEP` at `Recipes/init:43` only.
- Hidden (`ScrollBarImageTransparency 1`) on 6 grid pages (`Collection:230`, `InventoryComponent:579`, `Featured:89`, `Passes:101`, `Particles:87`, `DirectCosmeticsPurchase:91`); visible elsewhere.
- Replicate: thickness 5, black, hidden on grid pages and visible on list pages.

### 9.8 Toast payload mismatch
`SmallNotification` reads `current.Text` only (`SmallNotification.luau:239`). `DialogController:Notify` and `DialogService:Notify` are typed `{Title, Description, Image, SoundEnabled}`. Three callers send `Title`/`Description` and so render a blank label: `U:Pages/Ordering/init.luau:284-287`, `server/Scripts/PromoCodes.server.luau:172`, `server/Modules/SpillService/Spill.luau:244-247`. The working path is `DialogController:Toast(text)` (`AppDialogs.luau:247`). `Stories/SmallNotification.story.luau:25-41` also sends `Title`/`Text`. Replicate: send `Text`.

### 9.9 Close handling
- `Shop` and `Inventory` pass `OnClose = function() props.ClosePage() end` (2).
- `Menu` passes none (`Menu/init.luau:26-29`), so its `CloseButton` does nothing; `Recipes` has no close button and a no-op `OnClosing` (`Recipes/init.luau:162-164`).
- Replicate: pass `OnClose` through to `ClosePage`.

### 9.10 Billboard styling
`Npc.luau` bubble uses tokens (CREAM, GREEN, GREEN_DEEP, GRAY, FONT_FREDOKA, CORNER_BUTTON, CORNER_FULL); the two client overhead scripts use no tokens (white text, SourceSansPro and DenkOne literals: `PlayerOverheads.client.luau:117,127,139`, `PetFollowerRenderer.luau:271-272,284`). Sizes: offset-based (NPC) vs stud-scale (overheads); `AlwaysOnTop` true (NPC) vs false (pets); stroke 2 (NPC) vs 1 (ticket). Replicate: NPC bubble for cards, overhead scripts for bare text.

### 9.11 Fonts outside the two tokens
- `Font.new("...FredokaOne.json")` literal instead of `FONT_FREDOKA`: `Banner:52`, `ServerInfo:107`, `Credits:48`, `MobileOrder:593`. `DenkOne.json` literal: `ServerInfo:35`, `Credits:30`, `PlayerOverheads:139`, `PetFollowerRenderer:284`.
- Other families: SourceSansPro (`HudTabButton:59` is dead because `Text = ""`; `Ordering/init:400` notepad box; two overhead scripts), Nunito Bold (`OrderItem:30`), GothamSSm (27 uses, `MobileOrder` only).
- Replicate: the tokens.

### 9.12 Unused or misdocumented
- Tokens unused: `GREEN_TEXT`, `CORNER_PILL`; `ROSE_TEXT` and `GOLD_BADGE` have one use each (`GOLD_BADGE` only in `RequiredSelectionPage:44`).
- `ActionButton.luau:2-5` says it is a "sliced background image" button, but it paints a solid colour; `BUTTON_IMAGE` (`:34`) is never used and is the same asset ID as the checkbox image (`AddonCheckbox.luau:31`).
- `TopBar.luau:1-7` and `BottomLeft.luau:1-7`, `BottomRight.luau:1-7` headers all say "Hud" (copy-paste).
- Unreferenced: `FlavorCard`, `FloatingErrorText`, `PlayerSelectPage`, `_Featured`, `MobileOrder` (story only).
- Hover pair for `PromptSelection` is 0.93/1.06 (differs from `PromptButton` 0.93/1.07).

### 9.13 Copy
- Featured tab page is titled "Particles": `Featured.luau:77` (tab label "Featured", `Shop/init.luau:27`). Nametag tab titles differ by variant: "Nametag Cosmetics" (`RandomCosmeticsPurchase:116`) vs "Nametag Colors" (`DirectCosmeticsPurchase:79`). Tab "Passes" vs title "Game Passes" (`Passes.luau:89`).
- Negation in order lines: "- NO" (`OrderTicket:63`, `Ordering/init:63`, `Stories/Ordering:40`) vs "- No" (`MobileOrder:54`). Replicate "- NO".
- "Order full (3/3)" hard-codes the limit (`SizeOptionsPage.luau:274`) while the header builds it from `MaxOrderItems` (`RightPanel.luau:158`).
- Price strings: glyph-prefixed via code (`ShopItem:99`) vs stored leading space (9.x in section 7).
- `formatBrackets` exists three ways: client gold+red (`AppDialogs.luau:130`), server gold only (`DialogService.luau:30-32`), and local copies in stories (`ActionPrompt.story.luau:12-15`). Replicate: the client one for client dialogs.

### 9.14 Layering and insets
- App gui `IgnoreGuiInset = true`; Priority gui default false (2.3). Only `PromptSelection` compensates (`:364`).
- `ZIndexBehavior` set on App gui, not on Priority gui (`AppEntry.luau:24` vs `AppDialogs.luau:252-256`).

### 9.15 Hooks
Two different `useClock`: `Hooks/useClock` (binding) and `Utility/useClock` (number, re-renders each frame). Replicate: `Hooks/useClock` with `:map`, as the spotlight and spinner do; `ItemCard` uses the other for nametag animation only.

---

## 10. Review checklist (tick all before approving new UI)

- [ ] Every colour is a `Styles` token or a documented `Lerp` of one (1.2). No `Color3.fromRGB`, no new hex.
- [ ] Every text label uses `Styles.FONT_FREDOKA` (or `FONT_DENKONE` where 1.3 allows). No other font.
- [ ] Text colour follows 1.4; text is `TextScaled` with a `MaxTextSize` matching a sibling.
- [ ] Radius, stroke thickness and padding match the closest component in 1.6-1.8, using the token where one exists.
- [ ] Built from existing components (`Pane`, `PromptButton`, `NormalButton`, `ItemCard`, `Banner`, `OpenableMenu`, dialogs) before any raw instances.
- [ ] Sized with scale, `AspectRatio` and `usePx`; min/max via `UISizeConstraint` where HUD or dialog; no fixed pixel layout except hairlines.
- [ ] Interactive controls animate with `SPRING_STANDARD` and the sibling's hover/press pair (9.5); no new spring unless a documented one is reused.
- [ ] Siblings have `LayoutOrder`; lists use `UIListLayout` with `SortOrder LayoutOrder`.
- [ ] Page: opened via `SetCurrentPage`, passes `OnClose` to `ClosePage`, tab title block copied from 4.1a.
- [ ] Dialog: uses an existing type or follows 4.2; resolves through `closeFnRef` then `OnResolution`; sounds only Pop1/Pop2.
- [ ] HUD piece: guarded by `RunService:IsRunning()`, snapshots then listens, disconnects in cleanup, returns `nil` when empty, uses a free zone (2.4).
- [ ] Toast: sent with `Text` through `Toast`/`Push`.
- [ ] Billboard: follows 4.5; text readable at distance; `MaxDistance` set.
- [ ] Copy follows section 7: Title Case controls, sentence-case status lines, thousands separators, "- NO", emphasis via `[ ]` and `| |`.
- [ ] Loading and empty states render something sensible (spinner, "You don't have any...!", GRAY line).
- [ ] A story exists in `U:Stories/` and renders at desktop and phone aspect ratios; states inspected are recorded by Lens. Visual approval cannot come from source inspection alone.
- [ ] Nothing new was invented: no new token, component, asset, font, radius, spring or layout. Any exception is approved by Jack and named in the review.
