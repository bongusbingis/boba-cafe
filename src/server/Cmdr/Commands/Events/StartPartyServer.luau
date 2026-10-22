--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context)
	local CafeRatingService = Knit.GetService("CafeRatingService")
	local ok, success, err = pcall(function()
		return CafeRatingService:StartOrExtendBobaParty(context.Executor)
	end)

	if not ok then
		return "Error starting Boba Party: " .. tostring(success)
	end

	if not success then
		return err or "Failed to start Boba Party."
	end

	return "Boba Party started!"
end
