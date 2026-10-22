#!/usr/bin/env bash
# lane.sh — lightweight subagent bridge: dispatch one headless DeepSeek agent
# (deepcode -x) inside a fresh git worktree and capture its evidence.
#
# Usage:
#   scripts/lane.sh <TASK_ID> [BASE_REF]
#
# Contract:
#   * Task packet : .review/agent-workflow/tasks/<TASK_ID>/packet.md (or brief.md)
#   * Worktree    : .worktrees/<TASK_ID> (gitignored), branched from BASE_REF (default HEAD)
#   * Dispatch    : deepcode -x -p "<lane header>" with the packet on stdin, cwd = worktree
#   * Evidence    : <TASK_ID>/run.log, status.txt, diff.txt, gate.txt
#   * Integration : never here. Prime reviews the evidence and applies the diff.
#
# Exit: 0 dispatched and captured. Subagent failures are recorded in run.log,
#       not in the exit code; Prime reads the evidence.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_ID="${1:-}"
BASE_REF="${2:-HEAD}"

if [ -z "$TASK_ID" ]; then
	echo "usage: scripts/lane.sh <TASK_ID> [BASE_REF]" >&2
	exit 2
fi
command -v deepcode >/dev/null 2>&1 || { echo "lane: missing deepcode on PATH" >&2; exit 2; }

TASK_DIR="$REPO/.review/agent-workflow/tasks/$TASK_ID"
WT="$REPO/.worktrees/$TASK_ID"
[ -d "$TASK_DIR" ] || { echo "lane: no task dir: $TASK_DIR" >&2; exit 2; }

PACKET=""
for f in packet.md brief.md; do
	if [ -f "$TASK_DIR/$f" ]; then PACKET="$TASK_DIR/$f"; break; fi
done
[ -n "$PACKET" ] || { echo "lane: no packet.md or brief.md in $TASK_DIR" >&2; exit 2; }

# --- fresh worktree ---------------------------------------------------------
if [ -f "$WT/.git" ] || [ -d "$WT/.git" ]; then
	(cd "$REPO" && git worktree remove --force "$WT" 2>/dev/null) || rm -rf "$WT"
	git -C "$REPO" worktree prune >/dev/null 2>&1 || true
fi
mkdir -p "$REPO/.worktrees"
git -C "$REPO" worktree add "$WT" "$BASE_REF" >/dev/null

# Gitignored build inputs are absent from a fresh worktree; copy them so the
# lane can read package sources and run the full gate (7 MB total, cheap).
cp "$REPO/default.project.json" "$WT/default.project.json" 2>/dev/null || true
cp -R "$REPO/Packages" "$WT/Packages" 2>/dev/null || true
cp -R "$REPO/ServerPackages" "$WT/ServerPackages" 2>/dev/null || true

# --- lane header (the standing contract; packet follows on stdin) -----------
LANE_HEADER="$(cat <<'EOF'
You are a bounded specialist subagent for the boba-cafe Roblox repository, working inside a git worktree created for you. A task packet follows on stdin; it is your assignment. Your role and every rule below apply for the whole turn.

Rules (non-negotiable):
- Stay inside the read_scope and write_scope in the packet. Do not touch anything else.
- Never run git add/commit/push/rebase/reset. Never edit .git, .deepcode/, .gitignore, or any file with a secret or key.
- Never publish to Roblox, open Studio, or use a Roblox MCP unless the packet says "Rigger" and authorizes it.
- Follow AGENTS.md, docs/CONVENTIONS.md, docs/ARCHITECTURE.md, docs/SYSTEMS.md and docs/STYLE.md in the worktree.
- Do not invent assets, UI tokens, prices, probabilities or rewards. If an expected asset or product decision is missing, say so instead of building a substitute.
- No failure screens and no join/play blocks, ever. Keep optional-system failures isolated and non-fatal.
- Keep the change minimal. If you change files, run scripts/gate.sh in the worktree and report its result.
- Write no files outside the worktree except nothing at all. The packet's evidence notes are for Prime, not for you.

When you finish, your final reply must be exactly this form:
RESULT: PASS | FAIL | WAITING | BLOCKED
SUMMARY: what was established or changed
CHANGED: exact files or "none"
CHECKS: commands/scenarios and outcomes
EVIDENCE: paths to durable artifacts
UNVERIFIED: anything not actually exercised
RISKS: remaining material risks
NEXT: suggested follow-up tasks
EOF
)"

# --- dispatch ---------------------------------------------------------------
(cd "$WT" && deepcode -x -p "$LANE_HEADER") < "$PACKET" > "$TASK_DIR/run.log" 2>&1

# --- evidence capture -------------------------------------------------------
git -C "$WT" status --porcelain > "$TASK_DIR/status.txt" 2>&1 || true
git -C "$WT" diff > "$TASK_DIR/diff.txt" 2>&1 || true

if [ -s "$TASK_DIR/status.txt" ]; then
	(cd "$WT" && scripts/gate.sh) > "$TASK_DIR/gate.txt" 2>&1 || true
else
	echo "gate: no changes in worktree" > "$TASK_DIR/gate.txt"
fi

echo "lane $TASK_ID: dispatched and captured."
echo "  run:    $TASK_DIR/run.log"
echo "  status: $TASK_DIR/status.txt"
echo "  diff:   $TASK_DIR/diff.txt"
echo "  gate:   $TASK_DIR/gate.txt"
