--!strict
--[[
	ViewportCostumePreview
	Renders a live 3D preview of the player wearing the Boba Costume inside a ViewportFrame.
	Reuses ViewportModel component for camera framing and lighting.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local ViewportModel = require(UI.Components.ViewportModel)

local c = React.createElement

export type Props = {
	Size: UDim2?,
	LayoutOrder: number?,
	ZIndex: number?,
	ElevationAngle: number?,
	ModelRotation: number?,
}

local function buildPlayerWithCostume(): Model?
	local localPlayer = Players.LocalPlayer
	local desc: HumanoidDescription? = nil
	if localPlayer and localPlayer.Character then
		local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				desc = humanoid:GetAppliedDescription()
			end)
		end
	end

	if not desc and localPlayer then
		pcall(function()
			desc = Players:GetHumanoidDescriptionFromUserId(localPlayer.UserId)
		end)
	end

	local fallbackDesc = desc or Instance.new("HumanoidDescription")
	local ok, charModel = pcall(function()
		return Players:CreateHumanoidModelFromDescription(fallbackDesc, Enum.HumanoidRigType.R15)
	end)

	if not ok or not charModel or not charModel:IsA("Model") then
		return nil
	end

	local charHrp = charModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not charHrp then
		charModel:Destroy()
		return nil
	end

	-- Look up BobaCostume template
	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local npcs = sharedStorage and sharedStorage:FindFirstChild("NPCs")
	local buddy = npcs and npcs:FindFirstChild("BobaBuddy")
	local templateCostume = buddy and buddy:FindFirstChild("BobaCostume")
	local templateHrp = buddy and buddy:FindFirstChild("HumanoidRootPart") :: BasePart?

	if templateCostume and templateCostume:IsA("Model") and templateHrp then
		local costumeClone = templateCostume:Clone()
		costumeClone.Name = "BobaCostume"

		-- Remove loose scripts inside viewport
		for _, child in costumeClone:GetDescendants() do
			if child:IsA("LuaSourceContainer") then
				child:Destroy()
			end
		end

		for _, part in costumeClone:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Massless = true
				part.Anchored = false

				local rel = templateHrp.CFrame:ToObjectSpace(part.CFrame)
				part.CFrame = charHrp.CFrame:ToWorldSpace(rel)

				local weld = Instance.new("WeldConstraint")
				weld.Name = `{part.Name}Weld`
				weld.Part0 = charHrp
				weld.Part1 = part
				weld.Parent = part
			end
		end

		costumeClone.Parent = charModel
	end

	return charModel
end

return function(props: Props)
	local previewModel, setPreviewModel = React.useState(nil :: Model?)

	React.useEffect(function()
		local model = buildPlayerWithCostume()
		setPreviewModel(model)

		return function()
			if model then
				model:Destroy()
			end
		end
	end, {})

	if not previewModel then
		return c("Frame", {
			BackgroundTransparency = 1,
			Size = props.Size or UDim2.fromScale(1, 1),
			LayoutOrder = props.LayoutOrder,
			ZIndex = props.ZIndex,
		})
	end

	return c(ViewportModel, {
		Model = previewModel,
		Size = props.Size or UDim2.fromScale(1, 1),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
		ModelRotation = props.ModelRotation or 15,
		ElevationAngle = props.ElevationAngle or 12,
		FieldOfView = 30,
	})
end
