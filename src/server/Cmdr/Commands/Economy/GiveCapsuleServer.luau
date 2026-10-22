--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context: any, targets: { Player }, capsuleName: string)
	local CapsuleService = Knit.GetService("CapsuleService")
	for _, target in targets do
		pcall(function()
			CapsuleService:GrantEarnedCapsule(target, capsuleName)
		end)
	end

	return string.format("Granted capsule %s to %d player(s).", capsuleName, #targets)
end
