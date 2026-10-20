--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Styles = require(UI.Styles)

local Page = require(UI.Components.Core.Page)
local OpenableMenu = require(UI.Components.Core.OpenableMenu)
local DailyRewardsBody = require(script.Parent.DailyRewardsBody)

local c = React.createElement

export type DailyRewardsDialogProps = {
	Status: { [string]: any }?,
	OffsetX: number?,
	OnResolution: ((any) -> ())?,
	OnClose: (() -> ())?,
	Native: { [string]: any }?,
}

local function DailyRewardsMenu(props: { Status: { [string]: any }?, OnCloseRequested: () -> () })
	local rewardsTab = c(DailyRewardsBody, { Status = props.Status })

	return c(OpenableMenu, {
		TitleText = "Daily Rewards",
		TitleColor = Styles.GREEN,
		Pages = {
			{ Key = "Rewards", Label = "Rewards", Content = rewardsTab },
		},
		OnClose = props.OnCloseRequested,
	})
end

return function(props: DailyRewardsDialogProps)
	local closeFnRef = React.useRef(nil)

	local function handleClose()
		if closeFnRef.current then
			closeFnRef.current()
		end
		if props.OnResolution then
			props.OnResolution("Close")
		end
		if props.OnClose then
			props.OnClose()
		end
	end

	return c(Page, {
		IsVisible = true,
		PageContent = c(DailyRewardsMenu, {
			Status = props.Status,
			OnCloseRequested = handleClose,
		}),
		OnClosing = function(cb)
			closeFnRef.current = cb
		end,
	})
end
