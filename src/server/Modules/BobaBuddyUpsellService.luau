--!strict
--[[
	BobaBuddyUpsellService
	Server service managing the first-pain onboarding upsell modal for
	Boba Buddy consumables (Cleaner & Stocker).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local BobaBuddyConfig = require(Shared.Configuration.BobaBuddyConfig)
local UIFlags = require(Shared.Configuration.UIFlags)
local Styles = require(Shared.UI.Styles)

local BobaBuddyUpsellService = Knit.CreateService({
	Name = "BobaBuddyUpsellService",
	Client = {
		OpenShopRequested = Knit.CreateSignal(), -- (tab: string, highlightKey: string)
	},
	_lastUpsellTime = {} :: { [Player]: number },
	_shownTime = {} :: { [Player]: { [string]: number } },
	_sessionPurchased = {} :: { [Player]: { [string]: boolean } },
	_choreCounts = {} :: { [Player]: { [string]: number } },
})

function BobaBuddyUpsellService:KnitStart()
	local spillService = Knit.GetService("SpillService")
	local kitchenService = Knit.GetService("KitchenService")

	-- Listen for spills cleaned by a player (Cleaner trigger)
	if spillService and spillService.SpillCleanedSignal then
		spillService.SpillCleanedSignal:Connect(function(spill: any)
			local player = spill and spill.CleanedBy
			if player and player:IsA("Player") then
				self:OnChoreCompleted(player, "Cleaner")
			end
		end)
	end

	-- Listen for stations restocked by a player (Stocker trigger)
	if
		kitchenService
		and (kitchenService :: any).StationRestocked
		and typeof((kitchenService :: any).StationRestocked.Connect) == "function"
	then
		(kitchenService :: any).StationRestocked:Connect(function(player: Player, _model: Model)
			if player and player:IsA("Player") then
				self:OnChoreCompleted(player, "Stocker")
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		self._lastUpsellTime[player] = nil
		self._shownTime[player] = nil
		self._sessionPurchased[player] = nil
		self._choreCounts[player] = nil
	end)
end

function BobaBuddyUpsellService:OnProductPurchased(player: Player, chore: string)
	if not self._sessionPurchased[player] then
		self._sessionPurchased[player] = {}
	end
	self._sessionPurchased[player][chore] = true

	-- Attribution: purchase within 5 minutes of upsell modal
	local shownTimes = self._shownTime[player]
	if shownTimes and shownTimes[chore] then
		local elapsed = os.clock() - shownTimes[chore]
		if elapsed <= BobaBuddyConfig.UPSELL.ConversionWindowSeconds then
			pcall(function()
				local analytics = Knit.GetService("AnalyticsEvents")
				if analytics and analytics.Custom then
					analytics:Custom(player, "BobaBuddyUpsellConverted", 1)
				end
			end)
		end
	end
end

function BobaBuddyUpsellService:OnChoreCompleted(player: Player, chore: "Cleaner" | "Stocker")
	if not UIFlags.BobaBuddyUpsellEnabled then
		return
	end

	if not self._choreCounts[player] then
		self._choreCounts[player] = {}
	end
	local count = (self._choreCounts[player][chore] or 0) + 1
	self._choreCounts[player][chore] = count

	if count < BobaBuddyConfig.UPSELL.TriggerCount then
		return
	end

	-- Delay before showing upsell so player doesn't feel interrupted mid-momentum
	task.delay(BobaBuddyConfig.UPSELL.DelaySeconds, function()
		if not player or not player.Parent then
			return
		end
		self:_tryShowUpsell(player, chore)
	end)
end

function BobaBuddyUpsellService:_tryShowUpsell(player: Player, chore: "Cleaner" | "Stocker")
	if not UIFlags.BobaBuddyUpsellEnabled then
		return
	end

	-- Check session purchases
	if self._sessionPurchased[player] and self._sessionPurchased[player][chore] then
		return
	end

	-- Check perk (if already owns permanent floor cleaner pass)
	if chore == "Cleaner" then
		local okPerk, perkService = pcall(function()
			return Knit.GetService("PerkService")
		end)
		if okPerk and perkService and perkService.HasPerk and perkService:HasPerk(player, "BobaBuddyFloor") then
			return
		end
	end

	-- Suppression window (don't show if any upsell fired in last 60 seconds)
	local lastTime = self._lastUpsellTime[player]
	if lastTime and os.clock() - lastTime < BobaBuddyConfig.UPSELL.SuppressWindowSeconds then
		return
	end

	-- Check profile flag
	local dataService = Knit.GetService("DataService")
	if not dataService then
		return
	end

	local profile = (dataService :: any):GetDataAsync(player)
	if not profile or not profile.UpsellsSeen or profile.UpsellsSeen[chore] == true then
		return
	end

	-- Player holding kitchen tool check
	local char = player.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool and tool:GetAttribute("IsKitchenTool") == true then
			return
		end
	end

	local dialogService = Knit.GetService("DialogService")
	if not dialogService then
		return
	end

	self._lastUpsellTime[player] = os.clock()
	if not self._shownTime[player] then
		self._shownTime[player] = {}
	end
	self._shownTime[player][chore] = os.clock()

	-- Inline analytics
	pcall(function()
		local analytics = Knit.GetService("AnalyticsEvents")
		if analytics and analytics.Custom then
			analytics:Custom(player, "BobaBuddyUpsellShown", 1)
		end
	end)

	local title = if chore == "Cleaner"
		then BobaBuddyConfig.UPSELL.CleanerTitle
		else BobaBuddyConfig.UPSELL.StockerTitle
	local text = if chore == "Cleaner" then BobaBuddyConfig.UPSELL.CleanerText else BobaBuddyConfig.UPSELL.StockerText

	local promise = dialogService:CreateDialog(player, "ButtonPrompt", {
		Title = title,
		Text = text,
		Buttons = {
			{ Text = BobaBuddyConfig.UPSELL.ButtonSee, Color = Styles.GREEN },
			{ Text = BobaBuddyConfig.UPSELL.ButtonDismiss, Color = Styles.CORAL },
		},
	})

	promise:andThen(function(choice: string?)
		-- Mark as seen forever in profile
		pcall(function()
			profile:SetValue({ "UpsellsSeen", chore }, true)
		end)

		if choice == BobaBuddyConfig.UPSELL.ButtonSee then
			pcall(function()
				local analytics = Knit.GetService("AnalyticsEvents")
				if analytics and analytics.Custom then
					analytics:Custom(player, "BobaBuddyUpsellClicked", 1)
				end
			end)
			self.Client.OpenShopRequested:Fire(player, "Products", "BobaBuddy")
		else
			pcall(function()
				local analytics = Knit.GetService("AnalyticsEvents")
				if analytics and analytics.Custom then
					analytics:Custom(player, "BobaBuddyUpsellDismissed", 1)
				end
			end)
		end
	end)
end

return BobaBuddyUpsellService
