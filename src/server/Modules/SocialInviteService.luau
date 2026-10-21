--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local INVITE_REWARD_BOBABUCKS = 50

local SocialInviteService = Knit.CreateService({
	Name = "SocialInviteService",
	Client = {
		InvitePromptRequested = Knit.CreateSignal(),
		PromptInvite = function(self, player: Player)
			return self.Server:PromptInvite(player)
		end,
	},
})

SocialInviteService.INVITE_REWARD_BOBABUCKS = INVITE_REWARD_BOBABUCKS

--- Resolves another Knit service. Indirection exists so specs can substitute fakes without starting Knit.
function SocialInviteService:_getService(name: string): any
	return Knit.GetService(name)
end

--- Resolves player by UserId. Indirection exists so specs can test without live Players.
function SocialInviteService:_getPlayerByUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

function SocialInviteService:PromptInvite(player: Player): boolean
	self.Client.InvitePromptRequested:Fire(player)
	return true
end

function SocialInviteService:ProcessPlayerJoin(player: Player)
	local followUserId: number? = nil

	if typeof(player.FollowUserId) == "number" and player.FollowUserId > 0 then
		followUserId = player.FollowUserId
	elseif typeof(player.GetJoinData) == "function" then
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		if ok and typeof(joinData) == "table" then
			if typeof(joinData.FollowUserId) == "number" and joinData.FollowUserId > 0 then
				followUserId = joinData.FollowUserId
			elseif
				typeof(joinData.TeleportData) == "table"
				and typeof(joinData.TeleportData.FollowUserId) == "number"
				and joinData.TeleportData.FollowUserId > 0
			then
				followUserId = joinData.TeleportData.FollowUserId
			end
		end
	end

	if not followUserId or followUserId <= 0 then
		return
	end

	local inviter = self:_getPlayerByUserId(followUserId)
	if inviter == nil or inviter == player then
		return
	end

	local dataService = self:_getService("DataService")
	local ok, profile = dataService:GetDataAsync(inviter):timeout(10):await()
	if not ok or not profile then
		return
	end

	local data = profile.Data or profile
	if typeof(data.InvitedFriends) ~= "table" then
		data.InvitedFriends = {}
		if typeof(profile.SetValue) == "function" then
			profile:SetValue({ "InvitedFriends" }, {})
		end
	end

	local friendKey = tostring(player.UserId)
	if not data.InvitedFriends[friendKey] then
		data.InvitedFriends[friendKey] = true
		if typeof(profile.SetValue) == "function" then
			pcall(function()
				profile:SetValue({ "InvitedFriends", friendKey }, true)
			end)
		end

		local currencyService = self:_getService("CurrencyService")
		currencyService:Modify(inviter, "BobaBucks", INVITE_REWARD_BOBABUCKS, "FriendInvite")

		pcall(function()
			local dialogService = self:_getService("DialogService")
			dialogService:Notify(inviter, "Friend Joined!", "Your friend joined! +50 BobaBucks")
		end)
	end
end

function SocialInviteService:PlayerAdded(player: Player)
	task.spawn(function()
		self:ProcessPlayerJoin(player)
	end)
end

function SocialInviteService:KnitStart()
	for _, player in Players:GetPlayers() do
		self:PlayerAdded(player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		self:PlayerAdded(player)
	end)
end

return SocialInviteService
