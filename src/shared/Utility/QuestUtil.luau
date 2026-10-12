--[[
    Module: QuestUtil
    Description: Pure helpers for daily quests — expiry, progress counting and
    completion. No Roblox APIs and no state, so the rollover and counting rules can be
    tested directly.
--]]

local QuestUtil = {}

local SECONDS_PER_DAY = 86400

--- Next UTC midnight after `now`. Quests expire on this boundary, so everyone rolls
--- over at the same moment regardless of timezone.
function QuestUtil.getNextExpiry(now: number): number
	return (math.floor(now / SECONDS_PER_DAY) + 1) * SECONDS_PER_DAY
end

--- Whether the assigned set has lapsed and should be rerolled.
function QuestUtil.hasExpired(expires: number, now: number): boolean
	return (expires or 0) <= now
end

--- Progress toward a quest, normalising the two counting modes:
--- "Sum" stores a running number, "Unique" stores a set whose size is the count.
function QuestUtil.getProgress(progress: { [string]: any }, tracker: string): number
	local raw = progress and progress[tracker]

	if raw == nil then
		return 0
	end

	if typeof(raw) == "number" then
		return raw
	end

	if typeof(raw) == "table" then
		local count = 0
		for _ in raw do
			count += 1
		end
		return count
	end

	return 0
end

--- Applies `value` to `tracker` and returns the updated progress table. Sum mode adds
--- numbers; Unique mode records ids in a set so repeats do not count twice.
function QuestUtil.applyProgress(
	progress: { [string]: any },
	tracker: string,
	mode: string,
	value: number | string
): { [string]: any }
	local updated = progress or {}

	if mode == "Unique" then
		local key = tostring(value)
		local set = updated[tracker]

		if typeof(set) ~= "table" then
			set = {}
			updated[tracker] = set
		end

		set[key] = true
		return updated
	end

	-- Sum mode. Non-numeric values count as a single increment.
	local amount = if typeof(value) == "number" then value else 1
	local current = updated[tracker]
	updated[tracker] = (if typeof(current) == "number" then current else 0) + amount

	return updated
end

--- True when `progress` satisfies `goal`.
function QuestUtil.isComplete(progress: { [string]: any }, tracker: string, goal: number): boolean
	return QuestUtil.getProgress(progress, tracker) >= goal
end

--- Picks one quest per slot, never repeating a quest within the day. `randomIndex`
--- is injected so tests can make the selection deterministic.
function QuestUtil.rollQuests(
	bank: { [string]: { any } },
	slots: { string },
	randomIndex: (max: number) -> number
): { { Id: string, Tier: string, Completed: boolean } }
	local taken: { [string]: boolean } = {}
	local result = {}

	for _, tier in slots do
		local pool = bank[tier]
		if not pool or #pool == 0 then
			continue
		end

		-- Only consider quests not already assigned today.
		local available = {}
		for _, quest in pool do
			if not taken[quest.Id] then
				table.insert(available, quest)
			end
		end

		if #available == 0 then
			continue
		end

		local chosen = available[randomIndex(#available)]
		taken[chosen.Id] = true

		table.insert(result, {
			Id = chosen.Id,
			Tier = tier,
			Completed = false,
		})
	end

	return result
end

return QuestUtil
