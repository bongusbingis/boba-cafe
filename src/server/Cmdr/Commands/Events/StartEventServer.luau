--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context, event: string, duration: number?)
	local EventService = Knit.GetService("EventService")
	local ok, success, err = pcall(function()
		return EventService:StartEvent(event, context.Executor, duration)
	end)

	if not ok then
		return "Error starting event: " .. tostring(success)
	end

	if not success then
		return err or `Failed to start event {event}.`
	end

	if duration then
		return `Event {event} started for {duration} seconds!`
	else
		return `Event {event} started!`
	end
end
