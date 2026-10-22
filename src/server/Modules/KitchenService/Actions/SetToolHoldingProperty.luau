--[[
	Module: SetToolHoldingProperty
	Description: Action that sets a property on a named child or descendant of the player's held tool.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
	return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function SetToolHoldingProperty(
	player: Player,
	actionModel: Model,
	instanceName: string,
	propertyName: string,
	newValue: any
): boolean
	local tool = getHeldTool(player)
	if not tool then
		return false
	end

	local targets: { Instance } = {}
	for _, desc in tool:GetDescendants() do
		if desc.Name == instanceName then
			table.insert(targets, desc)
		end
	end

	if #targets == 0 then
		local direct = tool:FindFirstChild(instanceName)
		if direct then
			table.insert(targets, direct)
		end
	end

	if #targets == 0 then
		return true
	end

	for _, child in targets do
		local val = newValue
		if typeof(val) == "function" then
			val = val(child, actionModel)
		end

		local targetInstance: Instance = child
		if child:IsA("SpecialMesh") or child:IsA("FileMesh") then
			if propertyName == "Color" or propertyName == "Transparency" or propertyName == "Material" then
				if child.Parent and child.Parent:IsA("BasePart") then
					targetInstance = child.Parent
				end
			end
		end

		pcall(function()
			(targetInstance :: any)[propertyName] = val
		end)
	end

	return true
end

return SetToolHoldingProperty
