--[[
    Module: GiveTool
    Description: Action that clones a tool and equips it to the player's character.

    The clone is marked with the OrderSpec "Item" attribute (REVIVAL-001 M1.1 section 3)
    before it is equipped: Item = the cloned tool's name, which is right for every grab
    item (pastries, macarons, mochi, ice cream). An optional third argument, a table of
    literal attributes, is applied after it and may override Item (the cup givers use it
    to set Item = "Cup" / "Clear Cup" and Size). Recipe usage:
    { "GiveTool", tool, { Item = "Cup", Size = "Small" } }
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)

---> Helpers

local function getHeldTool(player: Player): Tool?
	return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

-- Every Tool the player carries (backpack + equipped), kitchen or not.
local function countTools(player: Player, character: Model): number
	local count = 0
	local backpack = if typeof(player.FindFirstChildOfClass) == "function"
		then player:FindFirstChildOfClass("Backpack")
		else (player :: any).Backpack
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					count += 1
				end
			end
		end
	end
	return count
end

---> Action

local function isLiteral(value: any): boolean
	local valueType = typeof(value)
	return valueType == "string" or valueType == "boolean" or valueType == "number"
end

local function GiveTool(player: Player, _actionModel: Model, toolToClone: Tool, attributes: { [string]: any }?): boolean
	local character = player.Character
	if not character then
		return false
	end

	-- Check the attributes before touching the held tool, so a bad recipe entry changes nothing.
	if attributes ~= nil then
		if typeof(attributes) ~= "table" then
			warn("[GiveTool] Expected a table of attributes.")
			return false
		end
		for name, value in attributes do
			if typeof(name) ~= "string" or not isLiteral(value) then
				warn(string.format("[GiveTool] Attribute '%s' is not a literal; nothing was given.", tostring(name)))
				return false
			end
		end
	end

	-- Cap carried tools so repeated giver use cannot flood the backpack. Returning false
	-- reports "GiveTool rejected" through the runner's InteractionFailed path.
	if countTools(player, character) >= KitchenConfig.MAX_HELD_TOOLS then
		pcall(function()
			Knit.GetService("DialogService"):Notify(player, {
				Title = "Hands full",
				Description = "You're carrying too many items. Serve or throw some away first!",
			})
		end)
		return false
	end

	local held = getHeldTool(player)
	if held then
		held.Parent = player.Backpack
	end

	local clone = toolToClone:Clone()

	clone:SetAttribute("Item", toolToClone.Name)
	if attributes then
		for name, value in attributes do
			clone:SetAttribute(name, value)
		end
	end

	-- If the tool is a cup with BobaBalls, make sure BobaBalls start hidden until tapioca is added
	if clone:GetAttribute("Tapioca") == nil then
		for _, desc in clone:GetDescendants() do
			if desc.Name == "BobaBalls" or desc.Name == "Tapioca" then
				local target: Instance = desc
				if
					(desc:IsA("SpecialMesh") or desc:IsA("FileMesh"))
					and desc.Parent
					and desc.Parent:IsA("BasePart")
				then
					target = desc.Parent
				end
				pcall(function()
					if target:IsA("BasePart") then
						target.Transparency = 1
					end
				end)
			end
		end
	end

	local autoWeld = clone:GetAttribute("AutoWeld")
	if autoWeld == true or autoWeld == nil then
		local handle = clone:FindFirstChild("Handle") :: BasePart?
		if handle then
			for _, part in clone:GetDescendants() do
				if part:IsA("BasePart") and part ~= handle then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = part :: BasePart
					weld.Parent = handle
				end
			end
		end
	end

	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end

	clone.Parent = character
	pcall(function()
		local a = require(game:GetService("ReplicatedStorage").Packages.Knit).GetService("AnalyticsEvents")
		a:OnboardingFunnel(player, 3, "FirstStationUse")
		a:Funnel(player, 3, "FirstItemTaken")
	end)
	return true
end

return GiveTool
