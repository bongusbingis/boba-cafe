--!strict
--[[
	SeasonPassService
	"Boba Season" Season Pass (SEASON-PASS, 2026-10-23).

	Owns per-season pass state (SeasonId, Xp, Premium, ClaimedTiers),
	Season XP awards from existing play signals, tier claims, premium
	grants (called by the ProcessReceipt action), and synchronous perk
	reads for QuestService/CapsuleService.

	No yield on the serve path: XP hooks are task.spawned from signals.
	Rollover forfeits unclaimed rewards (Jack-confirmed 2026-10-23).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local SeasonConfig = require(Config.SeasonConfig)

local DATA_TIMEOUT_SECONDS = 10

local SeasonPassService = Knit.CreateService({
	Name = "SeasonPassService",
	Client = {
		SeasonPassChanged = Knit.CreateSignal(),
		GetSeasonState = function(self, player: Player)
			return self.Server:GetSeasonState(player)
		end,
		ClaimTier = function(self, player: Player, tierIndex: number)
			return self.Server:ClaimTier(player, tierIndex)
		end,
	},
})

type SeasonState = SeasonConfig.SeasonState

local stateCache: { [number]: SeasonState } = {}
local claimLocks: { [number]: boolean } = {}

function SeasonPassService:_getService(name: string): any
	return Knit.GetService(name)
end

function SeasonPassService:_now(): number
	return os.time()
end

local function cloneState(state: SeasonState): SeasonState
	local copy = table.clone(state)
	copy.ClaimedTiers = table.clone(state.ClaimedTiers)
	return copy
end

local function freshState(seasonId: number): SeasonState
	return {
		SeasonId = seasonId,
		Xp = 0,
		Premium = false,
		ClaimedTiers = {},
	}
end

--- Normalizes the profile's SeasonPass table in place (no yield) and rolls
--- over to the current season when stale. Unclaimed rewards are forfeited.
function SeasonPassService:_ensureState(playerData: any, now: number?): SeasonState
	local current = SeasonConfig.GetCurrentSeasonId(now or self:_now())
	local stored = playerData.SeasonPass
	if typeof(stored) ~= "table" then
		local fresh = freshState(current)
		playerData:SetValue({ "SeasonPass" }, fresh)
		return fresh
	end
	if typeof(stored.SeasonId) ~= "number" or stored.SeasonId ~= current then
		local fresh = freshState(current)
		playerData:SetValue({ "SeasonPass" }, fresh)
		return fresh
	end
	if typeof(stored.Xp) ~= "number" then
		playerData:SetValue({ "SeasonPass", "Xp" }, 0)
		stored.Xp = 0
	end
	if typeof(stored.Premium) ~= "boolean" then
		playerData:SetValue({ "SeasonPass", "Premium" }, false)
		stored.Premium = false
	end
	if typeof(stored.ClaimedTiers) ~= "table" then
		playerData:SetValue({ "SeasonPass", "ClaimedTiers" }, {})
		stored.ClaimedTiers = {}
	end
	return stored :: SeasonState
end

function SeasonPassService:_fireChanged(player: Player)
	pcall(function()
		self.Client.SeasonPassChanged:Fire(player)
	end)
end

function SeasonPassService:_getPlayerData(player: Player): any
	local ok, playerData = self:_getService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if ok and playerData then
		return playerData
	end
	return nil
end

--- Synchronous perk read from the per-player cache. Fails closed (false)
--- when the cache is cold. Active while the perk tier is claimed this season.
function SeasonPassService:HasPerk(player: Player, perk: string): boolean
	local perkTier = SeasonConfig.PERK_TIERS[perk]
	if perkTier == nil then
		return false
	end
	local cached = stateCache[player.UserId]
	if not cached then
		return false
	end
	if cached.Premium ~= true then
		return false
	end
	return cached.ClaimedTiers[perkTier] == true
end

--- Read-only snapshot for the client (state + bundle flag + season clock).
function SeasonPassService:GetSeasonState(player: Player): { [string]: any }
	local playerData = self:_getPlayerData(player)
	if not playerData then
		return { Success = false }
	end
	local state = self:_ensureState(playerData)
	stateCache[player.UserId] = cloneState(state)
	local now = self:_now()
	local seasonId = SeasonConfig.GetCurrentSeasonId(now)
	return {
		Success = true,
		SeasonId = seasonId,
		Xp = state.Xp,
		Premium = state.Premium,
		ClaimedTiers = cloneState(state).ClaimedTiers,
		StarterBundleClaimed = playerData.StarterBundleClaimed == true,
		DaysLeft = if seasonId == 0
			then 0
			else math.max(0, math.ceil((SeasonConfig.GetSeasonEndTimestamp(seasonId) - now) / 86400)),
	}
end

function SeasonPassService:AddSeasonXp(player: Player, amount: number): (boolean, string?)
	if typeof(amount) ~= "number" or amount <= 0 then
		return false, "InvalidAmount"
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if player.Parent ~= Players then
				return
			end
			local playerData = self:_getPlayerData(player)
			if not playerData or player.Parent ~= Players then
				return
			end
			local state = self:_ensureState(playerData)
			local next = state.Xp + amount
			playerData:SetValue({ "SeasonPass", "Xp" }, next)
			state.Xp = next
			stateCache[player.UserId] = cloneState(state)
			self:_fireChanged(player)
		end)
		if not ok then
			warn(`[SeasonPassService] AddSeasonXp failed for {player.Name}: {err}`)
		end
	end)
	return true
