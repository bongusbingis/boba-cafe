--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local function hatchCapsule(ctx)
	local capsuleName = ctx.item.Name
	local capsuleId = ctx.item:GetId()

	local CapsuleService = Knit.GetService("CapsuleService")
	local ok = CapsuleService:StartHatch(ctx.player, capsuleId, capsuleName)

	if not ok then
		return
	end

	ctx.inventory:_removeItemById(capsuleId)
end

return {
	Capsules = setmetatable({}, {
		__index = function(_)
			return hatchCapsule
		end,
	}),
}
