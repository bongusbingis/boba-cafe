RESULT: PASS

# REVIVAL-001-M0.9 evidence (Mason)

Task: REVIVAL-001-M0.9 - cheap mechanical code gate. HEAD: 92f6144 (tree dirty from in-progress M0 work).

## Changed
- rokit.toml (new): pins selene 0.31.0 and stylua 2.5.2 only. Rojo not pinned (resolves from global ~/.rokit/rokit.toml, 7.5.1).
- scripts/gate.sh (new, executable, bash 3.2 compatible)
- src/server/Tests/RunTests.server.luau: TESTS_ENABLED default false; also enabled when RunService:IsStudio() and workspace:GetAttribute("RunTests") == true; print now "Running test suite...".

## Tool check (from repo root)
selene --version -> selene 0.31.0 | stylua --version -> stylua 2.5.2 | rojo --version -> Rojo 7.5.1

## gate.sh usage
    scripts/gate.sh <file.luau>...     # explicit files
    scripts/gate.sh                    # all changed + untracked .lua/.luau (git status)
Baseline = git show HEAD:<file> (empty if untracked), selene run with repo selene.toml, findings compared as multiset of "level[code]: message" (line numbers stripped). stylua --check must pass unless HEAD version also fails ("pre-existing stylua drift", non-failing). Then `rojo build default.project.json -o ${TMPDIR}/gate-build.rbxl`. Exit 0 pass, 1 new finding/build failure, 2 tool missing.
Caveat: if HEAD already had stylua drift, further drift in the same file is not caught (by spec).

## Test outputs
    PASS  src/server/Modules/ShiftService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
    PASS  src/server/Scripts/ProcessReceipt.server.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
    PASS  src/server/Modules/CurrencyService.luau  selene new=0 (baseline[HEAD]=2 now=0)  stylua=ok
    PASS  rojo build -> $TMPDIR/gate-build.rbxl
    GATE: PASS   (rc=0)
Own files: PASS src/server/Tests/RunTests.server.luau selene new=0 stylua=ok; rojo PASS.
No-arg mode: 36 changed/untracked files, all PASS, rojo PASS (rc=0).
Negative tests: untracked probe file with unused vars + bad format -> 2 NEW unused_variable, STYLUA FAIL, GATE FAIL rc=1. Appending an unused line to a tracked file -> NEW parse_error, GATE FAIL rc=1 (file restored afterwards; diff vs prior state unchanged).
Bug found/fixed during testing: awk NR==FNR trick misfired with an empty baseline; now uses FILENAME==ARGV[1]. TMPDIR trailing slash in rojo output path fixed.
shellcheck: not installed; `bash -n` passes and script ran under /bin/bash 3.2.57.

## Running TestEZ via the attribute (Gauge procedure)
1. In Edit mode via MCP execute_luau: `workspace:SetAttribute("RunTests", true)`
2. Start Play (start_stop_play); read results with get_console_output ("[Tests] ... All N test(s) passed." or "N test(s) FAILED."). Suite starts after a 3s wait.
3. Stop Play, then in Edit mode clear it: `workspace:SetAttribute("RunTests", nil)` (verify GetAttribute is nil before saving the place).
Studio-only guard: a saved attribute does nothing in a live server.

## Unverified
TestEZ attribute path not run in Studio (no Studio per task).
