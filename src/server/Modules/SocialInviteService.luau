--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local INVITE_REWARD_BOBABUCKS = 50
-- Anti-farm (X10-HARDEN, Jack 2026-10-21): the joiner must be on the inviter's Roblox friends list and have an
-- account at least this many days old.
local MIN_JOINER_ACCOUNT_AGE_DAYS = 7
-- Most invite rewards one inviter can earn per UTC day. DEC-058 agent-set, Jack to tune.
local MAX_INVITE_REWARDS_PER_DAY = 5
local SECONDS_PER_DAY = 86400

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
SocialInviteService.MIN_JOINER_ACCOUNT_AGE_DAYS = MIN_JOINER_ACCOUNT_AGE_DAYS
SocialInviteService.MAX_INVITE_REWARDS_PER_DAY = MAX_INVITE_REWARDS_PER_DAY

--- Current UTC day index. Indirection exists so specs can move the clock.
function SocialInviteService:_getDay(): number
	return os.time() // SECONDS_PER_DAY
end

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

	-- Account age gate (alts are usually fresh accounts).
	if typeof(player.AccountAge) ~= "number" or player.AccountAge < MIN_JOINER_ACCOUNT_AGE_DAYS then
		return
	end

	-- Friends gate. Any error (web call failure) means no reward.
	local friendOk, isFriend = pcall(function()
		return inviter:IsFriendsWith(player.UserId)
	end)
	if not friendOk or isFriend ~= true then
		return
	end

	local dataService = self:_getService("DataService")
	local inviterOk, inviterProfile = dataService:GetDataAsync(inviter):timeout(10):await()
	if not inviterOk or not inviterProfile then
		return
	end
	local joinerOk, joinerProfile = dataService:GetDataAsync(player):timeout(10):await()
	if not joinerOk or not joinerProfile then
		return
	end

	-- No yields from here until the reward is recorded, so concurrent joins cannot double-pay.
	local inviterData = inviterProfile.Data or inviterProfile
	local joinerData = joinerProfile.Data or joinerProfile

	-- One reward per invited UserId ever, across all inviters (recorded on the joiner's profile).
	if typeof(joinerData.InviteRewardedBy) == "number" and joinerData.InviteRewardedBy > 0 then
		return
	end
	local friendKey = tostring(player.UserId)
	if typeof(inviterData.InvitedFriends) == "table" and inviterData.InvitedFriends[friendKey] then
		return
	end

	-- Per-inviter daily cap.
	local today = self:_getDay()
	local daily = inviterData.InviteRewardsToday
	local countToday = if typeof(daily) == "table"
			and daily.Day == today
			and typeof(daily.Count) == "number"
		then daily.Count
		else 0
	if countToday >= MAX_INVITE_REWARDS_PER_DAY then
		return
	end

	joinerProfile:SetValue({ "InviteRewardedBy" }, inviter.UserId)
	if typeof(inviterData.InvitedFriends) ~= "table" then
		inviterProfile:SetValue({ "InvitedFriends" }, {})
	end
	inviterProfile:SetValue({ "InvitedFriends", friendKey }, true)
	inviterProfile:SetValue({ "InviteRewardsToday" }, { Day = today, Count = countToday + 1 })

	local currencyService = self:_getService("CurrencyService")
	currencyService:Modify(inviter, "BobaBucks", INVITE_REWARD_BOBABUCKS, "FriendInvite")

	pcall(function()
		local dialogService = self:_getService("DialogService")
		dialogService:Notify(inviter, "Friend Joined!", "Your friend joined! +50 BobaBucks")
	end)
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
