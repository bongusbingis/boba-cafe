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
		Key = "PromoCodes",
		Label = "Promo Codes",
		LayoutOrder = 4,
		Content = c(PromoCodes, {}),
	},
	{
		Key = "Statistics",
		Label = "Statistics",
		LayoutOrder = 5,
		Content = c(Statistics, {}),
	},
	{
		Key = "Purchases",
		Label = "Purchases",
		LayoutOrder = 6,
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
		LayoutOrder = 7,
		Content = c(Settings, {}),
	},
	{
		Key = "Credits",
		Label = "Credits",
		LayoutOrder = 8,
		Content = c(Credits, {}),
	},
}

return function(props)
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
		Pages = PAGES,
		SideButtonsProps = {
			ListLayout = {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0.015, 0),
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
