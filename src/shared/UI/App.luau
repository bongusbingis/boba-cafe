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
				handleSetCurrentPage(orderingPage, npcOrderData)
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

		return function()
			conn1:Disconnect()
			conn2:Disconnect()
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
			CurrentPage = pageToRender,
		}),
		HUD = React.createElement(Hud, {
			CurrentPage = currentPage,
			SetCurrentPage = handleSetCurrentPage,
		}),
	})
end

return App
