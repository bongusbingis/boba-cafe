--!nonstrict
--[[
	PassUpsell (UPSELL lane 2)
	Shared bits for the soft pass-upsell rows: live Robux price, ownership, the
	click-only purchase prompt, the show caps, and the small row component.

	Hard rules (Jack): a purchase prompt only ever opens from a button the player
	clicked; nothing auto-opens or interrupts play; owners never see an offer; prices
	are always live (MarketplaceService:GetProductInfoAsync, DEC-026), never
	hardcoded. If the price cannot be fetched the offer is simply not shown.

	Ownership is perk-based: a player already has a pass's benefit when the passes they
	own in Configuration/PassCatalog (the pass itself or any legacy pass, e.g. Senior
	Barista for Barista) together grant all of its perks. GamepassUtil resolves every
	id in the unified catalog; anything it does not know falls back to a direct
	MarketplaceService:UserOwnsGamePassAsync check (cached per id). A pass bought this
	session is remembered here because the caches hold the earlier "false".
]]

---> Services

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)

local GamepassUtil = require(Shared.Utility.GamepassUtil)
local PassCatalog = require(Shared.Configuration.PassCatalog)
local Styles = require(UI.Styles)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local usePx = require(UI.Hooks.usePx)

---> Private

local c = React.createElement

local PassUpsell = {}

PassUpsell.BARISTA = 6202153
PassUpsell.KITCHEN_LEADER = 15243046
PassUpsell.VIP = 12385781

-- Boost percent shown for each XP/tip pass (mirrors Perks.luau: Barista 25, Kitchen Leader 50).
PassUpsell.BOOST_PERCENT = {
	[PassUpsell.BARISTA] = 25,
	[PassUpsell.KITCHEN_LEADER] = 50,
}

-- Stable lists for useOwned (the hook's effect depends on list identity).
PassUpsell.XP_PASS_IDS = { PassUpsell.BARISTA, PassUpsell.KITCHEN_LEADER }

-- Cap rules. Paycheck: from the 2nd completed shift, then every 3rd (2, 5, 8 ...).
-- Level-up: every 3rd level (3, 6, 9 ...).
PassUpsell.PAYCHECK_FIRST_SHIFT = 2
PassUpsell.PAYCHECK_EVERY = 3
PassUpsell.LEVELUP_EVERY = 3

local priceCache: { [number]: number } = {}
local purchasedThisSession: { [number]: boolean } = {}
local directOwnCache: { [number]: boolean } = {}
local purchaseListeners: { [number]: (passId: number) -> () } = {}
local nextListenerId = 0
local finishedConnected = false

local function connectFinished()
	if finishedConnected or not RunService:IsClient() or not RunService:IsRunning() then
		return
	end
	finishedConnected = true
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if player ~= Players.LocalPlayer or not wasPurchased then
				return
			end
			purchasedThisSession[passId] = true
			for _, listener in purchaseListeners do
				task.spawn(listener, passId)
			end
		end
	)
end

---> Pure rules (unit tested)

function PassUpsell.ShouldShowOnPaycheck(shift: any): boolean
	if typeof(shift) ~= "number" or shift < PassUpsell.PAYCHECK_FIRST_SHIFT then
		return false
	end
	return (shift - PassUpsell.PAYCHECK_FIRST_SHIFT) % PassUpsell.PAYCHECK_EVERY == 0
end

function PassUpsell.ShouldShowOnLevelUp(level: any): boolean
	if typeof(level) ~= "number" or level < PassUpsell.LEVELUP_EVERY then
		return false
	end
	return level % PassUpsell.LEVELUP_EVERY == 0
end

-- owned: passId -> boolean, an absent key means "not resolved yet" (no offer).
-- Barista owner is offered Kitchen Leader; a Kitchen Leader owner is offered nothing.
function PassUpsell.PickPaycheckOffer(owned: { [number]: boolean }): number?
	local barista = owned[PassUpsell.BARISTA]
	local leader = owned[PassUpsell.KITCHEN_LEADER]
	if barista == nil or leader == nil or leader then
		return nil
	end
	if barista then
		return PassUpsell.KITCHEN_LEADER
	end
	return PassUpsell.BARISTA
end

-- Level-up only offers when the player owns no XP pass.
function PassUpsell.PickLevelUpOffer(owned: { [number]: boolean }): number?
	local barista = owned[PassUpsell.BARISTA]
	local leader = owned[PassUpsell.KITCHEN_LEADER]
	if barista == nil or leader == nil or barista or leader then
		return nil
	end
	return PassUpsell.BARISTA
end

function PassUpsell.PriceText(price: number): string
	return `\u{e002} {price}`
end

---> Runtime

-- Opens the Roblox purchase prompt. Call only from a click handler.
function PassUpsell.Prompt(passId: number)
	if not RunService:IsRunning() or not RunService:IsClient() then
		return
	end
	connectFinished()
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return
	end
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(localPlayer, passId)
	end)
end

-- Yields. True when the local player owns this exact pass id (cached; a failed
-- lookup is treated as not owned and not cached).
local function ownsIdAsync(localPlayer: Player, passId: number): boolean
	if purchasedThisSession[passId] then
		return true
	end
	if directOwnCache[passId] ~= nil then
		return directOwnCache[passId]
	end
	if GamepassUtil.Gamepasses[passId] ~= nil and GamepassUtil:PlayerOwnsPassAsync(localPlayer, passId) then
		directOwnCache[passId] = true
		return true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, passId)
	end)
	if not ok then
		return false
	end
	directOwnCache[passId] = owns == true
	return owns == true
