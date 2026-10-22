--[[
	BobaBucksShortfall
	One place for the "you cannot afford that" dead ends (UPSELL lane 1).

	Pure helpers (PickPackAmount, BuildText) are unit-tested. The client helpers
	(GetShortfall, OpenShop, Prompt) only ever run after the player's own click: they
	show a ButtonPrompt whose "Get Boba Bucks" button opens Shop > Currency. They never
	prompt a purchase themselves, and no Robux prices live here (DEC-026); the Currency
	page shows live Marketplace prices.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local Styles = require(UI.Styles)

---> constants
-- Mirrors the Boba Bucks packs on Shop > Currency (ProductIds.BobaBucks.Pack50..Pack5000).
local PACK_AMOUNTS = { 50, 150, 500, 1000, 5000 }

local GET_BUCKS = "Get Boba Bucks"
local CANCEL = "Cancel"

---> public
local BobaBucksShortfall = {}
BobaBucksShortfall.GET_BUCKS = GET_BUCKS
BobaBucksShortfall.PACK_AMOUNTS = PACK_AMOUNTS

-- Smallest pack that covers the shortfall; the largest pack when none does; nil when nothing is owed.
function BobaBucksShortfall.PickPackAmount(shortfall: number?): number?
	if typeof(shortfall) ~= "number" or shortfall ~= shortfall or shortfall <= 0 then
		return nil
	end
	for _, amount in PACK_AMOUNTS do
		if amount >= shortfall then
			return amount
		end
	end
	return PACK_AMOUNTS[#PACK_AMOUNTS]
end

-- Dialog body. `What` is the thing being bought, e.g. "that upgrade" (optional).
function BobaBucksShortfall.BuildText(shortfall: number?, what: string?): string
	local target = if what and what ~= "" then what else "that"
	local pack = BobaBucksShortfall.PickPackAmount(shortfall)
	if pack and shortfall then
		local covers = if pack >= shortfall then "covers it" else "is the biggest pack"
		return `You need {math.ceil(shortfall)} more Boba Bucks for {target}. The {pack} Boba Bucks pack {covers}.`
	end
	return `You do not have enough Boba Bucks for {target}.`
end

---> client only
-- price - current balance (read from replicated player data), or nil when unknown.
function BobaBucksShortfall.GetShortfall(price: any): number?
	local numeric = tonumber(price)
	if not numeric then
		return nil
	end
	local ok, balance = pcall(function()
		local data = Knit.GetController("DataController").LocalPlayerData
		return data and data.Currency and data.Currency.BobaBucks
	end)
	if not ok or typeof(balance) ~= "number" then
		return nil
	end
	local owed = numeric - balance
	return if owed > 0 then owed else nil
end

-- Opens Shop > Currency (the App listens on DialogController.OpenShopRequested).
function BobaBucksShortfall.OpenShop()
	local ok, controller = pcall(function()
		return Knit.GetController("DialogController")
	end)
	if ok and controller and controller.OpenShopRequested then
		controller.OpenShopRequested:Fire("Currency")
	end
end

--[[
	Shows the "Not enough Boba Bucks" ButtonPrompt.
	opts.Price / opts.Shortfall : one of them sizes the message (both optional)
	opts.What                   : "that upgrade", "that capsule", ...
	opts.ExtraButton            : { Text: string, OnClick: () -> () }? shown between Get Boba Bucks and Cancel
	opts.OffsetX                : forwarded to ButtonPrompt
]]
function BobaBucksShortfall.Prompt(opts: {
	Price: any?,
	Shortfall: number?,
	What: string?,
	ExtraButton: { Text: string, OnClick: () -> () }?,
	OffsetX: number?,
})
	local shortfall = opts.Shortfall or BobaBucksShortfall.GetShortfall(opts.Price)
	local buttons = { { Text = GET_BUCKS, Color = Styles.GREEN } }
	if opts.ExtraButton then
		table.insert(buttons, { Text = opts.ExtraButton.Text, Color = Styles.GREEN_DIM })
	end
	table.insert(buttons, { Text = CANCEL, Color = Styles.RED })

	local controller = Knit.GetController("DialogController")
	local dialog = controller.new("ButtonPrompt", {
		Title = "Not enough Boba Bucks",
		Text = BobaBucksShortfall.BuildText(shortfall, opts.What),
		Buttons = buttons,
		OffsetX = opts.OffsetX,
	})
	return dialog:Fire():andThen(function(choice)
		if choice == GET_BUCKS then
			BobaBucksShortfall.OpenShop()
		elseif opts.ExtraButton and choice == opts.ExtraButton.Text then
			opts.ExtraButton.OnClick()
		end
	end)
end

return BobaBucksShortfall
