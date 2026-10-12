-- Executes the real DailyStreak source against the daily-reward boundary conditions.
-- Run: lune run tools/verify-streak.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local src = fs.readFile("src/shared/Utility/DailyStreak.luau")
local DailyStreak = luau.load(src, { environment = { math = math } })()

local DAY = 86400
local RULES = { CycleLength = 7, ClaimInterval = DAY, StreakGrace = DAY * 2 }
-- Realistic epoch: a small NOW makes "long absence" cases go negative, which is
-- correctly treated as "never claimed" and would mask what the test means to check.
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

print("first ever claim")
local s = DailyStreak.evaluate({ CurrentDay = 0, LastClaimed = 0 }, RULES, NOW)
check("can claim", s.CanClaim, true)
check("starts at day 1", s.NextDay, 1)
check("not a reset", s.StreakReset, false)

print("too soon")
s = DailyStreak.evaluate({ CurrentDay = 1, LastClaimed = NOW - (DAY - 1) }, RULES, NOW)
check("blocked", s.CanClaim, false)
check("1 second remaining", s.SecondsRemaining, 1)
check("still points at day 2", s.NextDay, 2)

print("exactly at the interval boundary")
s = DailyStreak.evaluate({ CurrentDay = 1, LastClaimed = NOW - DAY }, RULES, NOW)
check("claimable", s.CanClaim, true)
check("advances to day 2", s.NextDay, 2)
check("no reset", s.StreakReset, false)

print("inside the grace window")
s = DailyStreak.evaluate({ CurrentDay = 3, LastClaimed = NOW - (DAY * 2 - 1) }, RULES, NOW)
check("claimable", s.CanClaim, true)
check("advances to day 4", s.NextDay, 4)
check("streak intact", s.StreakReset, false)

print("grace window expired")
s = DailyStreak.evaluate({ CurrentDay = 5, LastClaimed = NOW - (DAY * 2) }, RULES, NOW)
check("claimable", s.CanClaim, true)
check("back to day 1", s.NextDay, 1)
check("flagged as reset", s.StreakReset, true)

print("long absence")
s = DailyStreak.evaluate({ CurrentDay = 6, LastClaimed = NOW - (DAY * 40) }, RULES, NOW)
check("back to day 1", s.NextDay, 1)
check("flagged as reset", s.StreakReset, true)

print("cycle wraps at the end")
s = DailyStreak.evaluate({ CurrentDay = 7, LastClaimed = NOW - DAY }, RULES, NOW)
check("wraps to day 1", s.NextDay, 1)
check("not treated as a reset", s.StreakReset, false)

print("never returns an out-of-range day")
for day = 0, 7 do
	local r = DailyStreak.evaluate({ CurrentDay = day, LastClaimed = NOW - DAY }, RULES, NOW)
	check("day " .. day .. " in range", r.NextDay >= 1 and r.NextDay <= RULES.CycleLength, true)
end

print("degenerate cycle length is survivable")
s = DailyStreak.evaluate({ CurrentDay = 0, LastClaimed = NOW - DAY }, { CycleLength = 0, ClaimInterval = DAY, StreakGrace = DAY * 2 }, NOW)
check("still yields day 1", s.NextDay, 1)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
	process.exit(1)
end
