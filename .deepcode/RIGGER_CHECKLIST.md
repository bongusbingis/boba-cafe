# Rigger Checklist — 32 FPS Map Fix (Studio, manual)

Owner: Jack (Rigger). Read-only for agents; this is manual Studio work.
Baseline: 32 FPS client, 675 MB server, 15,275 workspace instances. Measured via MCP on place `128511401637461`.

Do the steps **in order**. Save the place to a file before each step (Ctrl+S or File → Save As) so any step is undoable.

---

## Step 1 — Delete the 196 legacy ParticleEmitters under `Assets.Kitchen` (~10 min)

**Impact: safe instant win — removes 196 unused emitters (85% of all emitters in the place).**

They are confirmed legacy/unused. They live on `Sparks` parts inside each station model (`MiniSparks`, `Sparks`, `CoreMiniSparks`). The Lua code (`InteractionRunner:Run`) calls `model:FindFirstChild("Sparks", true)` then `Emit(15)` on any children — with the emitters deleted this is a **no-op** (empty children loop, or nil find), so no Lua change is needed.

How:
1. Explorer → expand `Workspace → Assets → Kitchen`.
2. Click the **search/filter field** in the Explorer (magnifying glass) and type `ParticleEmitter`. This filters the selected tree (`Kitchen`) to its descendants.
3. Select all results (Ctrl+A) → press Delete. **This deletes only ParticleEmitters — station models, prompts, and parts are untouched.**
4. Optional: search `Sparks` and delete the now-empty `Sparks` parts too (safe; verified code path no-ops). Leave them if you prefer.
5. Verify: select `Kitchen`, search `ParticleEmitter` again → 0 results.

