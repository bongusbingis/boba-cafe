# WSL gate environment for this Windows checkout (DEC-010, DEC-016).
# Usage, from the repo root:  . .review/agent-workflow/tools/wsl/env.sh && gate <changed files>
# Runs the Windows rokit binaries from WSL (rojo 7.7.0 from rokit tool storage). The stylua shim
# checks CR-stripped content, because Windows git (autocrlf=true) checks files out as CRLF.
# "gate" is scripts/gate.sh with LF endings and REPO pinned to this checkout.
_wsl_tools="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$_wsl_tools/bin:$PATH" TMPDIR=/mnt/c/Users/jackc/AppData/Local/Temp/boba-gate
mkdir -p "$TMPDIR"
