---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local ProfileStore = require(Packages.Server.ProfileStore)
local ReplicaService = require(Packages.ReplicaService)
local GoodSignal = require(Packages.GoodSignal)
local Promise = require(Packages.Promise)

---> constants
local IS_MOCK_STORE_ENABLED = true
local PROFILE_STORE_NAME = "PlayerStore_0001"
local REPLICA_CLASS_TOKEN = ReplicaService.NewClassToken("PlayerProfile")
local PROFILE_TEMPLATE = require(Config:WaitForChild("ProfileTemplate"))

---> types
export type PlayerData = PROFILE_TEMPLATE.ProfileTemplate
type ProfileProxy = {
	Player: Player,
	Profile: {},
	Replica: {
		[string]: any,
	},
}

---> globals
local Profiles: {} = {}
local OnLoadSignals: {} = {}
local PlayerStore = ProfileStore.New(PROFILE_STORE_NAME, PROFILE_TEMPLATE)

if IS_MOCK_STORE_ENABLED then
	PlayerStore = PlayerStore.Mock
end

---> private
local function getPlayerKey(player: Player)
	return `Profile_{player.UserId}`
end

local function createProxyForPlayerProfile(player: Player, playerProfile): { [string]: any }
	return setmetatable(playerProfile.Data, {
		__index = ReplicaService.NewReplica({
			ClassToken = REPLICA_CLASS_TOKEN,
			Tags = { Player = player },
			Data = playerProfile.Data,
			Replication = player,
		}),
	})
end

local function loadPlayerProfile(player: Player)
	return Promise.new(function(resolve, reject)
		local playerProfile = PlayerStore:StartSessionAsync(getPlayerKey(player), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if playerProfile ~= nil then
			playerProfile:AddUserId(player.UserId)
			playerProfile:Reconcile()
			playerProfile.OnSessionEnd:Connect(function()
				Profiles[player.UserId] = nil
				player:Kick("Your player profile session was ended - please try rejoining.")
			end)

			if player.Parent == Players then
				local current = os.time()
				playerProfile.Data.Playtime.MostRecentJoin = current
				if playerProfile.Data.Playtime.FirstJoin == 0 then
					playerProfile.Data.Playtime.FirstJoin = current
				end
				resolve(createProxyForPlayerProfile(player, playerProfile))
			else
				playerProfile:EndSession()
			end
		else
			reject("player profile is nil")
		end
	end)
end

local function playerAdded(player: Player)
	loadPlayerProfile(player)
		:andThen(function(playerProfile)
			if RunService:IsStudio() then
				print(script.Name, `[STUDIO] Profile loaded for player`, player.UserId)
			end
			Profiles[player.UserId] = playerProfile
			if OnLoadSignals[player.UserId] then
				OnLoadSignals[player.UserId]:Fire(playerProfile)
				OnLoadSignals[player.UserId]:DisconnectAll()
				OnLoadSignals[player.UserId] = nil
			end
		end)
		:catch(function(failReason)
			warn(script.Name, `Failed to load data for {player.UserId}:`, failReason)
			failReason = if typeof(failReason) == "string"
				then `Profile load failed because: {failReason}.`
				else "Your player data couldn't be loaded."
			player:Kick(failReason .. " Please try again.")
		end)
end

---> service declaration
local DataService = Knit.CreateService {
	Name = "DataService",
	Client = {},
}

function DataService:GetDataAsync(player: Player)
	return Promise.new(function(resolve)
		local playerData = Profiles[player.UserId]
		if not playerData then
			if not OnLoadSignals[player.UserId] then
				OnLoadSignals[player.UserId] = GoodSignal.new()
			end
			playerData = OnLoadSignals[player.UserId]:Wait()
		end
		resolve(playerData)
	end)
end

function DataService:PlayerAdded(player: Player)
	playerAdded(player)
end

function DataService:PlayerRemoving(player: Player)
	Profiles[player.UserId] = nil
end

return DataService
