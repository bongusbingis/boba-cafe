--[[
    Module: ToolNameMatcher
    Description: Shared matching rules for held-tool names, used by both the
    ToolNameValidityCheck action (as a hard gate) and the runner's Branch
    dispatch (to pick a recipe variant).

    Term prefixes:
      "="  exact equality       -- "=Mug"
      "#"  Lua pattern match    -- "#Clear Cup"
      "!"  must NOT match       -- "!Lid"
    Alternatives are separated by "|" within a single term, e.g. "#Clear Cup|=Mug".
--]]

---> Module

local ToolNameMatcher = {}

-- Evaluates a single term (no "|" separator) against a tool name.
function ToolNameMatcher.matchesTerm(toolName: string, term: string): boolean
	local prefix = term:sub(1, 1)

	if prefix == "!" then
		return toolName:match(term:sub(2)) == nil
	elseif prefix == "#" then
		return toolName:match(term:sub(2)) ~= nil
	elseif prefix == "=" then
		return toolName == term:sub(2)
	end

	warn(string.format("[ToolNameMatcher] Unrecognized term prefix in '%s'", term))
	return toolName == term
end

-- Evaluates one entry, which may contain "|"-separated alternatives.
function ToolNameMatcher.matchesEntry(toolName: string, entry: string): boolean
	if not entry:find("|", 1, true) then
		return ToolNameMatcher.matchesTerm(toolName, entry)
	end

	for term in entry:gmatch("[^|]+") do
		if ToolNameMatcher.matchesTerm(toolName, term) then
			return true
		end
	end

	return false
end

-- All entries must pass.
function ToolNameMatcher.matchesAll(toolName: string, entries: { string }): boolean
	for _, entry in entries do
		if not ToolNameMatcher.matchesEntry(toolName, entry) then
			return false
		end
	end

	return true
end

return ToolNameMatcher
