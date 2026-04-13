--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local PetConfig = require(Shared.Configuration.PetConfig)

local PetShared = {}

export type EquippedPetSnapshot = {
	ItemId: string,
	Name: string,
	DisplayName: string,
	Tier: string?,
}

function PetShared.TrimName(rawName: string): string
	return (rawName:gsub("^%s*(.-)%s*$", "%1"))
end

function PetShared.ResolveDisplayName(baseName: string, properties: { [string]: any }?): string
	if typeof(properties) == "table" then
		local value = properties[PetConfig.RENAME_PROPERTY_KEY]
		if typeof(value) == "string" then
			local trimmed = PetShared.TrimName(value)
			if trimmed ~= "" then
				return trimmed
			end
		end
	end

	return baseName
end

return PetShared