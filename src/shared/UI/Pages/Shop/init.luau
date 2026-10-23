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

local c = React.createElement

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
		Key = "Season",
		Label = "Season",
		LayoutOrder = 1,
		Content = c(require(script.Season)),
	},
	{
		Key = "Products",
		Label = "Products",
		LayoutOrder = 2,
		Content = c(require(script.Products)),
	},
	{
		Key = "Passes",
		Label = "Passes",
		LayoutOrder = 3,
		Content = c(require(script.Passes)),
	},
	{
		Key = "Pets",
		Label = "Pets",
		LayoutOrder = 4,
		Content = c(require(script.Pets)),
	},
	{
		Key = "Nametags",
		Label = "Nametags",
		LayoutOrder = 5,
		Content = c(require(script.RandomCosmeticsPurchase)),
	},
	{
		Key = "Particles",
		Label = "Particles",
		LayoutOrder = 6,
		Content = c(require(script.Particles)),
	},
	{
		Key = "Group Benefit",
		Label = "Group Benefit",
		LayoutOrder = 7,
		Content = c(require(script.GroupBenefit)),
	},
}

return function(props)
	local landingPage = PAGES[1]
	local landingKey = if props.Args and props.Args[1] then props.Args[1] else nil
	if landingKey == "Currency" then
		landingKey = "Products"
	elseif landingKey == "Capsules" then
		landingKey = "Pets"
	end

	if landingKey then
		for _, page in PAGES do
			if page.Key == landingKey then
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
