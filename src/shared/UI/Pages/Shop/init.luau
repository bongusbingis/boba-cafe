local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)
local SeasonConfig = require(Shared.Configuration.SeasonConfig)

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
		Label = "Brew Bonus",
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
	local isClaimed, setIsClaimed = React.useState(false)

	React.useEffect(function()
		if not RunService:IsRunning() then
			return
		end

		local function checkClaim()
			local okGroup, GroupBenefitService = pcall(function()
				return Knit.GetService("GroupBenefitService")
			end)
			if okGroup and GroupBenefitService then
				GroupBenefitService:GetClaimStatusAsync()
					:andThen(function(claimStatus)
						if claimStatus == "Claimed" then
							setIsClaimed(true)
						end
					end)
					:catch(function() end)
			end
		end

		checkClaim()

		local okData, DataController = pcall(function()
			return Knit.GetController("DataController")
		end)
		if okData and DataController then
			DataController:GetDataAsync()
				:andThen(function(data)
					if data and data.Inventory and data.Inventory.FreeItemsRedeemed then
						if table.find(data.Inventory.FreeItemsRedeemed, "GroupPet") then
							setIsClaimed(true)
						end
					end
				end)
				:catch(function() end)
		end
	end, {})

	local landingPage = PAGES[1]
	local landingKey = if props.Args and props.Args[1] then props.Args[1] else nil
	if landingKey == "Currency" then
		landingKey = "Products"
	elseif landingKey == "Capsules" then
		landingKey = "Pets"
	elseif landingKey == "GroupBenefit" then
		landingKey = "Group Benefit"
	end

	if landingKey then
		for _, page in PAGES do
			if page.Key == landingKey then
				if page.Key == "Group Benefit" and isClaimed then
					landingPage = PAGES[1]
				else
					landingPage = page
				end
				break
			end
		end
	end

	local pages: { OpenableMenu.Page } = {}
	for _, page in PAGES do
		if page.Key == "Season" and SeasonConfig.ENABLED == false then
			continue
		end
		local copy = table.clone(page)
		if page.Key == "Group Benefit" then
			copy.Visible = not isClaimed
			copy.Content = c(require(script.GroupBenefit), {
				OnClaimed = function()
					setIsClaimed(true)
				end,
			})
		end
		table.insert(pages, copy)
	end

	return c(OpenableMenu, {
		TitleText = "Shop",
		TitleColor = Styles.GREEN,
		DefaultPage = landingPage.Key,
		Pages = pages,
		TabHeight = 0.095,
		SideButtonsProps = {
			ListLayout = {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				Padding = UDim.new(0.015, 0), -- ensures all tabs fit without overflowing
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
		OnClose = function()
			props.ClosePage()
		end,
	})
end
