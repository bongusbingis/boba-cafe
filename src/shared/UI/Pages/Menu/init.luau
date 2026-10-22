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
		-- Purchases and Credits are merged as sub-tabs inside Settings to keep side tabs uncrowded.
		Key = "Settings",
		Label = "Settings",
		LayoutOrder = 8,
		Content = c(Settings, {}),
	},
}

return function(props)
	local questClaimable = useQuestClaimable()
	local landingKey = PAGES[1].Key
	local requestedSubTab: string? = nil

	if props and props.Args and props.Args[1] then
		local arg = props.Args[1]
		if arg == "Purchases" or arg == "Credits" then
			landingKey = "Settings"
			requestedSubTab = arg
		else
			for _, page in PAGES do
				if page.Key == arg then
					landingKey = page.Key
					break
				end
			end
		end
	end

	local pages: { OpenableMenu.Page } = {}
	for _, page in PAGES do
		local copy = table.clone(page)
		if page.Key == "Quests" then
			copy.ShowDot = questClaimable
		elseif page.Key == "Settings" and requestedSubTab ~= nil then
			copy.Content = c(Settings, { SubTab = requestedSubTab })
		end
		table.insert(pages, copy)
	end

	return c(OpenableMenu, {
		TitleText = "Menu",
		TitleColor = Styles.GREEN,
		DefaultPage = landingKey,
		Pages = pages,
		TabHeight = 0.095,
		SideButtonsProps = {
			ListLayout = {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0.015, 0), -- eight tabs at 0.095 each fit comfortably
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
