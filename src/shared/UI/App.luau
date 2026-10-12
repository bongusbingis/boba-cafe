--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Page = require(UI.Components.Core.Page)
local Hud = require(UI.Components.Core.Hud)
local Pane = require(UI.Components.Pane)
local RoleSelect = require(UI.Pages.RoleSelect)

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
					--handleSetCurrentPage(typeof(newPage) == "Instance" and newPage or currentPage)
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

		-- Not routed through the page swapper: it has to be able to appear without a HUD
		-- button being pressed, and it covers everything until a role is chosen. It
		-- renders nothing once the player has one.
		RoleSelect = React.createElement(RoleSelect),
	})
end

return App