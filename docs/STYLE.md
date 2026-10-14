# boba-cafe UI Style

The UI is a cozy boba-cafe look: soft sage greens, rose pinks, warm gold, cream surfaces, rounded pill shapes, and springy motion. This document records the tokens and patterns the existing UI already uses so new work matches. It does not introduce a new design direction; propose one to Jack before changing the look.

## Tokens

`src/shared/UI/Styles.luau` owns the palette, fonts, corner radii, and spring configs. Import it (`local Styles = require(UI.Styles)`) and use the named value; do not copy RGB values into components.

| Family | Tokens |
| --- | --- |
| Fonts | `FONT_FREDOKA` (Fredoka One, the primary display and label face), `FONT_DENKONE` (Denk One, used for floating error text) |
| Green | `GREEN` `#8FA97F` primary (shop title, purchase button); `GREEN_MID` staff/role card; `GREEN_DEEP` shadows and description text; `GREEN_LIGHT` icons, tab text, accents; `GREEN_DIM` category header tint; `GREEN_TEXT` top-bar labels; `GREEN_BADGE` trending badge |
| Rose | `ROSE`, `ROSE_MID`, `ROSE_DEEP`, `ROSE_TEXT` |
| Gold | `GOLD`, `GOLD_MID`, `GOLD_DEEP`, `GOLD_BADGE` |
| Neutrals and alerts | `CREAM`, `OFFWHITE`, `GRAY`, `RED`, `CORAL` |
| Corner radii | `CORNER_FULL` (1, 0) circle/pill; `CORNER_PILL` (0.4, 0); `CORNER_BUTTON` (0.2, 0); `CORNER_CARD` (0.06, 0) |
| Springs | `SPRING_STANDARD` { mass 1, tension 10000, friction 150 }; `SPRING_CARD` { mass 1, tension 10000, friction 200 } |

If a needed value is missing, add a named token to `Styles.luau` (with a short comment saying where it is used) and use it, instead of introducing a one-off literal. About twenty existing UI files (for example `OrderTicket`, `SmallNotification`, `ItemCard`, `PlayerCard`, `FlavorCard`, `Pages/Shop/_Featured`, `Pages/MobileOrder`) and `shared/Ordering/Menu` still contain literal `Color3.fromRGB` values. Move those to tokens when you are already editing them; do not mass-migrate.

## Building blocks

- **`Pane`** (`Components/Pane.luau`) is the base container: it wraps Frame, ImageLabel, TextLabel, TextButton, ImageButton, and ScrollingFrame and accepts `CornerRadius`, `Stroke`, `Padding`, `AspectRatio`, `ListLayout`, `GridLayout`, `Gradient`, `Scale`, `AutomaticSize`, `MaxTextSize` (text only), `Native` (raw properties), and `OnClick` / `OnPress` / `OnRelease` / `OnHover` / `OnLeave`. Prefer `Pane` props over hand-built child instances.
- **Buttons** (`Components/Buttons/`) are the interactive atoms: `NormalButton` (pill with off-white stroke and tinted border image), `ActionButton`, `CloseButton`, `PromptButton`, `PurchaseButton`, plus cards (`ItemCard`, `ShopCard`, `PetCard`, `NametagCard`, `PlayerCard`, `FlavorCard`, `SelectionCard`). Reuse or extend one before creating another.
- **Pages** open through `Components/Core/Page.luau`, which springs a page from a smaller, lower origin (`0.6` scale, `0.5, 0.65`) to its resting size and position, and plays the reverse on close. Pages are mounted one at a time by `App`; follow the existing `OnClosing` handshake.
- **HUD** pieces live in `Components/Core/Hud/` (`TopBar`, `BottomLeft`, `BottomRight`, `OrderQueue`, `OrderTicket`, `SmallNotification`).
- **Dialogs** (`Components/Dialogs/`) are server-driven prompts: `ActionPrompt`, `ButtonPrompt`, `PromptSelection`, `TextInputPrompt`, `CapsuleOpening`. Adding a dialog type means adding a component here; `DialogService` finds it by name.
- **Decoration** (`BackgroundSpotlight`, `FloatingErrorText`) is presentation only.

## Layout and scale

- Position and size with scale (`UDim2.fromScale`) and `AspectRatio` so a component holds its proportions on every screen.
- For pixel-based sizes use `usePx` (`Hooks/usePx.luau`), which scales from a 1280x832 reference resolution and exposes `px(n)`, `px.even`, `px.floor`, `px.ceil`, and `px.scale`.
- Text is normally `TextScaled`; use `Pane`'s `MaxTextSize` cap where a label would otherwise grow too large for its container.
- Phones: check touch behavior (`UserInputService.TouchEnabled`) and use the mobile pages (`Pages/MobileOrder`) rather than shrinking the desktop page until it is unreadable. Touch targets must stay comfortably tappable.
- The app `ScreenGui` uses `IgnoreGuiInset = true`, so the UI draws under Roblox's top bar; keep interactive elements clear of Roblox's own buttons.

## Motion

- Animate with `ReactSpring` using `SPRING_STANDARD` or `SPRING_CARD` (or the page spring in `Page.luau`). Do not hand-roll tween loops or add elastic bounce on text-bearing controls.
- Hover, press, and release feedback uses `OnHover` / `OnLeave` / `OnPress` / `OnRelease` on `Pane`.
- Clean up per-frame work (`useClock` and friends disconnect in the effect cleanup).

## Copy

- Short, friendly, and functional. Prefer plain words over slogans.
- Dialog text may highlight a phrase with `[brackets]` (gold) or `|pipes|` (red) via the `formatBrackets` helpers in `DialogService` and `PlayerSetup`; keep that pattern for emphasis and errors.
- Error messages tell the player what to do next ("Please wait before claiming again."), not what went wrong internally.

## Review and validation

- Add or update a story in `UI/Stories/` for every new component or page, and check it renders at desktop and phone aspect ratios.
- A UI change is not visually approved from source inspection alone. Lens (see `AI_AGENT_WORKFLOW.md`) records the states, devices, and aspect ratios actually inspected, and which were not.
- Screens that read replicated data must render something sensible while the data is loading or missing, instead of erroring.
