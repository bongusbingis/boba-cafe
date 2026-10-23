---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local ReplicaController = require(Packages.ReplicaController)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)
local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared").Configuration.SettingsConfig)

---> globals
local PlayerDataReceivedSignal = GoodSignal.new()

-- Applies saved toggles that have a client effect (audio volumes). The callbacks
-- skip audio groups the place does not author, so this never blocks or errors.
local function applyClientSettings(settings: { [string]: any })
	for _, category in SettingsConfig do
		for _, setting in category.Settings do
			local callback: any = setting.ClientCallback
			if setting.Type ~= "Action" and callback then
				callback(settings[setting.Key] == true)
			end
		end
	end
end

---> controller declaration
local DataController = Knit.CreateController({
	Name = "DataController",
})

function DataController:GetDataAsync()
	return Promise.new(function(resolve)
		resolve(DataController.LocalPlayerData or PlayerDataReceivedSignal:Wait())
	end)
end

function DataController:KnitInit()
	ReplicaController.ReplicaOfClassCreated("PlayerProfile", function(replica)
		DataController.LocalPlayerData = setmetatable(replica.Data, { __index = replica })
		PlayerDataReceivedSignal:Fire(DataController.LocalPlayerData)
		applyClientSettings(replica.Data.Settings or {})
	end)
end

return DataController
