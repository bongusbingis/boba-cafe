--[[
	Module: SetToolAttributes
	Description: Action that sets attributes on the tool the player is currently holding.

	Recipes append it as the LAST step of a station. A station whose validity check
	(or any earlier step) fails stops the sequence before it gets here, so the tool
	stays unmarked. The attribute names are the OrderSpec contract: Item, Size, Syrup,
	Tapioca, Iced, Sugar and Lid (REVIVAL-001 M1.1 section 3). Values are literals
	(string, boolean or number). Tools live in the server-owned character, so a client
	cannot forge them.

	Recipe usage: { "SetToolAttributes", { Item = "Milk" } }
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
	return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

local function isLiteral(value: any): boolean
	local valueType = typeof(value)
	return valueType == "string" or valueType == "boolean" or valueType == "number"
end

---> Action

local function SetToolAttributes(player: Player, _actionModel: Model, attributes: { [string]: any }): boolean
	local tool = getHeldTool(player)
	if not tool then
		return false
	end

	if typeof(attributes) ~= "table" then
		warn("[SetToolAttributes] Expected a table of attributes.")
		return false
	end

	-- Check every pair before writing any, so a bad entry cannot leave the tool half-marked.
	for name, value in attributes do
		if typeof(name) ~= "string" or not isLiteral(value) then
			warn(
				string.format(
					"[SetToolAttributes] Attribute '%s' is not a string-keyed literal; nothing was set.",
					tostring(name)
				)
			)
			return false
		end
	end

	for name, value in attributes do
		tool:SetAttribute(name, value)
	end

	if attributes.ClearAttributes == true then
		for _, attrName in { "ClearAttributes", "Syrup", "Tapioca", "Iced", "Sugar", "Lid", "Blended", "Served" } do
			tool:SetAttribute(attrName, nil)
		end
		if tool.Name:find("Mug") ~= nil then
			tool:SetAttribute("Item", "Mug")
			tool:SetAttribute("Size", "Mug")
		else
			local isClear = tool:FindFirstChild("CoffeeCup") == nil and tool:FindFirstChild("CoffeeHolder") == nil
			local sizeVal = tool:FindFirstChild("Size")
			local size = (sizeVal and sizeVal:IsA("StringValue") and sizeVal.Value ~= "" and sizeVal.Value)
				or tool:GetAttribute("Size")
				or "Medium"
			if size ~= "Small" and size ~= "Medium" and size ~= "Large" then
				size = "Medium"
			end
			tool:SetAttribute("Item", if isClear then "Clear Cup" else "Cup")
			tool:SetAttribute("Size", size)
		end
		for _, desc in tool:GetDescendants() do
			if
				desc.Name == "BobaBalls"
				or desc.Name == "Tapioca"
				or desc.Name == "Liquid"
				or desc.Name == "CoffeeLid"
			then
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

	if attributes.Tapioca ~= nil and typeof(attributes.Tapioca) == "string" then
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
		local color = Recipes.Tapioca[attributes.Tapioca]
		for _, desc in tool:GetDescendants() do
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
						target.Transparency = 0
						if color then
							target.Color = color
						end
					end
				end)
			end
		end
	end
	return true
end

return SetToolAttributes
