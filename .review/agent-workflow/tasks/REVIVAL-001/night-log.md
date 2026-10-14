# REVIVAL-001: overnight run log (DEC-009)

Prime updates this after every lane. The newest entry is at the bottom. If context is lost, resume from here, then `board.json`.

## Plan
- Wave 1: M1.3c tool attributes · M1.3d OrderService auto-match deposit · S2 Rigger Q7–Q9 candidate packets (read-only, Studio)
- Wave 2: M1.5a Steps/StepState · M1.5c+d highlight, beam and toasts · M1.4d+b NPC lifecycle + config (no pay values) + pacing/patience rules
- Wave 3: M1.5b recipe card · measurement events (plan §4.8)
- Wave 4: batched Gauge (TestEZ + NPC smoke) → Sentry (opus) on the night's diff → fixes → commit → morning brief + kickoff

## Log
- Commits `2c6e248` (M0) and `2bdbba1` (M1.3a/b). Gate PASS on all changed files.
- Wave 1 launched: M1.3c, M1.3d, S2 (all sonnet).
- M1.3d DONE (gate PASS, TestEZ pending): FindServeTools/GetPendingCount/HasActiveOrder, synchronous auto-match deposit, _promptToolSelection removed. Real deposits fail until M1.3c attributes land. Jack Q: should an occupied pick-up area be guarded? (pre-existing gap)
- M1.4core launched (sonnet): CustomerConfig (no pay), Rules (pacing/patience/order pick) + spec, CustomerService lifecycle behind workspace.Assets.NPC contract, bubble; no assignment/serve/payout.
- M1.3c DONE (gate PASS, lune 34/34 + BobaRecipe 5/5). Commit `041888d` (M1.3c/d + M1.2 design + M0.11/S1 evidence). Notes for Jack: 8 Menu syrups have no station; smoothies, Latte, Oolong, Salted Hot Chocolate and 13 pastries have no station; the Hot Chocolate tool name has a leading space; Lid=true is written even when the tool has no lid part.
- M1.5a launched (sonnet): OrderSpec Steps/StepState, REQUIRE_BLENDER=false constant (Q3).
- M1.5a DONE (gate PASS, lune 116/116): OrderSpec.Steps/StepState. Questions logged in its evidence: Steps={} for tea, water, smoothie and bare Cup (Q22); the grab station is inferred from the " Ice Cream" name suffix.
- M1.5cd launched (sonnet): station highlight, beam, setting rename, Choice pulse, failure toasts, ClockedOut toast.
