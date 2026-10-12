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

---> hooks
local usePolicy = require(UI.Hooks.usePolicy)

local c = React.createElement

-- Pages that never vary. The Nametags entry depends on the player's policy, so it is
-- built per-render below rather than here at module scope.
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
	{ Key = "Particles", Label = "Particles", Content = c(require(script.Particles)) },
}

return function(props)
	-- Capsules are paid random items. Players whose policy restricts those are shown the
	-- direct-purchase nametag shop instead. Restricted is assumed until proven otherwise.
	local policy = usePolicy()

	local pages = React.useMemo(function()
		local built = table.clone(PAGES)

		table.insert(built, {
			Key = "Nametags",
			Label = "Nametags",
			Content = c(
				require(if policy.restricted then script.DirectCosmeticsPurchase else script.RandomCosmeticsPurchase)
			),
		})

		return built
	end, { policy.restricted })

	local landingPage = pages[1]
	if props.Args and props.Args[1] then
		for _, page in pages do
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
		Pages = pages,
		OnClose = function()
			props.ClosePage()
		end,
	})
end
