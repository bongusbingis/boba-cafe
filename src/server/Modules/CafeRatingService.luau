--!strict
--[[
    Module: CafeRatingService
    Description: Server-wide Cafe Rating (0-100) and Rush Hour (REVIVAL-001 M2-RATING, design 5.6).
                 Publishes workspace attributes CafeRating and RushHour; the client reads them.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)
local RatingConfig = require(ReplicatedStorage.Shared.Configuration.RatingConfig)

local CafeRatingService = Knit.CreateService({
	Name = "CafeRatingService",
	Client = {},
	_rating = RatingConfig.START,
	_rush = false,
	_lastRushEnd = nil :: number?,
	_partyActive = false,
	_partyEndTime = nil :: number?,
	_partyCooldownEnd = nil :: number?,
})

--- Pure: clamp(rating + delta / max(1, baristas), 0, 100).
function CafeRatingService.Apply(rating: number, delta: number, baristas: number): number
	return math.clamp(rating + delta / math.max(1, baristas), 0, 100)
end

function CafeRatingService:_baristas(): number
	local shift = Knit.GetService("ShiftService")
	local count = 0
	for _, player in Players:GetPlayers() do
		if shift:IsClockedIn(player) then
			count += 1
		end
	end
	return count
end

function CafeRatingService:_publish()
	workspace:SetAttribute("CafeRating", self._rating)
	workspace:SetAttribute("RushHour", self._rush)
	workspace:SetAttribute("BobaParty", self._partyActive)
end

function CafeRatingService:_notifyAll(text: string)
	local dialog = Knit.GetService("DialogService")
	for _, player in Players:GetPlayers() do
		pcall(function()
			dialog:Notify(player, { Title = "Cafe Rating", Description = text, Text = text } :: any)
		end)
	end
end

function CafeRatingService:_notifyParty(text: string)
	local ok, dialog = pcall(function()
		return Knit.GetService("DialogService")
	end)
	if not ok or not dialog then
		return
	end
	for _, player in Players:GetPlayers() do
		pcall(function()
			dialog:Notify(player, { Title = "Boba Party", Description = text, Text = text } :: any)
		end)
	end
end

function CafeRatingService:StartOrExtendBobaParty(buyer: Player?): (boolean, string?)
	if self._partyActive then
		self._partyEndTime = (self._partyEndTime or os.clock()) + RatingConfig.BOBA_PARTY_EXTENSION_SECONDS
		local text = if buyer
			then `{buyer.Name} extended the Boba Party by 10 minutes!`
			else "Boba Party was extended by 10 minutes!"
		self:_notifyParty(text)
		return true
	end

	self._partyActive = true
	self._partyEndTime = os.clock() + RatingConfig.BOBA_PARTY_SECONDS
	self._partyCooldownEnd = nil
	self._rush = true
	workspace:SetAttribute("RushHour", true)
	workspace:SetAttribute("BobaParty", true)
	self:_publish()

	local text = if buyer
		then `{buyer.Name} started a Boba Party! 10 minutes of Rush Hour!`
		else "Boba Party started! 10 minutes of Rush Hour!"
	self:_notifyParty(text)

	task.spawn(function()
		while self._partyActive do
			local remaining = (self._partyEndTime or 0) - os.clock()
			if remaining <= 0 then
				break
			end
			task.wait(math.clamp(remaining, 0.05, 1))
		end

		if not self._partyActive then
			return
		end

		self._partyActive = false
		self._rush = false
		self._partyEndTime = nil
		workspace:SetAttribute("RushHour", false)
		workspace:SetAttribute("BobaParty", false)
		self._partyCooldownEnd = os.clock() + RatingConfig.BOBA_PARTY_COOLDOWN
		self:_publish()
		self:_notifyParty("Boba Party has ended!")
	end)

	return true
end

function CafeRatingService:_change(delta: number)
	if self._rush then
		return -- the meter is frozen during Rush Hour
	end
	self._rating = CafeRatingService.Apply(self._rating, delta, self:_baristas())
	self:_checkRush()
	self:_publish()
end

function CafeRatingService:_checkRush()
	if self._partyActive or (self._partyCooldownEnd ~= nil and os.clock() < self._partyCooldownEnd) then
		return
	end
	if self._rush or self._rating < 100 then
		return
	end
	local last = self._lastRushEnd
	if last ~= nil and os.clock() - last < RatingConfig.MIN_GAP_SECONDS then
		return -- stays at 100 inside the gap
	end
	self._rush = true
	self:_notifyAll("Rush Hour! More customers and double pay!")
	task.delay(RatingConfig.RUSH_SECONDS, function()
		if self._partyActive then
			return
		end
		self._rush = false
		self._rating = RatingConfig.AFTER_RUSH
		self._lastRushEnd = os.clock()
		self:_publish()
		self:_notifyAll("Rush Hour is over.")
	end)
end

function CafeRatingService:_spillsPresent(): boolean
	local spills = Knit.GetService("SpillService").Spills
	for _, kind in { "Mopping", "Table" } do
		for _, regionSpills in spills[kind] do
			if #regionSpills > 0 then
				return true
			end
		end
	end
	return false
end

function CafeRatingService:KnitStart()
	self:_publish()

	Knit.GetService("CustomerService").CustomerResolved:Connect(function(_player, result)
		local ok, err = pcall(function()
			if result.Kind == "Walkout" then
				self:_change(RatingConfig.WALKOUT)
				return
			end
			local delta = if result.Grade == "Perfect" then RatingConfig.PERFECT else RatingConfig.CLOSE
			if result.Fast then
				delta += RatingConfig.FAST
			end
			self:_change(delta)
		end)
		if not ok then
			warn(`[CafeRatingService] Could not apply a serve: {err}`)
		end
	end)

	Knit.GetService("SpillService").SpillCleanedSignal:Connect(function(spill)
		local ok, err = pcall(function()
			local cleaner = spill.CleanedBy
			if cleaner == nil then
				return -- cleared by the system, not a player
			end
			self:_change(RatingConfig.SPILL_CLEANED)
			Knit.GetService("ProgressionService"):AddXp(cleaner, RatingConfig.SPILL_XP)
		end)
		if not ok then
			warn(`[CafeRatingService] Could not apply a clean: {err}`)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(RatingConfig.DRAIN_SECONDS)
			pcall(function()
				if not self._rush and self:_baristas() > 0 and self:_spillsPresent() then
					self:_change(RatingConfig.SPILL_DRAIN)
				end
			end)
		end
	end)
end

return CafeRatingService
