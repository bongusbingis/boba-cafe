# M3-E24-REVIEW: Review first-shift capsule grant design
Model: Terra   Studio: no   Depends on: DEC-024   Size: S

## Goal
Recommend a minimal, data-safe implementation for the approved one-time starter capsule reward. This is a read-only technical review; do not implement or decide product behavior.

## Source state
- Git HEAD: `cbf5271`.
- Relevant working-tree files were already modified before this review. SHA-256 at review dispatch:
  - `src/server/Modules/ShiftService.luau`: `42356AA72F9F1EB3E7B2ED6945121608AFFC23385B4B444A57D0CCE33F31471B`
  - `src/shared/Configuration/ProfileTemplate.luau`: `7F01385E5FF0A388AF0717AF5B47E4A1CA5DAADB0EB1A565F39CE01D889F702B`
  - `src/server/Modules/DataService/PlayerSetup.luau`: `994D9C7084196CE11B5E2A9E9F2605C7C5FB87A16687F3D6B563124DB344DFBB`
  - `src/shared/Inventory/InventoryServer.luau`: `CD4E9EA6F24A7EE0EEF5BB2CA3175668E465B935270649AC94E833CE4232CC35`
  - `src/server/Modules/CapsuleService.luau`: `38B920EEE2F9C6583CEEA8C40A53E7740EB1897E537F4DFA4F8FF7D03021DF43`

## Read (only these)
- `.review/agent-workflow/decisions.md:5-19` - DEC-024, E24's approved behavior.
- `src/server/Modules/ShiftService.luau:119-212` - first-shift count and shift completion order.
- `src/shared/Configuration/ProfileTemplate.luau:80-120` - durable inventory and shift fields.
- `src/server/Modules/DataService/PlayerSetup.luau:78-96` - existing free-item claim marker pattern.
- `src/shared/Inventory/InventoryServer.luau:90-125,233-310` - inventory writes and `Insert` behavior.
- `src/server/Modules/CapsuleService.luau:90-115,160-240` - inventory API reward grant patterns.

## Write scope
- Read-only review. No production code changes.
- `.review/agent-workflow/tasks/REVIVAL-001/M3-E24-REVIEW/evidence.md` - review result only.

## Investigation
1. Verify the first-shift signal/order and existing durable `FreeItemsRedeemed` marker behavior.
2. Verify whether inventory `Insert` can fail and whether its write is synchronous/idempotent.
3. Challenge this candidate only; do not treat it as settled: detect `state.Completed == 0`, perform a best-effort asynchronous inventory API insert of one `Regular Pet Capsule`, and use a durable marker to prevent duplicate grants.
4. Recommend marker ordering and failure behavior that minimize duplicate/lost rewards while never blocking shift completion or play.

## Exact question
Can the candidate safely satisfy DEC-024 E24 with the current APIs? If not, what smallest alternative meets the approved requirements? Identify any material tradeoff requiring Jack's decision. Distinguish facts, inference, recommendation, and unresolved issues.

## Done when
- Evidence cites exact symbols and paths, states which failure modes were checked, and gives a narrow implementation recommendation.
- The recommendation does not expand the reward or alter its approval.

## Checks to run
- Read-only source inspection only. No tests, Studio, or app edits.

## STOP-AND-ASK
- Stop if meeting the one-time/no-block requirements needs an unapproved data schema or reward rule.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/M3-E24-REVIEW/evidence.md`
