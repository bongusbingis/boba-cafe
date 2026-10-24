local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _PolicyService = game:GetService("PolicyService")
local _Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local OpenableMenu = require(UI.Components.Core.OpenableMenu)

local c = React.createElement

-- local success, playerPolicyInfo: { ArePaidRandomItemsRestricted: boolean } =
-- 	pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, Players.LocalPlayer)

local _paidRandomItemsRestricted = false --success and playerPolicyInfo.ArePaidRandomItemsRestricted or false

local PAGES: { OpenableMenu.Page } = {
	{
		Key = "Character",
		Label = "Character",
		Content = c(require(script.Character)),
		ButtonColor = Styles.GREEN_MID,
		ButtonTextColor = Color3.new(1, 1, 1),
	},
	{
		Key = "Capsules",
		Label = "Capsules",
		Content = c(require(script.InventoryComponent), { ItemType = "Capsules" }),
	},
	{
		Key = "Nametags",
		Label = "Nametags",
		Content = c(require(script.InventoryComponent), { ItemType = "Nametags" }),
	},
	{
		Key = "Pets",
		Label = "Pets",
		Content = c(require(script.InventoryComponent), { ItemType = "Pets" }),
	},
	{
		Key = "Particles",
		Label = "Particles",
		Content = c(require(script.InventoryComponent), { ItemType = "Particles" }),
	},
	{
		Key = "Titles",
		Label = "Titles",
		Content = c(require(script.Titles)),
	},
	{
		Key = "Collection",
		Label = "My Collection",
		ButtonColor = Styles.GOLD,
		ButtonTextColor = Styles.GOLD_DEEP,
		Content = c(require(script.Collection)),
	},
	-- { Key = "Pets", Label = "Pets", Content = c(require(script.DirectCosmeticsPurchase)) },
	-- { Key = "Passes", Label = "Passes", Content = c(require(script.DirectCosmeticsPurchase)) },
	-- {
	-- 	Key = "Cosmetics",
	-- 	Label = "Cosmetics",
	-- 	Content = c(
	-- 		require(script.DirectCosmeticsPurchase)
	-- 	),
	-- },
	-- { Key = "BecomeStaff", Label = "Become Staff", Content = c(require(script.DirectCosmeticsPurchase)) },
}

return function(props)
	local landingPage = PAGES[1]
	if props.Args and props.Args[1] then
		for _, page in PAGES do
			if page.Key == props.Args[1] then
				landingPage = page
				break
			end
		end
	end

	return c(OpenableMenu, {
		TitleText = "Inventory",
		TitleColor = Styles.GREEN,
		DefaultPage = landingPage.Key,
		Pages = PAGES,
		OnClose = function()
			props.ClosePage()
		end,
	})
end
