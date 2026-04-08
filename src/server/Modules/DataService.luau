---> services
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
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
local ProfileObjects: {} = {}
local OnLoadSignals: {} = {}
local PlayerStore = ProfileStore.New(PROFILE_STORE_NAME, PROFILE_TEMPLATE)

if IS_MOCK_STORE_ENABLED then
	PlayerStore = PlayerStore.Mock
end

---> private
local function getPlayerKey(player: Player)
	return `Profile_{player.UserId}`
end

local function getFilterResult(text: string, fromUserId: number)
	local filterResult
	local success, errorMessage = pcall(function()
		filterResult = TextService:FilterStringAsync(text, fromUserId)
	end)

	if success then
		return filterResult
	else
		warn("Error generating TextFilterResult:", errorMessage)
		return nil
	end
end

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", " <font color='#f5c242'>%1</font> ")
		:gsub("%|(.-)%|", " <font color='#fa2545'>%1</font> ")
end

local function createProxyForPlayerProfile(player: Player, playerProfile: any): { [string]: any }
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
				ProfileObjects[player.UserId] = playerProfile
				local proxy = createProxyForPlayerProfile(player, playerProfile)
				local current = os.time()
				playerProfile.Data.Playtime.MostRecentJoin = current
				if playerProfile.Data.Playtime.FirstJoin == 0 and not RunService:IsStudio() then
					playerProfile.Data.Playtime.FirstJoin = current

					local function chooseNicknameRecursive(errorText: string?)
						local baseMessage = "Choose a roleplay nickname."
						local toAppend = errorText or "This cannot be changed later, so choose wisely!"
						Knit.GetService("DialogService"):CreateDialog(player, "TextInputPrompt", {
							Title = "Roleplay Name",
							Text = formatBrackets(`{baseMessage} {toAppend}`),
							PlaceholderText = player.DisplayName,
							CloseText = "Close",
						}):andThen(function(nickname)
							if typeof(nickname) ~= "string" or nickname:gsub(" ", "") == "" then
								chooseNicknameRecursive("|Invalid nickname. Please try again.|")
								return
							end

							if #nickname > 15 then
								chooseNicknameRecursive("|Nickname must be 15 characters or less.|")
								return
							end

							local filterResult = getFilterResult(nickname, player.UserId)
							if filterResult then
								local filteredNickname = filterResult:GetNonChatStringForBroadcastAsync()
								if filteredNickname ~= nickname then
									chooseNicknameRecursive("|Nickname contains filtered content. Please try again.|")
									return
								end
								proxy:SetValue({ "Nickname" }, nickname)
							else
								chooseNicknameRecursive("|An unexpected error occurred. Please try again.|")
								return
							end
						end)
					end

					task.delay(3, chooseNicknameRecursive)
				end
				resolve(proxy)
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
	local profile = ProfileObjects[player.UserId]
	if profile then
		profile:EndSession()
		ProfileObjects[player.UserId] = nil
	end
	Profiles[player.UserId] = nil
end

return DataService
