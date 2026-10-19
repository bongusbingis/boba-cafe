# REVIVAL-001 / M3-BULK-NAMETAG / PET-COMPLETION

status: ready
priority: P0
role: mason
objective: Serialize pending capsule hatch completion and preserve pending state unless pet insertion succeeds.
reason: Terra identified a race between TryCompleteReadyHatch and the periodic completion loop, plus pending reward loss when insertion fails. This is an independent technical fix required before runtime validation.
read_scope:
  - docs/AI_AGENT_WORKFLOW.md
  - .review/agent-workflow/tasks/REVIVAL-001/M3-BULK-NAMETAG/packet.md
  - .review/agent-workflow/tasks/REVIVAL-001/M3-BULK-NAMETAG/terra-review.md
  - src/server/Modules/CapsuleService.luau: completePendingHatches, TryCompleteReadyHatch, periodic loop, per-player transaction helper
  - src/server/Scripts/ProcessReceipt.server.luau: Skip Hatch pending-record update
write_scope:
  - src/server/Modules/CapsuleService.luau
  - src/server/Scripts/ProcessReceipt.server.luau (preserve existing HatchId and MinTier on Skip Hatch)
  - .review/agent-workflow/tasks/REVIVAL-001/M3-BULK-NAMETAG/PET-COMPLETION/evidence.md
invariants:
  - Skip Hatch preserves the pending hatch HatchId and MinTier when updating TimeAccumulated.
  - Preserve all existing dirty user changes; do not reset, stash, or reformat unrelated files.
  - Serialize every completion entry point through the established per-player transaction mechanism.
  - Clear HatchingPet only after petsInventory:Insert confirms success.
  - On failed/throwing insert, retain pending state for retry and do not duplicate-grant.
  - Do not alter prices, odds, policy rules, rewards, UI, or refund/accounting behavior.
  - No Studio, Play, or TestEZ runs.
acceptance:
  - Receipt-driven Skip Hatch timer updates retain the same durable hatch identity and tier.
  - Client-triggered and periodic completion cannot concurrently grant the same pending pet.
  - Failed insertion does not erase the pending pet; successful insertion clears the matching pending record exactly once.
  - StyLua and scripts/gate.sh pass for CapsuleService.luau with no new findings.
checks:
  - Use repository WSL gate shim per workflow.
  - Inspect final diff to confirm scope.
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/M3-BULK-NAMETAG/PET-COMPLETION
forbidden:
  - Any refund ledger/accounting changes; these await Jack's policy decision.
  - Any Studio/runtime test or unrelated source edits.
return_format: standard-result-v1

