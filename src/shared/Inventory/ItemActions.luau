--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local function hatchCapsule(ctx)
	local capsuleName = ctx.item.Name
	local capsuleId = ctx.item:GetId()

	local CapsuleService = Knit.GetService("CapsuleService")
	local ok = CapsuleService:StartHatch(ctx.player, capsuleId, capsuleName, ctx.item:GetProperty("RandomSource"))
	if not ok then
		return
	end
end

return {
	Capsules = setmetatable({}, {
		__index = function(_)
			return hatchCapsule
		end,
	}),
}
