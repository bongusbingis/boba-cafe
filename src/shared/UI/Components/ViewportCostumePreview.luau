--!strict
--[[
	ViewportCostumePreview
	Renders a live 3D preview of the player wearing a Uniform or Boba Costume inside a ViewportFrame.
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
	Uniform: string?, -- "Default" | "StarEmployee" | nil
	Costume: string?, -- "BobaCostume" | nil
	Size: UDim2?,
	LayoutOrder: number?,
	ZIndex: number?,
	ElevationAngle: number?,
	ModelRotation: number?,
	CameraDistanceMultiplier: number?,
}

local function applyUniform(charModel: Model, uniformName: string)
	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local uniforms = sharedStorage and sharedStorage:FindFirstChild("Uniforms")
	local folder = uniforms and uniforms:FindFirstChild(uniformName)
	if not folder then
		return
	end

	local shirtAsset = folder:FindFirstChild("Shirt")
	if shirtAsset and shirtAsset:IsA("Shirt") then
		local charShirt = charModel:FindFirstChildOfClass("Shirt")
		if not charShirt then
			charShirt = Instance.new("Shirt")
			charShirt.Name = "Shirt"
			charShirt.Parent = charModel
		end
		charShirt.ShirtTemplate = shirtAsset.ShirtTemplate
	end

	local pantsAsset = folder:FindFirstChild("Pants")
	if pantsAsset and pantsAsset:IsA("Pants") then
		local charPants = charModel:FindFirstChildOfClass("Pants")
		if not charPants then
			charPants = Instance.new("Pants")
			charPants.Name = "Pants"
			charPants.Parent = charModel
		end
		charPants.PantsTemplate = pantsAsset.PantsTemplate
	end
end

local function buildPlayerPreview(uniformName: string?, costumeName: string?): Model?
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

	-- Apply uniform if specified
	if uniformName ~= nil then
		applyUniform(charModel, uniformName)
	end

	-- Apply costume if specified or default when no uniform
	local shouldAttachCostume = costumeName == "BobaCostume" or (costumeName == nil and uniformName == nil)
	if shouldAttachCostume then
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
	end

	return charModel
end

return function(props: Props)
	local previewModel, setPreviewModel = React.useState(nil :: Model?)

	React.useEffect(function()
		local model = buildPlayerPreview(props.Uniform, props.Costume)
		setPreviewModel(model)

		return function()
			if model then
				model:Destroy()
			end
		end
	end, { props.Uniform, props.Costume })

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
		ElevationAngle = props.ElevationAngle or 10,
		CameraDistanceMultiplier = props.CameraDistanceMultiplier or 0.65,
		FocusOffset = Vector3.new(0, 0.4, 0),
		FieldOfView = 30,
	})
end