end

local function grantCapsuleReward(self, player: Player, capsuleName: string): (boolean, string?)
	local capsuleService = self:_getService("CapsuleService")
	if not capsuleService or not capsuleService.GrantEarnedCapsule then
		return false, "CapsuleServiceUnavailable"
	end
	return capsuleService:GrantEarnedCapsule(player, capsuleName)
end

--- Claims a tier: capsules first (fail = no claim, quest pattern), then the
--- claim marker, then BB / nametag / title. Perk tiers need no grant:
--- HasPerk reads the claimed set. Returns (boolean, reason).
function SeasonPassService:ClaimTier(player: Player, tierIndex: number): (boolean, string?)
	if typeof(tierIndex) ~= "number" or tierIndex ~= math.floor(tierIndex) then
		return false, "InvalidTier"
	end
	if claimLocks[player.UserId] then
		return false, "ClaimInProgress"
	end
	claimLocks[player.UserId] = true

	local ok, success, errReason = pcall(function()
		local playerData = self:_getPlayerData(player)
		if not playerData then
			return false, "DataNotLoaded"
		end
		local state = self:_ensureState(playerData)
		local verdict = SeasonConfig.ValidateClaim(state, tierIndex)
		if verdict ~= "Ok" then
			return false, verdict
		end

		local track = SeasonConfig.TRACK[tierIndex]
		local freeReward = if track then track.Free else nil
		local premiumReward = if track then track.Premium else nil
		local grantsPremium = state.Premium == true and premiumReward ~= nil

		-- Capsules first: a full inventory must not consume the claim.
		if freeReward ~= nil and freeReward.Type == "Capsule" then
			local granted, reason = grantCapsuleReward(self, player, freeReward.Name)
			if not granted then
				return false, reason or "CapsuleGrantFailed"
			end
		end
		if grantsPremium and (premiumReward :: any).Type == "Capsule" then
			local granted, reason = grantCapsuleReward(self, player, (premiumReward :: any).Name)
			if not granted then
				return false, reason or "CapsuleGrantFailed"
			end
		end

		-- Claim marker: true when everything entitled is granted, "Free"
		-- when a premium reward stays retroactive for later purchase.
		if freeReward ~= nil and premiumReward ~= nil and state.Premium ~= true then
			playerData:SetValue({ "SeasonPass", "ClaimedTiers", tierIndex }, "Free")
			state.ClaimedTiers[tierIndex] = "Free" :: any
		else
			playerData:SetValue({ "SeasonPass", "ClaimedTiers", tierIndex }, true)
			state.ClaimedTiers[tierIndex] = true
		end

		local currencyService = self:_getService("CurrencyService")
		local function payBb(amount: number)
			if currencyService and currencyService.Modify then
				currencyService:Modify(player, "BobaBucks", amount, "SeasonPass")
			end
		end
		if freeReward ~= nil and freeReward.Type == "BobaBucks" then
			payBb(freeReward.Amount)
		end
		if grantsPremium and (premiumReward :: any).Type == "BobaBucks" then
			payBb((premiumReward :: any).Amount)
		end

		local function grantNametag(nametagName: string)
			playerData:SetValue({ "Inventory", "Items", "Nametags", HttpService:GenerateGUID(false) }, {
				Name = nametagName,
				Equipped = false,
				Properties = { RandomSource = "SeasonPass" },
			})
		end
		if freeReward ~= nil and freeReward.Type == "Nametag" then
			grantNametag(freeReward.Name)
		end
		if grantsPremium and (premiumReward :: any).Type == "Nametag" then
			grantNametag((premiumReward :: any).Name)
		end

		if grantsPremium and (premiumReward :: any).Type == "Title" then
			local progressionService = self:_getService("ProgressionService")
			if progressionService and progressionService.GrantTitle then
				progressionService:GrantTitle(player, (premiumReward :: any).Id)
			end
		end

		stateCache[player.UserId] = cloneState(state)
		self:_fireChanged(player)
		return true, nil
	end)

	claimLocks[player.UserId] = nil

	if not ok then
		warn(`[SeasonPassService] ClaimTier error for {player.Name}: {success}`)
		return false, tostring(success)
	end
	return success, errReason
