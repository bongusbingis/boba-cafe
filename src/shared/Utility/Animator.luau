local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise = require(Packages.Promise)

local AnimationManager = {}
AnimationManager.Prototype = {}

local PlayerCachedItems = {}

function AnimationManager:_resolveAnimationBase(animationBase: Model | Humanoid | Animator)
	if animationBase:IsA("Model") or animationBase:IsA("Humanoid") then
		return animationBase:FindFirstChildWhichIsA("Animator", true)
	elseif animationBase:IsA("Animator") then
		return animationBase
	end
end

function AnimationManager.Prototype:AddItems(player: Player, itemsData)
	local ItemAddPromises = {}
	if PlayerCachedItems[player] == nil then
		PlayerCachedItems[player] = {}
	end

	for _, itemData in itemsData do
		table.insert(
			ItemAddPromises,
			Promise.new(function(resolve)
				task.wait()
				itemData.Model.Parent = player.Character
				local itemMotor = Instance.new("Motor6D")
				itemMotor.Parent = itemData.Model
				for property, value in itemData.Motor do
					itemMotor[property] = value
				end
				table.insert(PlayerCachedItems[player], itemData.Model)
				resolve()
			end)
		)
	end

	Promise.all(ItemAddPromises):await()

	return self
end

function AnimationManager.Prototype:ClearAssociatedItems(player)
	if PlayerCachedItems[player] then
		for _, v in PlayerCachedItems[player] do
			v:Destroy()
		end
	end
	PlayerCachedItems[player] = nil
end

function AnimationManager:LoadAnimation(animationBase: (Model | Humanoid | Animator)?, animationForCharacter: Animation)
	print(animationBase, animationForCharacter)
	local animatorForCharacter: Animator = self:_resolveAnimationBase(animationBase)
	assert(animatorForCharacter, "Animation base input must be a character, humanoid, or animator")

	local animationTrack: AnimationTrack = animatorForCharacter:LoadAnimation(animationForCharacter)
	return setmetatable(AnimationManager.Prototype, {
		__index = function(_, index)
			if typeof(animationTrack[index]) == "function" then
				return function(_, ...)
					return animationTrack[index](animationTrack, ...)
				end
			else
				return animationTrack[index]
			end
		end,
	})
end

return AnimationManager
