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
local DailyQuests = require(script.DailyQuests)

local c = React.createElement

return function(props)
	return c(OpenableMenu, {
		TitleText = "Quests",
		TitleColor = Styles.GREEN,
		Pages = {
			{ Key = "Daily", Label = "Daily Quests", Content = c(DailyQuests, { Quests = props.Quests }) },
		},
		OnClose = function()
			props.ClosePage()
		end,
	})
end
