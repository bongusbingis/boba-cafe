--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> components
local Page = require(UI.Components.Core.Page)
local Hud = require(UI.Components.Core.Hud)
local Pane = require(UI.Components.Pane)

---> constants
local FULL_SCALE = UDim2.fromScale(1, 1)
local PAGE_SWAP_DELAY = 0.025

---> private
local c = React.createElement

local function App()
	local extraData = React.useRef(nil)
	local closePreviousPageCallback = React.useRef(nil)
	local currentPage, setCurrentPage = React.useState(nil)
	local pageMountKey, setPageMountKey = React.useState(0)

	local function closeCurrentPageIfExists()
		if closePreviousPageCallback.current then
			closePreviousPageCallback.current()
			task.wait(PAGE_SWAP_DELAY)
		end
	end

	local function handleSetCurrentPage(page: ModuleScript | nil, ...)
		extraData.current = { ... }
		setCurrentPage(function(existingPage)
			closeCurrentPageIfExists()
			if existingPage and existingPage == page then
				closePreviousPageCallback.current = nil
				return nil
			end
			return page
		end)
	end

	React.useEffect(function()
		local ok, orderController = pcall(function()
			return Knit.GetController("OrderController")
		end)
		if not ok or not orderController then
			return
		end

		local conn1 = orderController.OpenOrderingRequested:Connect(function(npcOrderData)
			local pages = UI:FindFirstChild("Pages")
			local orderingPage = pages and pages:FindFirstChild("Ordering")
			if orderingPage then
				-- TAKEOVER-REVIEW-FIX P2-1: Take Order always opens the tablet for this NPC (never toggles it shut),
				-- and a new mount key resets the page when it was already open for another NPC.
				extraData.current = { npcOrderData }
				setCurrentPage(function()
					closeCurrentPageIfExists()
					return orderingPage
				end)
				setPageMountKey(function(n)
					return n + 1
				end)
			end
		end)

		local conn2 = orderController.CloseOrderingRequested:Connect(function()
			setCurrentPage(function(existingPage)
				local pages = UI:FindFirstChild("Pages")
				local orderingPage = pages and pages:FindFirstChild("Ordering")
				if existingPage == orderingPage then
					closeCurrentPageIfExists()
					return nil
				end
				return existingPage
			end)
		end)

		local connUpsell
		pcall(function()
			local upsellService = Knit.GetService("BobaBuddyUpsellService")
			if upsellService and upsellService.OpenShopRequested then
				connUpsell = upsellService.OpenShopRequested:Connect(function(tab, highlightKey)
					local pages = UI:FindFirstChild("Pages")
					local shopPage = pages and pages:FindFirstChild("Shop")
					if shopPage then
						extraData.current = { tab or "Products", highlightKey }
						setCurrentPage(function()
							closeCurrentPageIfExists()
							return shopPage
						end)
						setPageMountKey(function(n)
							return n + 1
						end)
					end
				end)
			end
		end)

		return function()
			conn1:Disconnect()
			conn2:Disconnect()
			if connUpsell then
				connUpsell:Disconnect()
			end
		end
	end, {})

	-- "Get Boba Bucks" from a shortfall dialog: always land on the requested Shop tab (never toggle shut).
	React.useEffect(function()
		local ok, dialogController = pcall(function()
			return Knit.GetController("DialogController")
		end)
		if not ok or not dialogController or not dialogController.OpenShopRequested then
			return
		end
		local conn = dialogController.OpenShopRequested:Connect(function(pageKey)
			local pages = UI:FindFirstChild("Pages")
			local shopPage = pages and pages:FindFirstChild("Shop")
			if shopPage then
				extraData.current = { pageKey }
				setCurrentPage(function()
					closeCurrentPageIfExists()
					return shopPage
				end)
				setPageMountKey(function(n)
					return n + 1
				end)
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local pageToRender = currentPage
		and c(Page, {
			IsVisible = true,
			PageContent = c(require(currentPage), {
				Args = extraData.current,
				ClosePage = function(newPage: ModuleScript?)
					if newPage and newPage.ClassName == "ModuleScript" then
						handleSetCurrentPage(newPage)
					else
						handleSetCurrentPage(currentPage)
					end
				end,
			}),
			OnClosing = function(callbackFunction)
				closePreviousPageCallback.current = callbackFunction
			end,
		})

	return React.createElement(Pane, {
		Native = {
			Size = FULL_SCALE,
		},
	}, {
		Pages = React.createElement(Pane, {
			Native = {
				Size = FULL_SCALE,
			},
		}, {
			["CurrentPage" .. pageMountKey] = pageToRender,
		}),
		HUD = React.createElement(Hud, {
			CurrentPage = currentPage,
			SetCurrentPage = handleSetCurrentPage,
		}),
	})
end

return App
