--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
	- QuestsOpen: Whether the Quests pop-up card is open.
	- OnToggleQuests: Opens the Quests card when closed, closes it when open.
]]

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)
local usePx = require(UI.Hooks.usePx)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)

---> constants
local BUTTON_SIZE = UDim2.fromScale(1, 1)
-- Shifts the mount left of the mobile jump zone (width 0.75-1.0) (DEC-048, Q26 = B).
local JUMP_BUTTON_CLEARANCE = 196

---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
	QuestsOpen: boolean?,
	OnToggleQuests: (() -> ())?,
})
	local px = usePx()
	local claimable, setClaimable = React.useState(false)

	if RunService:IsRunning() then
		React.useEffect(function()
			local conn
			local alive = true

			local function refresh(quests)
				if not alive or typeof(quests) ~= "table" then
					return
				end
				local any = false
				for _, entry in quests do
					if entry.Completed == true and entry.Claimed ~= true then
						any = true
						break
					end
				end
				setClaimable(any)
			end

			task.spawn(function()
				pcall(function()
					local questService = Knit.GetService("QuestService")
					local res = questService:GetQuests()
					if typeof(res) == "table" and res.andThen then
						res:andThen(refresh)
					elseif typeof(res) == "table" then
						refresh(res)
					end
					if alive then
						conn = questService.QuestsUpdated:Connect(refresh)
					end
				end)
			end)

			return function()
				alive = false
				if conn then
					conn:Disconnect()
				end
			end
		end, {})
	end

	return c(Pane, {
		ClassName = "Frame",
		ListLayout = {
			Padding = UDim.new(0.03, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		},
		Native = {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(0.981, -JUMP_BUTTON_CLEARANCE, 0.981, 0),
			Size = UDim2.fromScale(0.175, 0.065),
			--BackgroundTransparency = 0.5
		},
	}, {
		Quests = c(Pane, {
			ClassName = "Frame",
			AspectRatio = 7,
			Native = {
				BackgroundTransparency = 1,
				Size = BUTTON_SIZE,
				LayoutOrder = 1,
			},
		}, {
			Button = c(NormalButton, {
				Icon = "",
				Position = UDim2.fromScale(0.5, 0.5),
				Size = BUTTON_SIZE,
				Color = Styles.GREEN_MID,
				Text = "Quests",
				OnClick = function()
					if props.OnToggleQuests then
						props.OnToggleQuests()
					end
				end,
			}),
			ClaimDot = if claimable
				then c(Pane, {
					ClassName = "Frame",
					CornerRadius = Styles.CORNER_FULL,
					Stroke = { Color = Styles.OFFWHITE, Thickness = 2 },
					Native = {
						Name = "QuestClaimDot",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Styles.GREEN_BADGE,
						BackgroundTransparency = 0,
						Position = UDim2.fromScale(0.94, 0.1),
						Size = UDim2.fromOffset(px(16), px(16)),
						ZIndex = 5,
					},
				})
				else nil,
		}),
	})
end