end

--- Receipt grant (called by the ProcessReceipt Season Pass action with the
--- loaded profile; sync, no yield). Grants premium for the current season.
function SeasonPassService:GrantPremium(player: Player, playerData: any): boolean
	local state = self:_ensureState(playerData)
	playerData:SetValue({ "SeasonPass", "Premium" }, true)
	state.Premium = true
	stateCache[player.UserId] = cloneState(state)
	task.spawn(function()
		self:_fireChanged(player)
	end)
	return true
end

function SeasonPassService:PlayerAdded(player: Player)
	task.spawn(function()
		local ok, err = pcall(function()
			local playerData = self:_getPlayerData(player)
			if not playerData or player.Parent ~= Players then
				return
			end
			local state = self:_ensureState(playerData)
			stateCache[player.UserId] = cloneState(state)
		end)
		if not ok then
			warn(`[SeasonPassService] PlayerAdded failed for {player.Name}: {err}`)
		end
	end)
end

function SeasonPassService:PlayerRemoving(player: Player)
	stateCache[player.UserId] = nil
	claimLocks[player.UserId] = nil
end

function SeasonPassService:KnitStart()
	local customerService = self:_getService("CustomerService")
	if customerService and customerService.CustomerResolved then
		customerService.CustomerResolved:Connect(function(player, result)
			task.spawn(function()
				local ok, err = pcall(function()
					if player == nil or player.Parent ~= Players then
						return
					end
					if typeof(result) == "table" and result.Kind == "Served" then
						self:AddSeasonXp(player, SeasonConfig.XP_SERVE)
					end
				end)
				if not ok then
					warn(`[SeasonPassService] Serve XP hook failed: {err}`)
				end
			end)
		end)
	else
		warn("[SeasonPassService] CustomerService.CustomerResolved missing; serve XP disabled")
	end

	local shiftService = self:_getService("ShiftService")
	if shiftService and shiftService.ShiftEnding then
		shiftService.ShiftEnding:Connect(function(player, _summary)
			task.spawn(function()
				local ok, err = pcall(function()
					if player == nil or player.Parent ~= Players then
						return
					end
					self:AddSeasonXp(player, SeasonConfig.XP_SHIFT)
				end)
				if not ok then
					warn(`[SeasonPassService] Shift XP hook failed: {err}`)
				end
			end)
		end)
	else
		warn("[SeasonPassService] ShiftService.ShiftEnding missing; shift XP disabled")
	end

	local spillService = self:_getService("SpillService")
	if spillService and spillService.SpillCleanedSignal then
		spillService.SpillCleanedSignal:Connect(function(spill)
			task.spawn(function()
				local ok, err = pcall(function()
					local cleaner = if typeof(spill) == "table" then (spill :: any).CleanedBy else nil
					if typeof(cleaner) ~= "Instance" then
						return
					end
					local cleanOk, isPlayer = pcall(function()
						return (cleaner :: any):IsA("Player")
					end)
					if not cleanOk or not isPlayer then
						return
					end
					if (cleaner :: any).Parent ~= Players then
						return
					end
					self:AddSeasonXp(cleaner, SeasonConfig.XP_SPILL)
				end)
				if not ok then
					warn(`[SeasonPassService] Spill XP hook failed: {err}`)
				end
			end)
		end)
	else
		warn("[SeasonPassService] SpillService.SpillCleanedSignal missing; spill XP disabled")
	end

	local questService = self:_getService("QuestService")
	if questService and questService.QuestClaimed then
		questService.QuestClaimed:Connect(function(player, _questIndex)
			task.spawn(function()
				local ok, err = pcall(function()
					if player == nil or player.Parent ~= Players then
						return
					end
					self:AddSeasonXp(player, SeasonConfig.XP_QUEST)
				end)
				if not ok then
					warn(`[SeasonPassService] Quest XP hook failed: {err}`)
				end
			end)
		end)
	else
		warn("[SeasonPassService] QuestService.QuestClaimed missing; quest XP disabled")
	end
end

return SeasonPassService
