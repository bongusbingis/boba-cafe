--!strict
--[[
	WorldPath
	Looks up content authored in the place (workspace.Assets, "Ordering System",
	SharedStorage, ...) without erroring. A missing step returns nil; callers
	warn and disable only the feature that needs it.
]]

local WorldPath = {}

-- Returns root[path[1]][path[2]]..., or nil when any step is missing. Never yields.
function WorldPath.find(root: Instance?, path: { string }): Instance?
	local current = root
	for _, name in path do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- Like find, but waits for missing steps, at most `timeoutSeconds` for the whole path.
-- Yields; call it from KnitStart or a spawned thread, never at require time.
function WorldPath.waitFor(root: Instance?, path: { string }, timeoutSeconds: number): Instance?
	local deadline = os.clock() + timeoutSeconds
	local current = root
	for _, name in path do
		if not current then
			return nil
		end
		local child = current:FindFirstChild(name)
		local remaining = deadline - os.clock()
		if not child and remaining > 0 then
			child = current:WaitForChild(name, remaining)
		end
		current = child
	end
	return current
end

return WorldPath
