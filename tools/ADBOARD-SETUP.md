# Ad boards — Studio setup

The boards are now driven entirely by `src/shared/Configuration/AdBoardConfig.luau` and
mounted by `src/client/Modules/AdBoardController.luau`. The per-board `Script`s and the
hand-built `SurfaceGui`s are no longer used.

## What changes

| Before (V3) | Now |
|---|---|
| A `Script` inside every board | One `AdBoardController` |
| A hand-built `SurfaceGui` per board, built in Studio | React components, built from config |
| Two separately authored SurfaceGuis (header + body) | Both generated from one config entry and one component tree |
| Celebrity board as a `ScreenGui` under `StarterGui.Ads` with its own `CelebrityHandler` | `CelebrityBoard` component, same abstraction as the rest |
| Pass id in a `Configure` attribute | `Id` in `AdBoardConfig.Boards` |

You do **not** need to build any UI by hand any more. The controller creates the
SurfaceGuis at runtime and **destroys any SurfaceGui already on the part first**, so
leftovers are replaced rather than layered — but deleting them keeps the place tidy and
the file smaller.

## Steps in Studio

### 1. Move the folder

The controller looks in **`workspace.Assets.Advertisements`**.

Move `Workspace/AdvertisementsFolder` → `Workspace/Assets/Advertisements`.

Keep the `Gamepasses/` and `Products/` sub-folders — the controller searches descendants,
so any nesting works.

### 2. Delete the per-board scripts

In every board model under `Advertisements`, delete the `Script`. There are 12 of them.
Leaving one in place would double-prompt on click and fight the controller for the GUI.

### 3. Delete the built-in SurfaceGuis (optional but recommended)

In each board delete:
- the `SurfaceGui` under `Union` (the body)
- the `SurfaceGui` under `Part` (the header)

### 4. Delete the Celebrity ScreenGui

Delete `StarterGui/Ads` entirely, including `Celebrity/CelebrityHandler` and the nested
`Info`/`Title`/`Description` StringValues under each perk label. All of that content now
lives in `AdBoardConfig.CELEBRITY`.

### 5. Keep these

Per board, **do not delete**:

| Instance | Why |
|---|---|
| `ClickDetector` | Clicking the board opens the purchase prompt |
| `MainColor` (`Color3Value`) | Optional per-board tint; falls back to `AdBoardConfig.DEFAULT_COLOR` |
| `Part` | Header strip — the header SurfaceGui is adorned to it |
| `Union` | Body panel — the content SurfaceGui is adorned to it |

`Configure` is no longer read and can be deleted; the pass id lives in config now.

### 6. Check the model names

Boards are matched by **Model name** against `AdBoardConfig.Boards`. A board whose name
has no config entry is skipped silently. Current keys:

```
Barista            Staff Intern       Faster Walkspeed   Instant Brewing
VIP                Korblox            Headless Head      Rainbow Pack
MopWhack           UnlimitedStock     Donate!            Celebrity
```

Rename the model or add a config entry if they disagree.

## How the header/body split is detected

The header and body are **separate parts** in the build — the header strip is about
13.1 × 1.1 studs and the body panel about 13.9 × 6.2, stacked vertically. A single
SurfaceGui cannot span two parts, so the controller adorns one to each: the **tallest**
part becomes the body, the **shortest** the header.

This is the one part of your brief I could not do literally. If you want a genuinely
single SurfaceGui, the two parts have to be merged into one in the build; tell me and
I'll collapse the components into a single tree with the header drawn as a bar inside it.

Either way the duplication you were objecting to is gone: one config entry, one component
tree, no per-board scripts, nothing authored by hand.

## Notes

- **Fun Pass** has no config entry — the pass is retired. Its board will be skipped; delete
  the model when convenient.
- **The Celebrity board's `Configure` attribute said `GamePass = 6202153`, which is
  actually Barista's id** — a copy-paste leftover in V3. Celebrity is a subscription and
  now uses the product ids in `AdBoardConfig.CELEBRITY.Tiers`.
- Prices, icons and descriptions are fetched live from Roblox, so they stay correct when
  changed on the pass. `Title`/`Description` in config override them if you want fixed text.
- Preview the boards without entering the game via `src/shared/UI/Stories/AdBoard.story.luau`
  in a story runner.
