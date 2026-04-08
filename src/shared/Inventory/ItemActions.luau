--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

--------------------------------------------------------------------------------
-- Hatch action (shared by all capsule types via __index)
--------------------------------------------------------------------------------

local function hatchCapsule(ctx)
	local capsuleName = ctx.item.Name
	local capsuleId = ctx.item:GetId()

	-- For pet capsules, check the one-hatch limit BEFORE removing the item.
	local CapsuleService = Knit.GetService("CapsuleService")
	local ok = CapsuleService:StartHatch(ctx.player, capsuleId, capsuleName)

	if not ok then
		-- Player already has a pet hatch pending; leave the capsule in place.
		return
	end

	-- Remove the capsule only after the hatch has been successfully registered.
	ctx.inventory:_removeItemById(capsuleId)
end

--------------------------------------------------------------------------------
-- Registry
-- All capsule names share the same handler via __index.
--------------------------------------------------------------------------------

return {
	Capsules = setmetatable({}, {
		__index = function(_)
			return hatchCapsule
		end,
	}),
}
