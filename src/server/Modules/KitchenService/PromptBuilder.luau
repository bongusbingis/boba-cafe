--[[
    Module: PromptBuilder
    Description: Creates and destroys ProximityPrompts on kitchen models.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)

---> Types

type PromptConfig = KitchenTypes.PromptConfig

---> Module

local PromptBuilder = {}

---> Functions

function PromptBuilder.Detach(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			local parent = descendant.Parent
			descendant:Destroy()
			if parent and parent ~= model and parent.Name == "Part" and parent.Transparency == 1 then
				parent:Destroy()
			end
		end
	end
end

function PromptBuilder.Attach(model: Model, config: PromptConfig, callback: (Player) -> ()): ProximityPrompt
	PromptBuilder.Detach(model)

	local cf, _ = model:GetBoundingBox()

	local part = Instance.new("Part")
	part.Size = Vector3.one * 0.1
	part.CFrame = cf
	part.CanCollide = false
	part.Anchored = true
	part.Transparency = 1
	part.Parent = model

	model.PrimaryPart = part

	local holdDuration = config.HoldDuration or 3

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = config.Label
	prompt.ActionText = config.ActionText
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = config.MaxActivationDistance or KitchenConfig.PROMPT_DISTANCE
	prompt.Style = Enum.ProximityPromptStyle.Custom

	if config.Stock ~= nil then
		prompt:SetAttribute("DefaultStock", config.Stock)
		prompt:SetAttribute("CurrentStock", config.Stock)
		prompt:SetAttribute("Theme", config.Theme or "Restock")
	elseif config.Theme ~= nil then
		prompt:SetAttribute("Theme", config.Theme)
	end

	prompt.Parent = part
	prompt.Triggered:Connect(callback)

	return prompt
end

return PromptBuilder
