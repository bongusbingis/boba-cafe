--!strict
--[[
	InstantBrewUpsellService.luau
	Server service managing the first non-onboarding order upsell modal for
	the Instant Brewing gamepass (12385760).
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local InstantBrewConfig = require(Shared.Configuration.InstantBrewConfig)
local UIFlags = require(Shared.Configuration.UIFlags)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local Styles = require(Shared.UI.Styles)

local InstantBrewUpsellService = Knit.CreateService({
	Name = "InstantBrewUpsellService",
	Client = {},
	_lastUpsellTime = {} :: { [Player]: number },
	_shownTime = {} :: { [Player]: number },
	_sessionPurchased = {} :: { [Player]: boolean },
})

function InstantBrewUpsellService:KnitStart()
	local customerService = Knit.GetService("CustomerService")
	if customerService and customerService.CustomerResolved then
		customerService.CustomerResolved:Connect(function(player: Player?, result: any)
			if player and player:IsA("Player") and typeof(result) == "table" and result.Kind == "Served" then
				self:OnOrderServed(player, result)
			end
		end)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if wasPurchased and passId == InstantBrewConfig.PASS_ID then
				self:OnPassPurchased(player)
			end
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		self._lastUpsellTime[player] = nil
		self._shownTime[player] = nil
		self._sessionPurchased[player] = nil
	end)
end

function InstantBrewUpsellService:OnPassPurchased(player: Player)
	self._sessionPurchased[player] = true

	-- Attribution: purchase within conversion window of upsell modal
	local shownTime = self._shownTime[player]
	if shownTime then
		local elapsed = os.clock() - shownTime
		if elapsed <= InstantBrewConfig.UPSELL.ConversionWindowSeconds then
			pcall(function()
				local analytics = Knit.GetService("AnalyticsEvents")
				if analytics and analytics.Custom then
					analytics:Custom(player, "InstantBrewUpsellConverted", 1)
				end
			end)
		end
	end
end

function InstantBrewUpsellService:OnOrderServed(player: Player, result: any)
	if not UIFlags.InstantBrewUpsellEnabled then
		return
	end

	-- Skip onboarding / scripted orders
	if result.Scripted == true then
		return
	end

	-- Verify player has completed first session onboarding count
	local dataService = Knit.GetService("DataService")
	if dataService then
		local profile = (dataService :: any):GetDataAsync(player)
		if profile and profile.Statistics then
			local served = profile.Statistics.CustomersServed or 0
			if served < CustomerConfig.FIRST_SESSION_COUNT then
				return
			end
		end
	end

	-- Check session purchases
	if self._sessionPurchased[player] then
		return
	end

	-- Delay before showing upsell so player doesn't feel interrupted mid-momentum
	task.delay(InstantBrewConfig.UPSELL.DelaySeconds, function()
		if not player or not player.Parent then
			return
		end
		self:_tryShowUpsell(player)
	end)
end

function InstantBrewUpsellService:_tryShowUpsell(player: Player)
	if not UIFlags.InstantBrewUpsellEnabled then
		return
	end

	-- 1. Check session purchases
	if self._sessionPurchased[player] then
		return
	end

	-- 2. Check if player already owns the pass or perk
	local perkService = Knit.GetService("PerkService")
	if
		perkService
		and typeof(perkService.HasPerk) == "function"
		and perkService:HasPerk(player, InstantBrewConfig.PERK_NAME)
	then
		return
	end

	local okOwns, owns = pcall(function()
		return (GamepassUtil :: any):PlayerOwnsPassAsync(player, InstantBrewConfig.PASS_ID)
	end)
	if okOwns and owns == true then
		return
	end

	-- 3. Suppression window (don't show if any upsell/dialog fired recently)
	local now = os.clock()
	local lastTime = self._lastUpsellTime[player]
	if lastTime and (now - lastTime) < InstantBrewConfig.UPSELL.SuppressWindowSeconds then
		return
	end
	local attrLast = player:GetAttribute("LastUpsellTime")
	if typeof(attrLast) == "number" and (now - attrLast) < InstantBrewConfig.UPSELL.SuppressWindowSeconds then
		return
	end

	-- 4. Check profile flag (marked seen forever in ProfileStore)
	local dataService = Knit.GetService("DataService")
	if not dataService then
		return
	end

	local profile = (dataService :: any):GetDataAsync(player)
	if not profile or not profile.UpsellsSeen or profile.UpsellsSeen.InstantBrew == true then
		return
	end

	-- 5. Don't interrupt if player is holding a kitchen tool
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

	self._lastUpsellTime[player] = now
	self._shownTime[player] = now
	player:SetAttribute("LastUpsellTime", now)

	-- Inline analytics
	pcall(function()
		local analytics = Knit.GetService("AnalyticsEvents")
		if analytics and analytics.Custom then
			analytics:Custom(player, "InstantBrewUpsellShown", 1)
		end
	end)

	local promise = dialogService:CreateDialog(player, "ButtonPrompt", {
		Title = InstantBrewConfig.UPSELL.Title,
		Text = InstantBrewConfig.UPSELL.Text,
		Buttons = {
			{ Text = InstantBrewConfig.UPSELL.ButtonBuy, Color = Styles.GREEN },
			{ Text = InstantBrewConfig.UPSELL.ButtonDismiss, Color = Styles.CORAL },
		},
	})

	promise:andThen(function(choice: string?)
		-- Mark as seen forever in profile
		pcall(function()
			profile:SetValue({ "UpsellsSeen", "InstantBrew" }, true)
		end)

		if choice == InstantBrewConfig.UPSELL.ButtonBuy then
			pcall(function()
				local analytics = Knit.GetService("AnalyticsEvents")
				if analytics and analytics.Custom then
					analytics:Custom(player, "InstantBrewUpsellClicked", 1)
				end
			end)

			-- Direct purchase path: prompt Roblox gamepass purchase dialog
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, InstantBrewConfig.PASS_ID)
			end)
		else
			pcall(function()
				local analytics = Knit.GetService("AnalyticsEvents")
				if analytics and analytics.Custom then
					analytics:Custom(player, "InstantBrewUpsellDismissed", 1)
				end
			end)
		end
	end)
end

return InstantBrewUpsellService
