--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local WorldPath = require(Shared.Utility.WorldPath)

---> styles
local Styles = require(UI.Styles)

---> components
local Pages = UI.Pages
local Pane = require(UI.Components.Pane)
local HudTabButton = require(UI.Components.Buttons.HudTabButton)

---> constants
-- workspace["Ordering System"].Computers is authored in the place. It is resolved
-- after the HUD mounts with a bounded wait so a missing folder never blocks the HUD.
local ORDERING_SYSTEM_TIMEOUT_SECONDS = 30
local CLOCKED_IN_ATTRIBUTE = "ClockedIn" -- owned by the server's ShiftService

---> private
local c = React.createElement

local function waitForComputers(): Instance?
	local computers = WorldPath.waitFor(workspace, { "Ordering System", "Computers" }, ORDERING_SYSTEM_TIMEOUT_SECONDS)
	if not computers then
		warn('[TopBar] workspace["Ordering System"].Computers not found; register prompts disabled.')
	end
	return computers
end

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local function setPage(page: ModuleScript)
		return function()
			props.SetCurrentPage(page)
		end
	end

	---> init register prompts (every player may order)

	if RunService:IsRunning() then
		React.useEffect(function()
			local prompts: { ProximityPrompt } = {}
			local cancelled = false
			local clockedInConnection: RBXScriptConnection? = nil

			task.spawn(function()
				local computers = waitForComputers()
				if not computers or cancelled then
					return
				end

				for _, computer in computers:GetChildren() do
					local prompt = Instance.new("ProximityPrompt")
					prompt.HoldDuration = 0
					prompt.UIOffset = Vector2.new(0, 25)
					prompt.ObjectText = "Register"
					prompt.ActionText = "Use Ordering System"
					prompt.RequiresLineOfSight = false
					prompt.Parent = computer
					prompt.Triggered:Connect(function()
						props.SetCurrentPage(Pages.Ordering)
					end)
					table.insert(prompts, prompt)
				end

				-- Clocked-in baristas don't see the register prompt, so it can't fight the NPC Serve prompt (DEC-046).
				local function updatePromptEnabled()
					for _, prompt in prompts do
						prompt.Enabled = Players.LocalPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) ~= true
					end
				end
				updatePromptEnabled()
				if not cancelled then
					clockedInConnection =
						Players.LocalPlayer:GetAttributeChangedSignal(CLOCKED_IN_ATTRIBUTE):Connect(updatePromptEnabled)
				end
			end)

			return function()
				cancelled = true
				if clockedInConnection then
					clockedInConnection:Disconnect()
				end
				for _, prompt in prompts do
					prompt:Destroy()
				end
			end
		end, {})
	end

	return c(Pane, {
		Native = {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, -0.001),
			Size = UDim2.fromScale(0.377911, 0.106612),
		},
		AspectRatio = 6.5443,
	}, {
		Time = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Image = "http://www.roblox.com/asset/?id=13407992271",
				ImageColor3 = Styles.GREEN,
				Position = UDim2.fromScale(0.5, 0.327),
				Size = UDim2.fromScale(0.263667, 0.633103),
			},
		}, {
			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Image = "http://www.roblox.com/asset/?id=13408001982",
					ImageColor3 = Styles.OFFWHITE,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 5, 1, 5),
				},
			}),

			TextLabel = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.66),
					Size = UDim2.fromScale(1, 0.364498),
					Text = "12:34 PM",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),
		}),

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
				},
			}),

			Buttons = c(Pane, {
				Native = {
					Size = UDim2.fromScale(1, 1),
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
