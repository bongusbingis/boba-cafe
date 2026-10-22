--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context)
	local EventService = Knit.GetService("EventService")
	local ok, ended = pcall(function()
		return EventService:EndActiveEvent()
	end)

	if not ok then
		return "Error ending event: " .. tostring(ended)
	end

	if ended then
		return "Active event ended."
	else
		return "No active event to end."
	end
end
