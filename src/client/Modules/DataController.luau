---> module declaration
local Controller = {}

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local ReplicaController = require(Packages.ReplicaController)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)

---> globals

local PlayerDataReceivedSignal = GoodSignal.new()

function Controller:GetDataAsync()
	return Promise.new(function(Resolve)
		Resolve((Controller.LocalPlayerData) or PlayerDataReceivedSignal:Wait())
	end)
end

function Controller:Init()
	ReplicaController.ReplicaOfClassCreated("PlayerProfile", function(Replica)
		Controller.LocalPlayerData = setmetatable(Replica.Data, {__index = Replica})
		PlayerDataReceivedSignal:Fire(Controller.LocalPlayerData)
	end)
end

return Controller