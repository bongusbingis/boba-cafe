--[[
    Module: ToolAttributeCheck
    Description: Action that validates the player's held tool attributes against a table of expected values.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
	return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function ToolAttributeCheck(player: Player, _actionModel: Model, expected: { [string]: any }): boolean
	local tool = getHeldTool(player)
	if not tool then
		return false
	end

	if typeof(expected) ~= "table" then
		warn("[ToolAttributeCheck] Expected a table of attributes.")
		return false
	end

	for attribute, want in expected do
		local have = tool:GetAttribute(attribute)
		if typeof(want) == "string" then
			if want:find("|", 1, true) then
				local matched = false
				for option in want:gmatch("[^|]+") do
					if have == option then
						matched = true
						break
					end
				end
				if not matched then
					return false
				end
			elseif have ~= want then
				return false
			end
		elseif want == true then
			if have ~= true then
				return false
			end
		elseif want == false then
			if have == true then
				return false
			end
		else
			warn(string.format("[ToolAttributeCheck] Unexpected expected value for '%s'", tostring(attribute)))
			return false
		end
	end

	return true
end

return ToolAttributeCheck
