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
		Key = "Featured",
		Label = "Featured",
		LayoutOrder = 0,
		Content = c(require(script.Featured)),
		ButtonColor = Color3.fromRGB(255, 182, 193),
		ButtonTextColor = Color3.fromRGB(180, 80, 100),
	},
	{
		Key = "Celebrity",
		Label = "Celebrity",
		Content = c(require(script.Celebrity)),
		ButtonColor = Color3.fromRGB(255, 215, 37),
		ButtonTextColor = Color3.fromRGB(188, 132, 0),
	},
	{ Key = "Currency", Label = "Currency", Content = c(require(script.Currency)) },
	{ Key = "Pets", Label = "Pets", Content = c(require(script.Pets)) },
	{ Key = "Passes", Label = "Passes", Content = c(require(script.Passes)) },
	{ Key = "Cosmetics", Label = "Cosmetics", Content = c(require(script.Cosmetics)) },
	{ Key = "BecomeStaff", Label = "Become Staff", Content = c(require(script.BecomeStaff))},
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
		TitleColor = Color3.fromRGB(143, 169, 127),
		DefaultPage = landingPage.Key,
		Pages = PAGES,
        OnClose = function()
            props.ClosePage()
        end,
	})
end
