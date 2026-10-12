---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> module declaration
local KitchenAnimationController = Knit.CreateController({
	Name = "KitchenAnimationController",
	ActiveTweens = {},
})

---> private

-- Effects are transient and purely cosmetic: a part fades out while an animation plays,
-- then snaps back so the next player sees the station in its original state.
function KitchenAnimationController:_setTransparency(target: Instance, value: number, duration: number)
	if not target:IsA("BasePart") then
		return
	end

	local existing = self.ActiveTweens[target]
	if existing then
		existing:Cancel()
		self.ActiveTweens[target] = nil
	end

	local original = target.Transparency

	if duration <= 0 then
		target.Transparency = value
		return
	end

	local tween = TweenService:Create(target, TweenInfo.new(duration), { Transparency = value })
	self.ActiveTweens[target] = tween

	tween.Completed:Once(function()
		if self.ActiveTweens[target] == tween then
			self.ActiveTweens[target] = nil
			target.Transparency = original
		end
	end)

	tween:Play()
end

function KitchenAnimationController:_handleEffect(effectType: string, target: Instance, value: number, duration: number)
	if not target or not target:IsDescendantOf(workspace) then
		return
	end

	if effectType == "SetTransparency" then
		self:_setTransparency(target, value, duration)
	else
		warn(`[KitchenAnimationController] Unknown effect type: {effectType}`)
	end
end

---> lifecycle

function KitchenAnimationController:KnitStart()
	local kitchenService = Knit.GetService("KitchenService")

	kitchenService.StationEffect:Connect(function(effectType, target, value, duration)
		self:_handleEffect(effectType, target, value, duration)
	end)
end

return KitchenAnimationController
