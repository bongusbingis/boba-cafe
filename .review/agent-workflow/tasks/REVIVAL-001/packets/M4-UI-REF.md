# M4-UI-REF: Edit-mode reference captures of the existing menus and dialogs
Model: sonnet (Lens)   Studio: YES (exclusive)   Depends on: none   Size: S

## Goal
- Give the Architect and Jack reference images of the existing UI that the M4-UI-DAILY-REDO rebuild must match (DEC-013, DEC-038).
- Capture the existing OpenableMenu shell, a ButtonPrompt dialog and the Shop menu, plus one with its tab row if any menu has tabs. No lasting change to the place.

## Read (only these)
- `docs/STYLE.md`, `default.project.json` lines 1-12.
- `packets/M4-UI-APPROVAL.md` (mount helper method, Studio constraints; reuse them exactly).
- Locate the components with Grep under `src/shared/UI/Components` (`OpenableMenu`, `ButtonPrompt`, `Shop`, any `Tab`/`Tabs` component). Read only their props/top-level render, enough to mount them with realistic props.

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/M4-UI-REF/` (screenshots, evidence.md) only.
- Studio: a temporary `StarterGui._LensPreview` ScreenGui, destroyed before you finish. No repo or script edits.

## Hard constraints
- Studio target "jacks project" (placeId 89999123284040). Edit mode only. Never start Play, never run TestEZ (DEC-019). If `get_studio_state` shows Play, STOP and report it.
- Rojo serve is not running. Do not sync, edit or save the place. Staleness-check each module you mount (Studio source vs repo); on a difference, record it and keep going only if the difference is not in render code.
- Mount inside a ScreenGui with the same `ZIndexBehavior` the real client mount uses: find where the client creates its React root ScreenGui (Grep `createRoot` under `src/client`) and copy its ScreenGui properties (ZIndexBehavior, IgnoreGuiInset, DisplayOrder). Record those properties in evidence; M4-UI-DAILY-REDO needs them for the backdrop bug.

## Steps
1. Find the real client mount and record its ScreenGui properties.
2. For each of OpenableMenu (with a simple body), ButtonPrompt, Shop (first page), and any tabbed menu: mount, wait ~1 s, `screen_capture`, unmount, destroy. One component per run.
3. If a menu has a modal backdrop (darken effect), capture it as it appears with the backdrop, and note whether the backdrop is behind or over the panel in this mount.
4. Cleanup check after each run: `_LensPreview` gone, StarterGui/ReplicatedStorage child counts unchanged. Do not save.

## Done when
- Screenshots saved and listed with the component path and props used for each.
- Real-mount ScreenGui properties recorded; backdrop order recorded per menu.
- A short list of the reusable building blocks visible in them (header, close button, panel, tab buttons, primary/secondary buttons, pills) with each one's component path or "inline in <file>".

## STOP-AND-ASK
- Play mode, a component that cannot mount without Knit, or any need to edit a script or save: stop and report BLOCKED.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/M4-UI-REF/evidence.md`.
