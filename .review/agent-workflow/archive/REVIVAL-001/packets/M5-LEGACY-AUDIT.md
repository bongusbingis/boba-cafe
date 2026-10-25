# M5-LEGACY-AUDIT: Audit of Legacy Workspace Scripts
Model: sonnet / scout   Studio: yes (read-only)   Depends on: none   Size: S

## Goal
Audit all remaining legacy scripts in `Workspace.OldScriptables` and `Workspace.Map` (revival-plan §7.1, §8 M5):
- Read script contents via Studio MCP `script_read` without modifying or deleting authored instances.
- Check for obsolete gamepass/product prompts, broken global calls, hardcoded paths, or infinite loops.
- Classify each script: `SAFE_TO_KEEP`, `NEEDS_UPDATE`, or `RECOMMEND_DISABLE`.
- Document findings and recommendations in `.review/agent-workflow/tasks/REVIVAL-001/LEGACY-AUDIT/audit.md`.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `Workspace.OldScriptables.ElevatorFolder.ElevatorScript`
- `Workspace.OldScriptables.ZiplineFolder.ZiplineHandler`
- `Workspace.OldScriptables.CelebrityFolder.IslandTeleporter.Script`
- `Workspace.Map.FountainsFolder.Script`
- `Workspace.Map.SlideSitPart.Script`
- `Workspace.Map.Model.Script`
- `Workspace.Map.Part.Script`

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/LEGACY-AUDIT/audit.md` (new)

## Steps
1. Use Studio MCP `script_read` to inspect each legacy script in `Workspace.OldScriptables` and `Workspace.Map`.
2. Analyze behavior:
   - Does it prompt old passes/products?
   - Does it index deprecated services or hardcoded player ranks?
   - Does it produce output errors or break when players interact with it?
3. Generate a comprehensive audit matrix:
   - Script Path
   - Purpose & Triggers
   - Gamepass / Product IDs referenced (if any)
   - Risk Assessment
   - Recommendation (Keep / Update / Disable)
4. Write audit document to `.review/agent-workflow/tasks/REVIVAL-001/LEGACY-AUDIT/audit.md`.

## Done when
- All legacy workspace scripts are read and audited.
- `LEGACY-AUDIT/audit.md` contains the completed assessment matrix.

## STOP-AND-ASK
- none

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/LEGACY-AUDIT/audit.md`
