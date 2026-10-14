---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldPath = require(ReplicatedStorage:WaitForChild("Shared").Utility.WorldPath)

---> Constants

local ASSET_TIMEOUT_SECONDS = 5

---> Assets
-- Tools and animations are authored in the place (world contract):
--   ReplicatedStorage.SharedStorage.Tools.Kitchen.*
--   ReplicatedStorage.SharedStorage.Animations.Kitchen.*
-- They are looked up without erroring. A missing tool skips the recipe or branch
-- that needs it; a missing animation drops only the animation step.

local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage", ASSET_TIMEOUT_SECONDS)
local SelectorModels = ReplicatedStorage:FindFirstChild("SelectorModels")

local Tools = WorldPath.find(SharedStorage, { "Tools", "Kitchen" })
local Animations = WorldPath.find(SharedStorage, { "Animations", "Kitchen" })

if not Tools then
	warn("[Recipes] ReplicatedStorage.SharedStorage.Tools.Kitchen not found; recipes that give tools are skipped.")
end
if not Animations then
	warn("[Recipes] ReplicatedStorage.SharedStorage.Animations.Kitchen not found; kitchen animations are skipped.")
end

---> Module

local RecipeConstructors = {}

local coffeeNames = {}
local warnedAnimations: { [string]: boolean } = {}

-- Returns SharedStorage.Tools.Kitchen[...path], or nil (with a warning) when missing.
function RecipeConstructors.getTool(path: { string }): Instance?
	if not Tools then
		return nil -- already warned once for the whole folder
	end
	local tool = WorldPath.find(Tools, path)
	if not tool then
		warn(string.format("[Recipes] Tool Tools.Kitchen.%s not found; skipping it.", table.concat(path, ".")))
	end
	return tool
end

-- Returns the tools that exist for a list of { Category, Name } paths.
function RecipeConstructors.getTools(paths: { { string } }): { Instance }
	local tools = {}
	for _, path in paths do
		local tool = RecipeConstructors.getTool(path)
		if tool then
			table.insert(tools, tool)
		end
	end
	return tools
end

-- Returns the action steps that grab `tool`, with the grab animation first when
-- it exists. `attributes` (optional) are the tool attributes GiveTool applies on
-- top of its default Item = the tool's name (see Actions/GiveTool).
local function grabActions(tool: Instance, attributes: { [string]: any }?): { { any } }
	local actions = {}
	local animation = Animations and Animations:FindFirstChild("GrabAnimation_01")
	if animation then
		table.insert(actions, { "AnimateRaw", animation, true })
	elseif Animations and not warnedAnimations.GrabAnimation_01 then
		warnedAnimations.GrabAnimation_01 = true
		warn("[Recipes] Animation Animations.Kitchen.GrabAnimation_01 not found; grabbing plays no animation.")
	end
	if attributes then
		table.insert(actions, { "GiveTool", tool, attributes })
	else
		table.insert(actions, { "GiveTool", tool })
	end
	return actions
end

function RecipeConstructors.makeCoffeeVariant(name: string, color: Color3): { { any } }
	table.insert(coffeeNames, "=" .. name)
	return {
		{ "SetToolHoldingProperty", "Liquid", "Color", color },
		{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
		{ "RenameToolHolding", name },
		{ "SetToolAttributes", { Item = name } },
	}
end

function RecipeConstructors.makeTeaVariant(name: string, color: Color3): { { any } }
	return {
		Sound = "Powder",
		HoldDuration = 2,
		Actions = {
			{ "ToolNameValidityCheck", { "#Water" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{ "RenameToolHolding", name },
			{ "SetToolAttributes", { Item = name } },
		},
	}
end

function RecipeConstructors.makeHotChocolateVariant(flavor: string, color: Color3): { { any } }
	-- The Menu item name; the plain recipe (flavor "") is "Hot Chocolate". The tool is
	-- still renamed `flavor .. " Hot Chocolate"` (unchanged), so only the attribute needs this.
	local item = if flavor == "" then "Hot Chocolate" else flavor .. " Hot Chocolate"
	return {
		Sound = "Powder",
		HoldDuration = 2,
		Actions = {
			{ "ToolNameValidityCheck", { "=Mug + Steamed Milk" } },
			{ "SetToolHoldingProperty", "Liquid", "Color", color },
			{ "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
			{ "RenameToolHolding", flavor .. " Hot Chocolate" },
			{ "SetToolAttributes", { Item = item } },
		},
	}
end

-- Returns nil when none of the cup sizes have a tool.
function RecipeConstructors.makeCupGiver(name: "Clear Cup" | "Cup")
	local buttons = {}
	local branches = {}
	for _, size in { "Small", "Medium", "Large" } do
		local tool = RecipeConstructors.getTool({ "Cups", size .. " " .. name })
		if tool then
			table.insert(buttons, { Text = size })
			branches[size] = grabActions(tool, { Item = name, Size = size })
		end
	end

	if #buttons == 0 then
		return nil
	end

	return {
		HoldDuration = 0.5,
		Actions = {
			{
				"SelectFrom",
				{
					Title = name,
					Text = "Choose a size:",
					Buttons = buttons,
				},
				branches,
			},
		},
	}
end

-- Returns nil when `tools` is empty (every tool was missing).
function RecipeConstructors.makeGrabSelector(title: string, text: string, tools: { Instance })
	if #tools == 0 then
		return nil
	end

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
		selectionActions[tool.Name] = grabActions(tool)
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

function RecipeConstructors.getCoffeeNames(): { string }
	return coffeeNames
end

return RecipeConstructors
