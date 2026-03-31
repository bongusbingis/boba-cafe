---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local ReplicaController = require(Packages.ReplicaController)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)

---> globals
local PlayerDataReceivedSignal = GoodSignal.new()

---> controller declaration
local DataController = Knit.CreateController {
	Name = "DataController",
}

function DataController:GetDataAsync()
	return Promise.new(function(resolve)
		resolve(DataController.LocalPlayerData or PlayerDataReceivedSignal:Wait())
	end)
end

function DataController:KnitInit()
	ReplicaController.ReplicaOfClassCreated("PlayerProfile", function(replica)
		DataController.LocalPlayerData = setmetatable(replica.Data, { __index = replica })
		PlayerDataReceivedSignal:Fire(DataController.LocalPlayerData)
	end)
end

return DataController
