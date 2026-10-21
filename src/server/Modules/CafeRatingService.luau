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
	_rushEndsAt = nil :: number?,
	_lastRushEnd = nil :: number?,
	_partyActive = false,
	_partyEndTime = nil :: number?,
	_partyCooldownEnd = nil :: number?,
	_partyBuyer = nil :: string?,
})

--- D5: DisplayName when it is a non-empty string, else Name when a string, else nil.
local function buyerName(buyer: Player?): string?
	if buyer == nil then
		return nil
	end
	local display = (buyer :: any).DisplayName
	if typeof(display) == "string" and display ~= "" then
		return display
	end
	local name = (buyer :: any).Name
	if typeof(name) == "string" then
		return name
	end
	return nil
end

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
	workspace:SetAttribute("RushEndsAt", self._rushEndsAt)
	workspace:SetAttribute("BobaPartyBuyer", self._partyBuyer)
end

function CafeRatingService:_notifyAll(text: string)
	local ok, dialog = pcall(function()
		return Knit.GetService("DialogService")
	end)
	if not ok or not dialog then
		return
	end
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

--- D6: one thank-you toast to every player except the buyer, on start and each extension.
function CafeRatingService:_promptThanks(buyer: Player?, name: string)
	local ok, dialog = pcall(function()
		return Knit.GetService("DialogService")
	end)
	if not ok or not dialog then
		return
	end
	local text = `Thank {name} with an emote!`
	for _, player in Players:GetPlayers() do
		if player ~= buyer then
			pcall(function()
				dialog:Notify(player, { Title = "Boba Party", Description = text, Text = text } :: any)
			end)
		end
	end
end

function CafeRatingService:StartOrExtendBobaParty(buyer: Player?): (boolean, string?)
	if self._partyActive then
		self._partyEndTime = (self._partyEndTime or os.clock()) + RatingConfig.BOBA_PARTY_EXTENSION_SECONDS
		self._rushEndsAt = workspace:GetServerTimeNow() + (self._partyEndTime - os.clock())
		if buyer ~= nil then
			local extender = buyerName(buyer)
			if extender ~= nil then
				self._partyBuyer = extender
			end
		end
		self:_publish()
		local extenderName = buyerName(buyer) or "Someone"
		local text = if buyer
			then `{extenderName} extended the Boba Party by 10 minutes!`
			else "Boba Party was extended by 10 minutes!"
		self:_notifyParty(text)
		local thanks = buyerName(buyer)
		if thanks ~= nil then
			self:_promptThanks(buyer, thanks)
		end
		return true
	end

	-- A receipt that arrives during the cooldown is still granted (Jack, 2026-10-19); the purchase
	-- prompt hides itself while BobaPartyCooldownEndsAt (server time) is in the future.
	self._partyActive = true
	self._partyEndTime = os.clock() + RatingConfig.BOBA_PARTY_SECONDS
	self._partyCooldownEnd = nil
	workspace:SetAttribute("BobaPartyCooldownEndsAt", nil)
	self._rush = true
	self._rushEndsAt = workspace:GetServerTimeNow() + RatingConfig.BOBA_PARTY_SECONDS
	self._partyBuyer = buyerName(buyer)
	workspace:SetAttribute("RushHour", true)
	workspace:SetAttribute("BobaParty", true)
	self:_publish()

	local starterName = buyerName(buyer) or "Someone"
	local text = if buyer
		then `{starterName} started a Boba Party! 10 minutes of Rush Hour!`
		else "Boba Party started! 10 minutes of Rush Hour!"
	self:_notifyParty(text)
	local thanks = buyerName(buyer)
	if thanks ~= nil then
		self:_promptThanks(buyer, thanks)
	end

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
		self._rushEndsAt = nil
		self._partyBuyer = nil
		self._partyEndTime = nil
		workspace:SetAttribute("RushHour", false)
		workspace:SetAttribute("BobaParty", false)
		self._partyCooldownEnd = os.clock() + RatingConfig.BOBA_PARTY_COOLDOWN
		workspace:SetAttribute(
			"BobaPartyCooldownEndsAt",
			workspace:GetServerTimeNow() + RatingConfig.BOBA_PARTY_COOLDOWN
		)
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
	self._rushEndsAt = workspace:GetServerTimeNow() + RatingConfig.RUSH_SECONDS
	self:_notifyAll("Rush Hour! More customers and double pay!")
	task.delay(RatingConfig.RUSH_SECONDS, function()
		if self._partyActive then
			return
		end
		self._rush = false
		self._rushEndsAt = nil
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
