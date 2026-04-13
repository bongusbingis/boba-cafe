---> services
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local ReplicaController = require(Packages.ReplicaController)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)

local SFX: SoundGroup = SoundService:WaitForChild("SFX")
local Music: SoundGroup = SoundService:WaitForChild("Music")

---> globals
local PlayerDataReceivedSignal = GoodSignal.new()

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
		print("Local player data received:", replica.Data)
		DataController.LocalPlayerData = setmetatable(replica.Data, { __index = replica })
		PlayerDataReceivedSignal:Fire(DataController.LocalPlayerData)
		SFX.Volume = if replica.Data.Settings.SFXEnabled then 0.5 else 0
		Music.Volume = if replica.Data.Settings.MusicEnabled then 0.5 else 0
	end)
end

return DataController
