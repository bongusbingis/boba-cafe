--!nonstrict
--[[
	useQuestClaimable
	Returns true while the player has a completed, unclaimed daily or weekly quest.
	Drives the claim dot on the Menu button and the Menu's Quests tab.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local function anyClaimable(quests): boolean
	if typeof(quests) ~= "table" then
		return false
	end
	for _, entry in quests do
		if entry.Completed == true and entry.Claimed ~= true then
			return true
		end
	end
	return false
end

return function(): boolean
	local dailyClaimable, setDaily = React.useState(false)
	local weeklyClaimable, setWeekly = React.useState(false)

	if RunService:IsRunning() then
		React.useEffect(function()
			local conns = {}
			local alive = true

			local function watch(getter: string, signal: string, setter)
				pcall(function()
					local questService = Knit.GetService("QuestService")
					local res = questService[getter](questService)
					local function apply(quests)
						if alive and typeof(quests) == "table" then
							setter(anyClaimable(quests))
						end
					end
					if typeof(res) == "table" and res.andThen then
						res:andThen(apply)
					elseif typeof(res) == "table" then
						apply(res)
					end
					if alive then
						table.insert(conns, questService[signal]:Connect(apply))
					end
				end)
			end

			task.spawn(function()
				watch("GetQuests", "QuestsUpdated", setDaily)
				watch("GetWeeklyQuests", "WeeklyQuestsUpdated", setWeekly)
			end)

			return function()
				alive = false
				for _, conn in conns do
					conn:Disconnect()
				end
			end
		end, {})
	end

	return dailyClaimable or weeklyClaimable
end