end

-- Pure: catalog ids (other than passId) that share at least one perk with it.
function PassUpsell.GetPerkSiblings(passId: number): { number }
	local entry = PassCatalog[passId]
	local siblings = {}
	if entry == nil then
		return siblings
	end
	for otherId, other in PassCatalog do
		if otherId ~= passId then
			for _, perk in other.Perks do
				if table.find(entry.Perks, perk) then
					table.insert(siblings, otherId)
					break
				end
			end
		end
	end
	return siblings
end

-- Pure: true when every perk of passId is granted by some owned catalog pass.
-- owned: passId -> boolean for the pass and its siblings.
function PassUpsell.HasPerks(passId: number, owned: { [number]: boolean }): boolean
	local entry = PassCatalog[passId]
	if entry == nil then
		return owned[passId] == true
	end
	if owned[passId] then
		return true
	end
	for _, perk in entry.Perks do
		local covered = false
		for ownedId, isOwned in owned do
			local other = PassCatalog[ownedId]
			if isOwned and other ~= nil and table.find(other.Perks, perk) then
				covered = true
				break
			end
		end
		if not covered then
			return false
		end
	end
	return true
end

-- Yields. True when the player already gets this pass's perks from it or from any
-- owned catalog pass that grants the same perks (legacy passes included).
function PassUpsell.OwnsAsync(passId: number): boolean
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return purchasedThisSession[passId] == true
	end
	local owned = { [passId] = ownsIdAsync(localPlayer, passId) }
	if owned[passId] then
		return true
	end
	for _, siblingId in PassUpsell.GetPerkSiblings(passId) do
		owned[siblingId] = ownsIdAsync(localPlayer, siblingId)
	end
	return PassUpsell.HasPerks(passId, owned)
end

-- Yields. Live price in Robux, or nil when it cannot be read or the pass is off sale.
function PassUpsell.FetchPriceAsync(passId: number): number?
	if priceCache[passId] ~= nil then
		return priceCache[passId]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(passId, Enum.InfoType.GamePass)
	end)
	if not ok or typeof(info) ~= "table" or info.IsForSale == false then
		return nil
	end
	local price = info.PriceInRobux
	if typeof(price) ~= "number" or price <= 0 then
		return nil
	end
	priceCache[passId] = price
	return price
end

-- Calls fn(passId) when the local player buys a pass. Returns a disconnect function.
function PassUpsell.OnPurchased(fn: (passId: number) -> ()): () -> ()
	connectFinished()
	nextListenerId += 1
	local id = nextListenerId
	purchaseListeners[id] = fn
	return function()
		purchaseListeners[id] = nil
	end
end

---> Hooks (call unconditionally; every guard lives inside the effect)

-- Live price for one pass id (nil id allowed). nil while loading or on failure.
function PassUpsell.usePrice(passId: number?): number?
	local price, setPrice = React.useState(nil :: number?)
	React.useEffect(function()
		setPrice(nil)
		if passId == nil or not RunService:IsRunning() then
			return
		end
		local cancelled = false
		task.spawn(function()
			local fetched = PassUpsell.FetchPriceAsync(passId)
			if not cancelled then
				setPrice(fetched)
			end
		end)
		return function()
			cancelled = true
		end
	end, { passId })
	return price
end

-- Ownership for a fixed list of registered pass ids. Unresolved ids are absent.
-- Pass a stable list (module constant) so the effect runs once.
function PassUpsell.useOwned(passIds: { number }): { [number]: boolean }
	local owned, setOwned = React.useState({} :: { [number]: boolean })
	React.useEffect(function()
		if not RunService:IsRunning() then
			return
		end
		local cancelled = false
		for _, passId in passIds do
			task.spawn(function()
				local owns = PassUpsell.OwnsAsync(passId)
				if cancelled then
					return
				end
				setOwned(function(prev)
					local next = table.clone(prev)
					next[passId] = owns
					return next
				end)
			end)
		end
		local disconnect = PassUpsell.OnPurchased(function(passId: number)
			if cancelled then
				return
			end
			setOwned(function(prev)
				local next = table.clone(prev)
				next[passId] = true
				return next
			end)
		end)
		return function()
			cancelled = true
			disconnect()
		end
	end, { passIds })
	return owned
end

---> Component

-- Small offer row: message on the left, a coloured button on the right.
-- Lesser = secondary look (GREEN_LIGHT button instead of GOLD).
function PassUpsell.Row(props: {
	Text: string,
	ButtonText: string,
	Lesser: boolean?,
	Height: number?,
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Size: UDim2?,
	OnClick: () -> (),
})
	local px = usePx()
	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = UDim.new(0, 6),
		Stroke = { Color = Styles.GREEN_DIM, Thickness = 1 },
		ListLayout = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.02, 0),
		},
		Native = {
			AnchorPoint = props.AnchorPoint,
			BackgroundColor3 = Styles.OFFWHITE,
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Position = props.Position,
			Size = props.Size or UDim2.new(1, 0, 0, px(props.Height or 44)),
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 18,
			Native = {
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.56, 0.78),
				Text = props.Text,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),
		Button = c(PromptButton, {
			Text = props.ButtonText,
			Color = if props.Lesser then Styles.GREEN_LIGHT else Styles.GOLD,
			Size = UDim2.fromScale(0.38, 0.78),
			LayoutOrder = 2,
			OnClick = props.OnClick,
		}),
	})
end

return PassUpsell
