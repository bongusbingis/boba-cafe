---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Assets

local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")
local SelectorModels = ReplicatedStorage:FindFirstChild("SelectorModels")

local Tools = SharedStorage.Tools.Kitchen
local Animations = SharedStorage.Animations.Kitchen
local AllAnimations = SharedStorage.Animations
local TemporaryItems = AllAnimations.TemporaryItems

---> Module

local RecipeConstructors = {}

-- Scooping powder out of a tub, spoon in the left hand. Shared by the tea and hot
-- chocolate stations, which used identical timing in the original game.
local SCOOP_ANIMATION = {
	Animation = AllAnimations.ScoopAnimation_01,
	HoldInLeftHand = TemporaryItems.Spoon_01,
	DoActionAfter = 1.5,
}

RecipeConstructors.SCOOP_ANIMATION = SCOOP_ANIMATION

local coffeeNames = {}

function RecipeConstructors.makeCoffeeVariant(name: string, color: Color3): { { any } }
	table.insert(coffeeNames, "=" .. name)
	return {
		{ "SetToolHoldingProperty", "Liquid", "Color", color },
		{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
		{ "RenameToolHolding", name },
	}
end

function RecipeConstructors.makeTeaVariant(name: string, color: Color3): { { any } }
	return {
		Sound = "Powder",
		HoldDuration = 2,
		Actions = {
			{ "ToolNameValidityCheck", { "#Water" } },
			{ "Animate", SCOOP_ANIMATION },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{ "RenameToolHolding", name },
		},
	}
end

function RecipeConstructors.makeHotChocolateVariant(flavor: string, color: Color3): { { any } }
	return {
		Sound = "Powder",
		HoldDuration = 2,
		Actions = {
			{ "ToolNameValidityCheck", { "=Mug + Steamed Milk" } },
			{ "Animate", SCOOP_ANIMATION },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{ "RenameToolHolding", flavor .. " Hot Chocolate" },
		},
	}
end

function RecipeConstructors.makeCupGiver(name: "Clear Cup" | "Cup")
	return {
		HoldDuration = 0.5,
		Actions = {
			{
				"SelectFrom",
				{
					Title = name,
					Text = "Choose a size:",
					Buttons = { { Text = "Small" }, { Text = "Medium" }, { Text = "Large" } },
				},
				{
					["Small"] = {
						{ "AnimateRaw", Animations.GrabAnimation_01, true },
						{ "GiveTool", Tools.Cups["Small " .. name] },
					},
					["Medium"] = {
						{ "AnimateRaw", Animations.GrabAnimation_01, true },
						{ "GiveTool", Tools.Cups["Medium " .. name] },
					},
					["Large"] = {
						{ "AnimateRaw", Animations.GrabAnimation_01, true },
						{ "GiveTool", Tools.Cups["Large " .. name] },
					},
				},
			},
		},
	}
end

function RecipeConstructors.makeGrabSelector(title: string, text: string, tools: { Instance })
	local function resolveSelectorModel(name: string): Instance?
		if not SelectorModels then
			return nil
		end

		local exact = SelectorModels:FindFirstChild(name, true)
		if exact and (exact:IsA("Model") or exact:IsA("BasePart")) then
			return exact
		end

		return nil
	end

	local function resolvePreviewModel(tool: Instance): Instance?
		local selectorModel = resolveSelectorModel(tool.Name)
		if selectorModel then
			return selectorModel
		end

		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		end

		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("Model") and descendant:FindFirstChildWhichIsA("BasePart", true) then
				return descendant
			end
		end

		local basePart = tool:FindFirstChildWhichIsA("BasePart", true)
		if basePart then
			return basePart
		end

		return nil
	end

	local buttons = {}
	local items = {}
	local selectionActions = {}
	for _, tool in tools do
		table.insert(buttons, { Text = tool.Name })
		table.insert(items, {
			Name = tool.Name,
			ModelName = tool.Name,
			Model = resolvePreviewModel(tool),
		})
		selectionActions[tool.Name] = {
			{ "AnimateRaw", Animations.GrabAnimation_01, true },
			{ "GiveTool", tool },
		}
	end
	return {
		HoldDuration = 1,
		Actions = {
			{
				"SelectFrom",
				{
					Title = title,
					Text = text,
					Buttons = buttons,
					DialogType = "PromptSelection",
					Items = items,
				},
				selectionActions,
			},
		},
	}
end

-- Fruits Freezer: pick a fruit to drop into a clear cup. The tool keeps its size prefix
-- and gains a literal "[Fruit]" marker; the real fruit name is stored on the tool by
-- AddFruit so the Blender can resolve which smoothie to make.
function RecipeConstructors.makeFruitSelector(title: string, text: string, fruitNames: { string })
	local fruitCups = SelectorModels and SelectorModels:FindFirstChild("Fruits Cups")

	local buttons = {}
	local items = {}
	local selectionActions = {}

	for _, fruitName in fruitNames do
		table.insert(buttons, { Text = fruitName })
		table.insert(items, {
			Name = fruitName,
			ModelName = fruitName,
			Model = fruitCups and fruitCups:FindFirstChild(fruitName),
		})
		selectionActions[fruitName] = {
			{ "AnimateRaw", Animations.GrabAnimation_01, true },
			{ "AddFruit", fruitName },
			{
				"RenameToolHolding",
				function(old: string)
					return old .. " + [Fruit]"
				end,
			},
		}
	end

	return {
		HoldDuration = 1,
		Actions = {
			{ "ToolNameValidityCheck", { "#Clear Cup", "!%[Fruit%]" } },
			{
				"SelectFrom",
				{
					Title = title,
					Text = text,
					Buttons = buttons,
					DialogType = "PromptSelection",
					Items = items,
				},
				selectionActions,
			},
		},
	}
end

function RecipeConstructors.getCoffeeNames(): { string }
	return coffeeNames
end

return RecipeConstructors
