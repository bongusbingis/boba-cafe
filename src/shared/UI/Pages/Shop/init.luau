local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
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

local paidRandomItemsRestricted = false--success and playerPolicyInfo.ArePaidRandomItemsRestricted or false

local PAGES: { OpenableMenu.Page } = {
	{
		Key = "Featured",
		Label = "Featured",
		LayoutOrder = 0,
		Content = c(require(script.Featured)),
		ButtonColor = Styles.ROSE,
		ButtonTextColor = Styles.ROSE_DEEP,
	},
	{
		Key = "Celebrity",
		Label = "Celebrity",
		Content = c(require(script.Celebrity)),
		ButtonColor = Styles.GOLD,
		ButtonTextColor = Styles.GOLD_DEEP,
	},
	{ Key = "Currency", Label = "Currency", Content = c(require(script.Currency)) },
	{ Key = "Pets", Label = "Pets", Content = c(require(script.Pets)) },
	{ Key = "Passes", Label = "Passes", Content = c(require(script.Passes)) },
	{
		Key = "Nametags",
		Label = "Nametags",
		Content = c(
			require((paidRandomItemsRestricted and script.DirectCosmeticsPurchase or script.RandomCosmeticsPurchase))
		),
	},
	{ Key = "Particles", Label = "Particles", Content = c(require(script.Particles)) },
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
		TitleText = "Shop",
		TitleColor = Styles.GREEN,
		DefaultPage = landingPage.Key,
		Pages = PAGES,
		OnClose = function()
			props.ClosePage()
		end,
	})
end
