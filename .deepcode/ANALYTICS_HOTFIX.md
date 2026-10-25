# Analytics Hotfix — Launch Day FTUE & Performance

Generated 2026-10-24 by the Primary Reasoning Agent.
Basis: `.deepcode/FTUE_TRACE.md` (code trace), live funnel data (8 h post-launch), and a live Studio inspection of place `128511401637461` (MCP: class counts, console, tree).

Status: **DIAGNOSIS + PLAN ONLY.** No code or config has been changed yet. Items marked PENDING JACK need explicit approval before implementation.

---

## 1. Funnel read (per-step conversion, not cumulative)

| Step | Event | Conversion | Abs. users | Interpretation |
| --- | --- | --- | --- | --- |
| 1 → 2 | Joined → ClockedIn | 100% | 398 → 398 | Clock-in is automatic and working |
| 2 → 3 | ClockedIn → FirstItemTaken | 55.78% | 398 → 222 | 176 players never grabbed a single tool |
| 3 → 4 | FirstItemTaken → FirstServe | 34.68% | 222 → 77 | 145 players took a tool but never served |
| 4 → 5 | FirstServe → OnboardingCompleted | 28.57% | 77 → 22 | 55 players served at least once but didn't complete |

Two cliffs dominate, plus a hidden third (step 2 → 3).

## 2. Cliff diagnoses

### Cliff A — Step 4 `FirstServe` (65% churn after taking an item)

**Why:** the first tutorial order is a **4-station boba with exact attribute matching**:

`FIRST_SESSION_ORDERS[1]` = "Classic Milk Tea Boba, Medium"
→ Clear Cup dispenser (size dialog) → Milk → **Classic Milk Tea Syrup (1 correct dispenser out of ~14 cloned syrup dispensers)** → **Normal Tapioca (1 correct jar out of ~13)** → walk to the pick-up counter → Serve.

Every step is server-gated by tool-name patterns, and the serve grades by attributes (`OrderSpec.Match`). A wrong size, wrong syrup, wrong tapioca, or a skipped station produces a **Wrong drink** at serve: the tool is not consumed, the player must find the Sink's hidden "Wash Cup" dialog or a trash can, then redo. That is a brutal first task for a brand-new player on a 32 FPS client.

Contributing factors found in code:
- Recovery is not discoverable. The Sink washout exists but is a `SelectFrom` dialog behind a 1 s hold; `KitchenController` only points to the trash can for a *completed* wrong drink, not for a partial mistake (wrong size / wrong syrup mid-chain).
- The mistake toast is shown only at the failed serve ("Wrong drink: …"), after the player already walked to the NPC.
- The auto-granted NPC spawns at the pick-up counter while the player is at the kitchen island — a navigation step with only a beam for guidance.