Do NOT touch the 34 emitters under `workspace.Map` in this step (fountains/ambience may have visual intent — review them in Step 2's pass, not now).

## Step 2 — SurfaceLights in `workspace.Map`: 164 → ≤10 (~45 min)

**Impact: likely the single biggest FPS win — SurfaceLights are per-pixel lights and are brutal on low-end GPUs.**

How to find them:
1. Explorer → select `workspace.Map`.
2. Search `SurfaceLight` (then separately `PointLight`, `SpotLight` — you have 7 PointLights; keep the good ones). Filter shows the Map's descendants only.
3. Work **area by area**, not one giant select-all, so you can judge visual intent.

Keep vs delete — decision rule:
- **KEEP (≤10 total dynamic lights for the whole cafe):** lights that carry actual gameplay readability — 2–3 over the kitchen work island, 2–3 over the main counter/register area, 1 over the pick-up counter. These are usually under models whose names mention Counter/Register/Kitchen/Cooking.
- **DELETE (the vast majority):** decorative strips, neon trim, menu-board glows, chair/table accent lights. The part they light usually has a bright/neon Material or Color that already reads as "lit" — the SurfaceLight is redundant.
- **CONVERT (when the glow really matters):** if an area goes noticeably dark after deleting, add ONE `PointLight` (Range 8–14, Brightness 1–2, Shadows = false) instead of the old SurfaceLight. PointLights are far cheaper.

Safety:
- If you can't tell what a light does: toggle it off (`Enabled = false`) in the Properties panel, look at the viewport, then decide. Disabled is reversible; deleted is not (beyond undo).
- If the cafe feels too dark overall after the pass, raise `Lighting.Brightness` by 0.5–1 in the Lighting service Properties (ambient, cheap — presentation only, no code).
- Do not change `Lighting.Technology` unless you also test on the target device class (Future is the authored look; Compatibility is faster but flattens everything).

## Step 3 — Cell-based streaming for `workspace.Map` (~60–90 min)

**Impact: drops the ~11,000 Map instances the GPU/physics hold while not in view. Streaming is already ON; this makes it actually work.**

### 3a. Workspace radii (2 min)
1. Select `Workspace` in Explorer.
2. In Properties, set:
   - `StreamingEnabled` = true (already on — leave on).
   - `StreamingMinRadius` = **48** (studs around the camera that are always streamed; default 64).
   - `StreamingTargetRadius` = **256** (streaming fetch radius; default 1024 — far too big for a cafe).
   - Set these **via the Properties panel**, not a Command Bar script (a previous attempt via script errored: "StreamingMinRadius is not a valid member of Workspace").
3. Tune later: if content pops in visibly while walking, raise MinRadius to 64; if memory/FPS improve and you want more, drop to 32.

### 3b. Integrity modes (20–40 min)
Per-instance streaming behavior:
- `Enum.StreamingIntegrityMode`: `PausedNever` (always simulate), `PausedOutsideRadius` (pause physics/animations when far — the big win for the 168 Seats and decor), `PausedOnLowMemory`, `Default`.
- `Enum.StreamingMode` (BaseParts) / `Enum.ModelStreamingMode` (Models): `Persistent` (never streams out), `NonPersistent` (can stream out), `Default`, `Atomic` (models only — streams as one unit).

Apply by selecting groups in the Explorer and setting Properties:
1. **Gameplay anchors → `Persistent` + `PausedNever`:** `workspace.Assets` (Kitchen, NPC path/queue/counter parts, TrashCans), `workspace["Ordering System"]` (CustomerAreas, Pick Up, registers), `workspace.OldScriptables` (chest nodes, leaderboards — if used), `workspace.AreaLimits*`, and the runtime `workspace.Customers` folder if it exists. Code resolves these by path and expects their prompts/parts to exist — they must never stream out.
2. **Map decor → `NonPersistent` + `PausedOutsideRadius`:** everything under `workspace.Map` that is not a gameplay anchor. Select the whole Map and set it first, then override the handful of anchor pieces (if any register/counter parts live under Map) back to `Persistent`/`PausedNever`.
3. **Big furniture models → `Atomic`:** for the Map's largest children (the 290/218/195/167-descendant models found in the audit), set `ModelStreamingMode = Atomic` so a chair set or shelf streams in/out as one unit instead of piece-by-piece.

### 3c. Cells (30 min)
Streaming culls per-instance, but it works far better when distant things are grouped. Build 4–6 cells under `workspace.Map`:
- `Map.KitchenIsland` (nearest gameplay), `Map.Registers`, `Map.Seating`, `Map.FarDecor`, `Map.Props`.
- Move existing Map children into these `Model`s (keep names/pivots; code never references `Map` children — verified, safe to re-parent).
- Set each cell's `ModelStreamingMode = Atomic` + `StreamingIntegrityMode = PausedOutsideRadius`.
- Do NOT move or rename `workspace.Assets`, `workspace["Ordering System"]`, `workspace.OldScriptables`, `workspace.Customers`, `workspace.AreaLimits*` — code paths depend on them.

## Step 4 — Verify after each step (~15 min + per-step measurement)

Measure **at the same camera position** every time so numbers are comparable: stand at the kitchen island looking toward the counter, and a second spot at the seating area looking across the cafe.

1. **In Studio Play:** press **F9** (Developer Console) and check the **Performance** section — frame rate, frame time, and memory (client view).
2. **In the Roblox client:** press **Shift+F5** to toggle the on-screen performance stats overlay (FPS, physics, memory, network). This is the number that matters for the 32 FPS field report.
3. **Record after every step:** FPS, client memory, and whether any pop-in/darkness is visible.

Expected relative gains (rough):
- Step 1 (emitters): small-to-moderate FPS gain, memory down, zero visual change.
- Step 2 (lights): **largest FPS gain** on low-end GPUs; some areas may need the PointLight conversion fallback.
- Step 3 (streaming): large memory drop (server + client) and a second FPS gain when looking away from dense decor.

Stop and report if any step makes FPS *worse* or breaks a station prompt — do not proceed to the next step.
