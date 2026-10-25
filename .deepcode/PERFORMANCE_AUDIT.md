# Performance Audit — 32 FPS & 675 MB Memory

Generated 2026-10-24 by the Primary Reasoning Agent (read-only; proposes, does not implement).
Evidence: live Studio inspection of place `128511401637461` via MCP (`execute_luau`, `search_game_tree`, `get_console_output`) + static code search.

## 1. What the numbers say

| Scope | Finding |
| --- | --- |
| Workspace total | **15,275 instances** |
| `workspace.Map` | **11,287 descendants** — 7,544 parts (3,344 MeshParts), 7,541 anchored / **3 unanchored**, **164 SurfaceLights**, 7 PointLights, **168 Seats**, 98 Unions, 34 ParticleEmitters |
| `workspace.Assets.Kitchen` | **1,385 descendants** — 971 parts (752 MeshParts), **196 ParticleEmitters**, 7 Unions, 0 lights |
| `Lighting` service | 0 lights in the service itself — **all 171 dynamic lights live inside the Map models** |
| Streaming | `StreamingEnabled = true` (good) |
| Console | Repeated `ContentId` failures (`rbxassetid://203785492` type mismatch ×many, `124987465` not found, `7764190296` not approved) — asset lookups retried during stream-in |
| Server memory | 675 MB — dominated by the authored map (15 k instances, ~8 k collidable) + NPC rigs; no obvious per-player leak found (see §4) |

**Root cause of 32 FPS:** a geometry- and light-heavy map with **171 dynamic lights (164 SurfaceLight)**, **230 particle emitters (196 in the kitchen)**, ~7.5 k collidable parts, and no per-part streaming tuning — streamed on low-end ad-acquired devices. Code loops are a secondary cost (§3).

## 2. Prioritized Rigger checklist (Studio map work — highest impact)

### P0 — do these first (biggest FPS win, zero gameplay change)
1. **Kill or convert the 164 SurfaceLights.** SurfaceLights are per-pixel lights: expensive on mobile GPUs. Either delete them, or replace emissive parts with `MaterialVariant`/baked look + a handful (≤8) of PointLights. Target: 171 dynamic lights → ≤10.
2. **Neutralize the kitchen's 196 ParticleEmitters.** The `Sparks` parts under `Assets.Kitchen` carry 3 emitters per station. Set `Enabled = false` on idle emitters (code can do this too, see §3.2) or delete two of the three per station. Target: 230 → ≤40 (only gameplay-triggered ones).
3. **Fix the failing asset IDs.** `203785492` (wrong asset type — likely a texture used as a mesh or vice versa), `124987465` (missing), `7764190296` (not approved). Each stream-in retries and hitches. Replace or remove.
4. **Set per-part `StreamingMode`/`StreamingIntegrityMode` and a sane `StreamingMinRadius`** for the 11 k-descendant Map so distant decor unloads (the console shows a script already attempted `StreamingMinRadius` and errored — it was set on the wrong object/type).

### P1 — high impact
5. **Split `Workspace.Map` into streamable cells** (kitchen island, registers, seating, far decor). The Map is one flat folder; streaming can't cull it effectively.
6. **Reduce the 168 Seats + 98 Unions.** Seats are physics parts; many are decorative chairs. Convert decorative chairs to `CanCollide = false` MeshParts or models.
7. **Audit the dense furniture models** (top Map children: 290, 218, 195, 167-descendant models). Merge static parts into fewer MeshParts (or leave as-is only if streaming cells are added).
8. **Check texture memory:** `Texture` instances (339) + mesh textures; ensure no 2048² textures on small props.

### P2
9. NPC look budget: runtime NPCs use full HumanoidDescription rigs; cap visible NPCs at distance (LOD/name-only beyond 60 studs).

## 3. Client code loops (findings + proposals)

### What runs every frame (from code search)