**Verdict:** recipe complexity + unforgiving grading + weak error recovery, amplified by poor FPS. Not "invalid ingredients" (the chain is consistent: `Custom Boba` → `ServeItem = "Boba"` matches the Tapioca station's `Item = "Boba"`).

### Cliff B — Step 5 `OnboardingCompleted` (71% churn after serving)

**Exact condition from the trace:** `OnboardingCompleted` fires in `_onServeTriggered` only when

```
(_readServedCount(player) BEFORE the serve) + 1 >= CustomerConfig.FIRST_SESSION_COUNT  -- FIRST_SESSION_COUNT = 3
```

i.e. the player must **serve 3 lifetime drinks**. The 71% churn = players who served exactly 1 (or 2) drinks and stopped.

Why they stop after serve #1:
- The next tutorial order auto-grants 1 s later with **no callout**; the ticket silently changes. The Daily Rewards dialog auto-opens over the screen at the same moment (first serve), burying the new ticket.
- Order #2 is a different station (Food Display) and order #3 is a different recipe — more discovery right after the first success.
- The whole loop is session-bound: if they leave before serving 3, progress on `CustomersServed` persists but the scripted auto-grant chain restarts fresh on rejoin.

**Verdict:** the missing condition is literally "2 more serves". Onboarding is over-gated relative to the moment of first success, and the loop is under-communicated.

### Cliff C (hidden, feeds the others) — Step 3 `FirstItemTaken` (44% churn before any tool)

`_readServedCount(player)` (used by both the auto-grant gate and the onboarding-complete check) has a **5-second timeout** and falls back to `FIRST_SESSION_COUNT` (3) when the profile read fails:

```lua
local SERVED_COUNT_TIMEOUT_SECONDS = 5
-- on failure: return CustomerConfig.FIRST_SESSION_COUNT  (i.e. "looks graduated")
```

On a cold DataStore / slow ProfileStore at launch, a slow read makes a brand-new player look **graduated**: `_checkAutoGrantFirstOrder` sees `served >= 3` and skips the tutorial entirely — **no auto-ticket, no spawned NPC**. The player is dumped into the pool flow ("Wait at the register…", manual Take Order + tablet with no prefill), which explains a large share of players who clock in but never take an item. The same fallback also inflates `OnboardingCompleted` for the unlucky few (they "complete" on serve #1), masking the real step-5 problem.

### Performance — 32 FPS / 675 MB server memory

Live Studio inspection (MCP, Edit mode) of place `128511401637461`:

| Metric | Value |
| --- | --- |
| Workspace instances | **15,275** |
| BaseParts (Part + MeshPart + Wedge + Union) | **~9,200** (4,556 Part + 4,495 MeshPart + 16 Wedge + 151 Union) |
| Map folder alone | **11,287 descendants** |
| Anchored / unanchored | 9,351 / 116 (physics is fine) |
| CanCollide parts | 7,994 |
| Lights | **186** (179 SurfaceLight + 7 PointLight) |
| ParticleEmitters | **232** (196 inside `Assets.Kitchen` alone) |
| Seats | 240 |
| StreamingEnabled | true (already on) |

Client-side (code) contributors on top of the heavy map:
- `KitchenController` runs a guidance pass every **0.2 s** (`GUIDANCE_INTERVAL_SECONDS = 0.2`) plus a second serve-prompt pass every 0.2 s; each pass iterates `workspace.Customers` and does recursive `FindFirstChild("CustomerPrompt", true)` per NPC per tick.
- Guidance draws `Highlight` with `DepthMode = AlwaysOnTop` and a 20-segment `Beam` — expensive on low-end GPUs.
- Console also shows repeated asset failures (`rbxassetid://203785492` "Asset type does not match requested type" ×many, `124987465` not found, `7764190296` not approved) — a streaming-in asset retried over and over, a hitch source.
- Server memory is dominated by the authored map (15 k instances, 8 k collidable) plus up to 16 full NPC rigs; the server holds all streamed content.

The dominant FPS fix is a **Studio perf pass** (lights/emitters/parts + streaming radii) which needs a Rigger lease — listed as follow-up, not in the top 3.

## 3. Audit: is the Sink Washout helping or scope creep?

**Verdict: KEEP IT. It is not scope creep and removing it would make the cliff worse.**

- It is a contained, already-reviewed recovery path (`Recipes.Items["Sink"]` "Wash Cup" branch + `SetToolAttributes` `ClearAttributes`). It has no loops, no signals, no cross-service surface.
- The funnel cliff is **upstream** of it: players fail because the first order has 4 failure points, not because they can't reset. The washout is the only instant reset for a mid-chain mistake (the alternative is the corner trash can + dialog + walk back).
- The honest gap is that the washout is **undiscoverable** (a dialog option on a sink the player may never look at). Before any removal discussion, instrument it: add a `SinkWash` custom event in the Wash Cup branch and compare wash usage vs. trash usage. Removal is only justified if it measures near-zero after the tutorial reorder ships.

## 4. Hotfix plan — top 3 lowest-risk changes

### Hotfix 1 (config-only) — Reorder the tutorial so the first serve is trivial
**File:** `src/shared/Configuration/CustomerConfig.luau` → `FIRST_SESSION_ORDERS`
**Change:**
1. `Fudge Brownie` (Grab item — 1 station, 1 dialog, `OrderSpec.Match` always `Perfect` for Grab)
2. `Regular Coffee, Small, no ice/sugar` (Cup → Coffee Machine — 2 stations)
3. `Classic Milk Tea Boba, Medium` (the full teaching chain)

**Why:** a Grab item cannot be made wrong — it eliminates every failure point between FirstItemTaken and FirstServe for the first serve, gets a dopamine hit in under a minute, and moves the boba to slot 3 where a served player has guidance momentum.
**Risk:** none technically (pure data); **PENDING JACK** because this is onboarding content.
**Goal:** FirstServe 34.68% → **≥60%**; knock-on lift to step 5 because serves #1–#2 become fast.

### Hotfix 2 (small server edits) — Communicate the onboarding loop + fix the data-fallback skip
**Files:** `src/server/Modules/CustomerService/init.luau` (3 small edits)
1. `SERVED_COUNT_TIMEOUT_SECONDS`: 5 → 15, and change the `_readServedCount` failure fallback from `FIRST_SESSION_COUNT` (3, "looks graduated") to **0** (treat as new; a worst-case extra scripted order is harmless, and a new player is never skipped). This attacks Cliff C.
2. In `_autoGrantFirstOrder`, after `_issueTicket`, add a `DialogService:Notify` callout: "New customer at the pick-up counter — check your ticket!" (guarded `pcall`, deferred, style tokens only).
3. In `_onServeTriggered`, where the next grant is scheduled (`servedNow < limit`), add a progress toast: "Order {servedNow}/3 done — next customer on the way!" and suppress it if a dialog is open (reuse existing `Notify` path).
**Risk:** low — all changes are inside existing `pcall`/deferred paths; no serve-path yields added; no economy touched.
**Goal:** FirstItemTaken 55.78% → **≥70%** (kills the silent tutorial skip); OnboardingCompleted 28.57% → **≥50%** (players know the loop continues).

### Hotfix 3 (small client edits) — Throttle per-frame guidance and cache prompts
**File:** `src/client/Modules/KitchenController.luau`
1. `GUIDANCE_INTERVAL_SECONDS` 0.2 → 0.4, and the serve-prompt pass threshold 0.2 → 0.4 (halve the per-frame work).
2. Cache the `CustomerPrompt` reference per NPC model instead of `FindFirstChild("CustomerPrompt", true)` every pass (store on a table keyed by model, invalidate on `DescendantRemoving`).
3. Cap the beam cost: `Beam.Segments` 20 → 12 and only enable the `AlwaysOnTop` highlight when a hint is actually active (it already toggles; confirm no idle-highlight).
**Risk:** low — client presentation only; server authority untouched; guidance still updates 2.5×/s which is visually equivalent for hints.
**Goal:** client FPS 32 → **~40+** on the same device class (partial relief; the real fix is the Studio perf pass below).

### Follow-ups (not now, need Rigger lease or Jack)
- **Studio perf pass:** reduce/disable the 179 SurfaceLights and 196 kitchen emitters, set streaming radii on the 11 k-descendant `Map`, and fix the failing asset IDs seen in console (`203785492`, `124987465`, `7764190296`). This is the real FPS fix.
- **Measure the washout:** add `SinkWash` custom event before any keep/remove decision.
- Re-run the gates: Selene, StyLua `--check`, `rojo build`, TestEZ with `TESTS_ENABLED = true` then reverted (note: the Studio console currently shows a failing local test suite — 27 failures — do not ship test-enabled).

## 5. Metrics goals (48 h after hotfix)

| Metric | Now | Target |
| --- | --- | --- |
| FirstItemTaken (step 3) | 55.78% | ≥70% |
| FirstServe (step 4) | 34.68% | ≥60% |
| OnboardingCompleted (step 5) | 28.57% | ≥50% |
| Client FPS | 32 | 40+ (then Studio perf pass → 55+) |
| Day-1 retention | 2.03% | 5%+ (lagging indicator; driven by the above) |

## 6. Explicitly out of scope (per AGENTS.md boundaries)

- No economy/prices/probability changes, no join gates, no failure screens, no profile migrations.
- The tutorial reorder and any pacing/NPC-cap tuning are **PENDING JACK**.
- This document changes no code; it is the plan the next session executes after approvals.
