--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)

return function(_context: any, targets: { Player }, amount: number): string
	local ProgressionService = Knit.GetService("ProgressionService")
	for _, target in targets do
		pcall(function()
			ProgressionService:AddXp(target, amount)
		end)
	end
	return string.format("Granted %d XP to %d player(s).", amount, #targets)
end
