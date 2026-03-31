--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local ByteNet = require(Packages.ByteNet)

return ByteNet.defineNamespace("Inventory", function()
	return {
		removeItems = ByteNet.definePacket({
			value = ByteNet.struct({
				itemsType = ByteNet.string,
				items = ByteNet.array(ByteNet.string),
			}),
		}),
		setItemEquipped = ByteNet.definePacket({
			value = ByteNet.struct({
				itemId = ByteNet.string,
				itemType = ByteNet.string,
				equipped = ByteNet.bool,
			}),
		}),
		useItem = ByteNet.definePacket({
			value = ByteNet.struct({
				itemId = ByteNet.string,
				itemType = ByteNet.string,
				actionName = ByteNet.string,
			}),
		}),
		onChange = ByteNet.definePacket({
			value = ByteNet.struct({
				action = ByteNet.string,
				itemId = ByteNet.string,
				itemsType = ByteNet.string,
			}),
		}),
	}
end)
