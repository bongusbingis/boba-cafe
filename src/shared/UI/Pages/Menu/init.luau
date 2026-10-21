local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local OpenableMenu = require(UI.Components.Core.OpenableMenu)

---> pages
local FoodMenu = require(script.FoodMenu)
local Staff = require(script.Staff)
local Daily = require(script.Daily)
local PromoCodes = require(script.PromoCodes)
local Credits = require(script.Credits)
local Purchases = require(script.Purchases)
-- local ServerInfo = require(script.ServerInfo)
local Settings = require(script.Settings)
local Statistics = require(script.Statistics)
local Regulars = require(script.Regulars)
local Quests = require(script.Quests)
local useQuestClaimable = require(UI.Hooks.useQuestClaimable)
local c = React.createElement

local PAGES: { OpenableMenu.Page } = {
	{
		Key = "FoodMenu",
		Label = "Food Menu",
		LayoutOrder = 1,
		Content = c(FoodMenu, {}),
	},
	{
		Key = "Staff",
		Label = "Staff",
		LayoutOrder = 2,
		Content = c(Staff, {}),
	},
	{
		Key = "Daily",
		Label = "Daily Rewards",
		LayoutOrder = 3,
		Content = c(Daily, {}),
	},
	{
		-- Daily + weekly quests; the only way to open them (DEC-057 removed the HUD button).
		Key = "Quests",
		Label = "Quests",
		LayoutOrder = 4,
		Content = c(Quests, {}),
	},
	{
		Key = "PromoCodes",
		Label = "Promo Codes",
		LayoutOrder = 5,
		Content = c(PromoCodes, {}),
	},
	{
		Key = "Statistics",
		Label = "Statistics",
		LayoutOrder = 6,
		Content = c(Statistics, {}),
	},
	{
		-- BIG-B5 Regulars collection.
		Key = "Regulars",
		Label = "Regulars",
		LayoutOrder = 7,
		Content = c(Regulars, {}),
	},
	{
		Key = "Purchases",
		Label = "Purchases",
		LayoutOrder = 8,
		Content = c(Purchases, {}),
	},
	-- ServerInfo button is made invisible for now to fit the side menu cleanly (DEC-019).
	-- {
	-- 	Key = "ServerInfo",
	-- 	Label = "Server Info",
	-- 	LayoutOrder = 7,
	-- 	Content = c(ServerInfo, {}),
	-- },
	{
		Key = "Settings",
		Label = "Settings",
		LayoutOrder = 9,
		Content = c(Settings, {}),
	},
	{
		Key = "Credits",
		Label = "Credits",
		LayoutOrder = 10,
		Content = c(Credits, {}),
	},
}

return function(props)
	local questClaimable = useQuestClaimable()
	local pages: { OpenableMenu.Page } = {}
	for _, page in PAGES do
		local copy = table.clone(page)
		if page.Key == "Quests" then
			copy.ShowDot = questClaimable
		end
		table.insert(pages, copy)
	end

	local landingPage = PAGES[1]
	if props and props.Args and props.Args[1] then
		for _, page in PAGES do
			if page.Key == props.Args[1] then
				landingPage = page
				break
			end
		end
	end

	return c(OpenableMenu, {
		TitleText = "Menu",
		TitleColor = Styles.GREEN,
		DefaultPage = landingPage.Key,
		Pages = pages,
		TabHeight = 0.088,
		SideButtonsProps = {
			ListLayout = {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0.006, 0), -- ten tabs at 0.088 each fit the side panel
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
		OnClose = if props and props.ClosePage
			then function()
				props.ClosePage()
			end
			else nil,
	})
end
