-- Executes the real OnboardingUtil source against the role/gate rules.
-- These decide what a player is permitted to do, so they are worth testing directly.
-- Run: lune run tools/verify-onboarding.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local src = fs.readFile("src/shared/Utility/OnboardingUtil.luau")
local U = luau.load(src, { environment = { math = math, string = string } })()

local RULES = { BaristaPlaytimeRequirement = 600, RankBypass = 7 }
local NOW = 1700000000

local pass, fail = 0, 0
local function check(label, actual, expected)
	if actual == expected then
		pass += 1
	else
		fail += 1
		print(string.format("  FAIL %s (got %s, want %s)", label, tostring(actual), tostring(expected)))
	end
end

local function state(role, onboarded, barista)
	return { ActiveRole = role, WorkerOnboarded = onboarded, BaristaUnlocked = barista }
end

print("lifetime playtime")
check("banked only, no session", U.getLifetimePlaytime(300, 0, NOW), 300)
check("banked plus live session", U.getLifetimePlaytime(300, NOW - 120, NOW), 420)
-- A first-timer has no banked time; the gate must still be reachable this session.
check("first session counts", U.getLifetimePlaytime(0, NOW - 600, NOW), 600)
check("negative banked clamped", U.getLifetimePlaytime(-50, 0, NOW), 0)
check("future join does not go negative", U.getLifetimePlaytime(100, NOW + 50, NOW), 100)

print("rank bypass")
check("rank 7 bypasses", U.hasRankBypass(7, RULES), true)
check("rank 8 bypasses", U.hasRankBypass(8, RULES), true)
check("rank 6 does not", U.hasRankBypass(6, RULES), false)
check("rank 0 does not", U.hasRankBypass(0, RULES), false)
check("staff skip role select", U.shouldShowRoleSelect(7, RULES), false)
check("everyone else sees it", U.shouldShowRoleSelect(0, RULES), true)

print("barista gate")
local ok, reason = U.canTrainBarista(state("Worker", false, false), 9999, RULES)
check("blocked before worker onboarding", ok, false)
check("names the onboarding requirement", reason, "Work a shift first.")

ok = U.canTrainBarista(state("Worker", true, false), 599, RULES)
check("blocked one second short", ok, false)
ok = U.canTrainBarista(state("Worker", true, false), 600, RULES)
check("allowed exactly at threshold", ok, true)
ok = U.canTrainBarista(state("Worker", true, true), 9999, RULES)
check("blocked once already unlocked", ok, false)

print("barista progress bar")
check("zero at start", U.getBaristaProgress(0, RULES), 0)
check("half way", U.getBaristaProgress(300, RULES), 0.5)
check("full at threshold", U.getBaristaProgress(600, RULES), 1)
check("clamped beyond threshold", U.getBaristaProgress(99999, RULES), 1)

print("taking orders")
-- The group requirement was dropped: an ungrouped Worker must be able to work.
check("ungrouped worker may take orders", U.canTakeOrders(state("Worker", true, false), 0, RULES), true)
check("customer may not", U.canTakeOrders(state("Customer", true, true), 0, RULES), false)
check("ranked staff may regardless of role", U.canTakeOrders(state("Customer", false, false), 7, RULES), true)
check("brand new worker may", U.canTakeOrders(state("Worker", false, false), 0, RULES), true)

print("kitchen access")
check("worker without barista may not", U.canUseKitchen(state("Worker", true, false), 0, RULES), false)
check("worker with barista may", U.canUseKitchen(state("Worker", true, true), 0, RULES), true)
check("customer with barista may not", U.canUseKitchen(state("Customer", true, true), 0, RULES), false)
check("ranked staff may regardless", U.canUseKitchen(state("Customer", false, false), 8, RULES), true)

print("denial messages are actionable")
local msg = U.explainDenial("TakeOrders", state("Customer", false, false), 0, RULES)
check("customer told to switch role", msg, "Switch to the Worker role to do that.")
msg = U.explainDenial("UseKitchen", state("Worker", true, false), 300, RULES)
check("kitchen denial names the wait", string.find(msg, "5 more minutes") ~= nil, true)
msg = U.explainDenial("UseKitchen", state("Worker", true, false), 600, RULES)
check("kitchen denial says train now", string.find(msg, "train now") ~= nil, true)

print("step sequencing")
local STEPS = { { Id = "a" }, { Id = "b" }, { Id = "c" } }
local step, index = U.getCurrentStep(STEPS, 0)
check("first step from zero", step.Id, "a")
check("index is 1", index, 1)
step = U.getCurrentStep(STEPS, 2)
check("third step after two done", step.Id, "c")
step = U.getCurrentStep(STEPS, 3)
check("nil once complete", step, nil)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
	process.exit(1)
end
