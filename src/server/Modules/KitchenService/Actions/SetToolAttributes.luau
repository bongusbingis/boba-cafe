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
	return true
end

return SetToolAttributes
