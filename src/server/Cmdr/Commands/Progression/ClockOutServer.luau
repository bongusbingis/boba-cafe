--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)

return function(_context: any, targets: { Player }): string
	local ShiftService = Knit.GetService("ShiftService")
	for _, target in targets do
		pcall(function()
			ShiftService:SetClockedIn(target, false)
		end)
	end
	return "Clocked out targets."
end
