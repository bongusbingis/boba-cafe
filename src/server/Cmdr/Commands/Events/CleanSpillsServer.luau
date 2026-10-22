--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context)
	local SpillService = Knit.GetService("SpillService")
	local ok, err = pcall(function()
		SpillService:CleanEverything()
	end)

	if not ok then
		return "Error cleaning spills: " .. tostring(err)
	end

	return "All spills cleaned!"
end
