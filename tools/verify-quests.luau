-- Executes the real QuestUtil source against daily-quest rollover and counting rules.
-- Run: lune run tools/verify-quests.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local src = fs.readFile("src/shared/Utility/QuestUtil.luau")
local QuestUtil = luau.load(src, {
	environment = { math = math, table = table, typeof = type, tostring = tostring },
})()

local DAY = 86400
local pass, fail = 0, 0
local function check(label, actual, expected)
	if actual == expected then
		pass += 1
	else
		fail += 1
		print(string.format("  FAIL %s (got %s, want %s)", label, tostring(actual), tostring(expected)))
	end
end

print("expiry lands on UTC midnight")
check("midnight is exact multiple", QuestUtil.getNextExpiry(1700000000) % DAY, 0)
check("always in the future", QuestUtil.getNextExpiry(1700000000) > 1700000000, true)
-- Exactly on a boundary must roll to the NEXT day, not return the same instant.
check("boundary rolls forward", QuestUtil.getNextExpiry(DAY * 100), DAY * 101)

print("expiry checks")
check("past expiry is expired", QuestUtil.hasExpired(100, 200), true)
check("future expiry is not", QuestUtil.hasExpired(300, 200), false)
check("equal counts as expired", QuestUtil.hasExpired(200, 200), true)
check("zero (never assigned) is expired", QuestUtil.hasExpired(0, 200), true)

print("sum progress")
local p = {}
p = QuestUtil.applyProgress(p, "PlayTime", "Sum", 5)
p = QuestUtil.applyProgress(p, "PlayTime", "Sum", 7)
check("accumulates", QuestUtil.getProgress(p, "PlayTime"), 12)
check("unrelated tracker is 0", QuestUtil.getProgress(p, "BobaOrdered"), 0)
check("goal met", QuestUtil.isComplete(p, "PlayTime", 12), true)
check("goal not met", QuestUtil.isComplete(p, "PlayTime", 13), false)

print("unique progress")
local u = {}
u = QuestUtil.applyProgress(u, "FriendJoined", "Unique", "111")
u = QuestUtil.applyProgress(u, "FriendJoined", "Unique", "222")
check("two distinct ids count 2", QuestUtil.getProgress(u, "FriendJoined"), 2)
u = QuestUtil.applyProgress(u, "FriendJoined", "Unique", "111")
check("repeat id does not double count", QuestUtil.getProgress(u, "FriendJoined"), 2)
u = QuestUtil.applyProgress(u, "FriendJoined", "Unique", 333)
check("numeric id is normalised to string", QuestUtil.getProgress(u, "FriendJoined"), 3)

print("rolling quests")
local BANK = {
	Easy = {
		{ Id = "e1" }, { Id = "e2" }, { Id = "e3" },
	},
	Moderate = { { Id = "m1" }, { Id = "m2" } },
	Hard = { { Id = "h1" } },
}
local SLOTS = { "Easy", "Moderate", "Hard", "Easy" }

-- Deterministic: always take the first available.
local rolled = QuestUtil.rollQuests(BANK, SLOTS, function()
	return 1
end)
check("fills every slot", #rolled, 4)

local seen = {}
local duplicate = false
for _, q in rolled do
	if seen[q.Id] then
		duplicate = true
	end
	seen[q.Id] = true
end
check("no duplicate quest in a day", duplicate, false)
check("slot 1 is Easy", rolled[1].Tier, "Easy")
check("slot 2 is Moderate", rolled[2].Tier, "Moderate")
check("slot 3 is Hard", rolled[3].Tier, "Hard")
check("slot 4 is Easy again", rolled[4].Tier, "Easy")
check("starts incomplete", rolled[1].Completed, false)

print("rolling is resilient")
-- A tier with fewer quests than slots referencing it must not error or repeat.
local thin = QuestUtil.rollQuests({ Easy = { { Id = "only" } } }, { "Easy", "Easy" }, function()
	return 1
end)
check("exhausted tier yields one quest", #thin, 1)

local missing = QuestUtil.rollQuests({}, SLOTS, function()
	return 1
end)
check("empty bank yields nothing", #missing, 0)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
	process.exit(1)
end
