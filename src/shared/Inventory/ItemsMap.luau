--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configuration = Shared:WaitForChild("Configuration")

local Types = require(script.Parent.Types)

type ItemType = Types.ItemType

local ItemDefinitions = require(Configuration:WaitForChild("InventoryItemDefinitions"))

--
-- Static item definitions only.
-- Put permanent/shared data here: icon ids, base stats, ability ids, tags, etc.
-- Put per-instance rolled data in InventoryItemRoot.Properties.
--
local map: { [ItemType]: { [string]: any } } = {
	Nametags = ItemDefinitions.Nametags,
	Pets = ItemDefinitions.Pets,
	Capsules = ItemDefinitions.Capsules,
	Particles = ItemDefinitions.Particles,
}

return map
