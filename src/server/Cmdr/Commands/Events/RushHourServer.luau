--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context, duration: number?)
	local EventService = Knit.GetService("EventService")
	local durationSeconds = duration or 600
	local ok, success, err = pcall(function()
		return EventService:StartEvent("RushHour", context.Executor, durationSeconds)
	end)

	if not ok then
		return "Error triggering Rush Hour: " .. tostring(success)
	end

	if not success then
		return err or "Failed to start Rush Hour."
	end

	return `Rush Hour started for {durationSeconds} seconds!`
end
