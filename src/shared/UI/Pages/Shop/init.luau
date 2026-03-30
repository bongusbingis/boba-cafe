local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local OpenableMenu = require(UI.Components.Core.OpenableMenu)

local c = React.createElement

local PAGES: { OpenableMenu.Page } = {
	{
		Key = "Celebrity",
		Label = "Celebrity",
		Content = c(require(script.Celebrity)),
		LayoutOrder = 0,
		ButtonColor = Color3.fromRGB(255, 215, 37),
		ButtonTextColor = Color3.fromRGB(188, 132, 0),
	},
	{
		Key = "Featured",
		Label = "Featured",
		Content = nil,
		ButtonColor = Color3.fromRGB(255, 182, 193),
		ButtonTextColor = Color3.fromRGB(180, 80, 100),
	},
	{ Key = "Currency", Label = "Currency", Content = c(require(script.Currency)) },
	{ Key = "Pets", Label = "Pets", Content = nil },
	{ Key = "Passes", Label = "Passes", Content = c(require(script.Passes)) },
	{ Key = "Cosmetics", Label = "Cosmetics", Content = nil },
	{ Key = "BecomeStaff", Label = "Become Staff", Content = nil },
}

return function(props)
	return c(OpenableMenu, {
		TitleText = "Shop",
		TitleColor = Color3.fromRGB(143, 169, 127),
		DefaultPage = "Celebrity",
		Pages = PAGES,
        OnClose = function()
            props.ClosePage()
        end,
	})
end
