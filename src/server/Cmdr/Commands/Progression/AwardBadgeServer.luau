--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)

return function(_context: any, targets: { Player }, badge: string): string
	local BadgeService = Knit.GetService("BadgeService")
	for _, target in targets do
		pcall(function()
			BadgeService:AwardBadgeByName(target, badge)
		end)
	end
	return string.format("Awarded badge %s to targets.", badge)
end