| Loop | Frequency | Cost | Verdict |
| --- | --- | --- | --- |
| `KitchenController` guidance pass (line 825) | Heartbeat, gated 0.2 s | iterates kitchen index/`workspace.Customers`, recomputes `KitchenGuidance`, moves Highlight/Beam | OK-ish; throttle to 0.4 s + cache NPC prompt refs (already proposed in ANALYTICS_HOTFIX) |
| `KitchenController` serve-prompt pass (line 1389) | Heartbeat, gated 0.2 s | per NPC `FindFirstChild("CustomerPrompt", true)` recursive | throttle to 0.4 s; cache prompt per model |
| `PetFollowerRenderer:_step` (line 215) | **Heartbeat, ungated** | steps every follower every frame for every equipped pet | gate to 30 Hz; early-return when no followers; skip off-screen followers |
| `useClock` (`shared/UI/Utility/useClock.luau`) | **Heartbeat, ungated** | re-renders the clock React component **every frame** (always mounted in TopBar) | change to 1 Hz tick (clock shows minutes) — trivial win |
| `OrderTicket` patience bar (line 488) | Heartbeat while a ticket exists | setState quantized to 0.5% (React bails on same value) | fine; keep |
| `Ordering/RightPanel` (line 112) | Heartbeat while page open | fraction update | fine (page-scoped) |
| `EventFxController` confetti follow (line 201) | Heartbeat while event FX active | CFrame follow | fine (event-scoped) |
| `FlightController` (line 66) / `FlyingMopController` (line 101) | RenderStepped/Heartbeat while flying/riding | physics-free presentation | fine (state-scoped) |

**Proposed client changes (low risk, presentation only):**
- `useClock` → 1 Hz (one-line change; removes a per-frame React render for every player).
- `PetFollowerRenderer` → 30 Hz step + skip when `_followers` empty.
- `KitchenController` → 0.4 s intervals + cached prompts (already in hotfix plan).

**Metrics goal:** these three + the P0 map/lighting pass should move 32 FPS → 45–55 on the same device class.

## 4. Server memory (675 MB) — leak check

Static audit result: **no smoking-gun per-player leak.**

- Every Knit service in `src/server/Modules` (35 files) implements `PlayerRemoving`. The only modules with per-player tables and no `PlayerRemoving` are `KitchenService/InteractionRunner.luau` (`_debounces[player]` — self-clears 0.5 s after the interaction, so a departed player's key lives ≤0.5 s) and legacy `RankingClient.luau` (URL rate-limit + `pendingUsers`; legacy HTTP, tiny).
- `CustomerService` clears tickets, assignees, combos, idle clocks, ordering state, inventory watchers and character connections in `PlayerRemoving` (verified in trace).
- `OrderService` clears `_orderDebounces` and `_freeSince`; orders are removed on customer leave and re-dispatched on barista leave (verified).
- `PerkService` clears `_tipRemainder` and `_storageMultiplier`; `AnalyticsEvents` clears `stepsSeen`/`onboardingStepsSeen`/`sessionIds`; `ShiftService`, `CapsuleService`, `SpillService`, `DialogService` all clean up.
- `Janitor` is used correctly in `SpillService/Spill.luau` (per-spill). Other services use manual connections, but all are disconnected in `PlayerRemoving`.

**So the 675 MB is mostly the authored map + NPC rigs + streaming cache, not a leak.** The P0/P1 map reductions above are the same fixes that lower server memory. Two extra server-side savings:
- `CustomerConfig.SERVER_CAP` 16 → 10 (fewer simultaneous NPC rigs; TUNING, PENDING JACK).
- Ensure dead NPC models are destroyed (verified: `Npc.Leave` → `Destroy`; but check `workspace.Customers` for orphaned models after a long session — one `execute_luau` count in play mode is enough).

## 5. Bottom line for the Rigger

Disable 164 SurfaceLights → delete 2/3 of kitchen Spark emitters → fix 3 broken asset IDs → cell+stream the Map. That is the 32 FPS fix. Code-side: `useClock` 1 Hz, pet follower 30 Hz, guidance 0.4 s. No code change proposed here alters gameplay or economy.
