--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)

return function(_context: any, targets: { Player }, titleId: string): string
	local ProgressionService = Knit.GetService("ProgressionService")
	for _, target in targets do
		pcall(function()
			ProgressionService:GrantTitle(target, titleId)
		end)
	end
	return string.format("Granted title '%s' to %d player(s).", titleId, #targets)
end
