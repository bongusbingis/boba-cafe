--[[
	TopBar
	Renders groups of Hud buttons used for opening/closing page components,
	along with the integrated center Cafe Rating and Rush Event pod,
	and flanking Cmdr / Logs admin buttons for authorized staff.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)
local RankUtil = require(Shared.Utility.RankUtil)

---> styles
local Styles = require(UI.Styles)

---> components
local Pages = UI.Pages
local Pane = require(UI.Components.Pane)
local HudTabButton = require(UI.Components.Buttons.HudTabButton)
local useQuestClaimable = require(UI.Hooks.useQuestClaimable)
local CafeRating = require(UI.Components.Core.Hud.CafeRating)

---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript?,
	SetCurrentPage: ((pageComponent: ModuleScript | nil, ...any) -> ())?,
})
	local questClaimable = useQuestClaimable()

	local isAllowed, setIsAllowed = React.useState(function()
		if RunService:IsStudio() then
			return true
		end
		local player = Players.LocalPlayer
		return player ~= nil and player:GetAttribute("IsAdmin") == true
	end)

	React.useEffect(function()
		if RunService:IsStudio() then
			setIsAllowed(true)
			return
		end

		local player = Players.LocalPlayer
		if not player then
			return
		end

		local function checkPermission()
			if player:GetAttribute("IsAdmin") == true then
				setIsAllowed(true)
				return
			end
			task.spawn(function()
				local ok, rank = pcall(function()
					return RankUtil:GetRankAsync(player)
				end)
				if ok and typeof(rank) == "number" and rank >= 11 then
					setIsAllowed(true)
				end
			end)
		end

		checkPermission()
		local conn = player:GetAttributeChangedSignal("IsAdmin"):Connect(checkPermission)
		return function()
			conn:Disconnect()
		end
	end, {})

	local function setPage(page: ModuleScript)
		return function()
			if props.SetCurrentPage then
				props.SetCurrentPage(page)
			end
		end
	end

	-- DEC-040: real players order through the Boba Phone, so no register
	-- "Use Ordering System" prompt is created here. Pages.Ordering and the
	-- barista tablet (OrderController.OpenOrderingTablet) are untouched.
	return c(Pane, {
		Native = {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, -0.001),
			Size = UDim2.fromScale(0.377911, 0.106612),
		},
		AspectRatio = 6.5443,
	}, {
		CafeRating = c(CafeRating, {}),

		CmdrButton = if isAllowed
			then c("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				AutoButtonColor = true,
				BackgroundColor3 = Styles.GREEN_MID,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.new(0.245, -6, 0.95, 0),
				Size = UDim2.fromOffset(54, 28),
				Text = "Cmdr",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				ZIndex = 4,
				[React.Event.Activated] = function()
					local ok, cmdrCtrl = pcall(function()
						return Knit.GetController("CmdrController")
					end)
					if ok and cmdrCtrl and typeof(cmdrCtrl.Toggle) == "function" then
						cmdrCtrl:Toggle()
					end
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = c("UIStroke", {
					Color = Styles.GREEN_DEEP,
					Thickness = 2,
				}),
			})
			else nil,

		LogsButton = if isAllowed
			then c("TextButton", {
				AnchorPoint = Vector2.new(0, 0.5),
				AutoButtonColor = true,
				BackgroundColor3 = Styles.GREEN_MID,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.new(0.755, 6, 0.95, 0),
				Size = UDim2.fromOffset(54, 28),
				Text = "Logs",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				ZIndex = 4,
				[React.Event.Activated] = function()
					local ok, logViewer = pcall(function()
						return Knit.GetController("LogViewerController")
					end)
					if ok and logViewer and typeof(logViewer.Toggle) == "function" then
						logViewer:Toggle()
					end
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = c("UIStroke", {
					Color = Styles.GREEN_DEEP,
					Thickness = 2,
				}),
			})
			else nil,

		Base = c(Pane, {
			ClassName = "ImageLabel",
			AspectRatio = 11.5077,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Image = "http://www.roblox.com/asset/?id=13407950658",
				ImageColor3 = Styles.GREEN,
				Position = UDim2.fromScale(0.5, 0),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.982294, 0.558621),
				ZIndex = 2,
			},
		}, {
			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Image = "http://www.roblox.com/asset/?id=13407901910",
					ImageColor3 = Styles.OFFWHITE,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.00668, 1.07692),
					ZIndex = 2,
				},
			}),

			Buttons = c(Pane, {
				Native = {
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
				},
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				},
			}, {
				Shop = c(HudTabButton, {
					LayoutOrder = 0,
					Text = "Shop",
					TextColor3 = Styles.OFFWHITE,
					OnClick = setPage(Pages.Shop),
				}),
				Menu = c(HudTabButton, {
					LayoutOrder = 1,
					Text = "Menu",
					ShowDot = questClaimable,
					TextColor3 = Styles.OFFWHITE,
					OnClick = setPage(Pages.Menu),
				}),
				Inventory = c(HudTabButton, {
					LayoutOrder = 2,
					Text = "Inventory",
					TextColor3 = Styles.OFFWHITE,
					OnClick = setPage(Pages.Inventory),
				}),
			}),
		}),

		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(590, math.huge),
			MinSize = Vector2.new(390, math.huge),
		}),
	})
end
