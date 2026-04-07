---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Assets

local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")

local Tools = SharedStorage.Tools.Kitchen
local Animations = SharedStorage.Animations.Kitchen

---> Module

local RecipeConstructors = {}

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
		Actions = {
			{ "ToolNameValidityCheck", { "=Hot Water" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{ "RenameToolHolding", name },
		},
	}
end

function RecipeConstructors.makeHotChocolateVariant(flavor: string, color: Color3): { { any } }
	return {
		Actions = {
			{ "ToolNameValidityCheck", { "=Mug + Milk" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{ "RenameToolHolding", flavor .. " Hot Chocolate" },
		},
	}
end

function RecipeConstructors.makeCupGiver(name: "Clear Cup" | "Cup")
	return {
		HoldDuration = 0,
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
	local buttons = {}
	local selectionActions = {}
	for _, tool in tools do
		table.insert(buttons, { Text = tool.Name })
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
				{ Title = title, Text = text, Buttons = buttons },
				selectionActions,
			},
		},
	}
end

function RecipeConstructors.getCoffeeNames(): { string }
	return coffeeNames
end

return RecipeConstructors
