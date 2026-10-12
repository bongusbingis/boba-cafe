--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)
local HudLayout = require(script.Parent.HudLayout)
local QuestPanel = require(script.Parent.QuestPanel)

---> private
local c = React.createElement
local usePx = require(UI.Hooks.usePx)

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local px = usePx()

	-- The Island page is only useful to Celebrities, so the button is hidden entirely
	-- rather than opening a page that just says "you can't use this".
	local isCelebrity, setIsCelebrity = React.useState(false)

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			local ok, result = Knit.GetService("CelebrityService"):IsCelebrity():await()
			if not cancelled and ok then
				setIsCelebrity(result == true)
			end
		end)

		-- Membership changes when a subscription is claimed or lapses mid-session.
		local changed = Knit.GetService("CelebrityService").IslandChanged:Connect(function()
			task.spawn(function()
				local ok, result = Knit.GetService("CelebrityService"):IsCelebrity():await()
				if not cancelled and ok then
					setIsCelebrity(result == true)
				end
			end)
		end)

		return function()
			cancelled = true
			changed:Disconnect()
		end
	end, {})

	-- Quests live here as an expandable panel rather than a page, mirroring how the
	-- notification card expands the bottom-left column. Collapsed by default.
	local questsOpen, setQuestsOpen = React.useState(false)

	-- Keep in step with the buttons below. An explicit height is used rather than
	-- AutomaticSize because NormalButton's 7:1 aspect-ratio constraint resolves after
	-- AutomaticSize measures its children, which collapsed the column to nothing.
	local BUTTON_COUNT = if isCelebrity then 3 else 2

	local columnHeight = HudLayout.stackHeight(BUTTON_COUNT)
	if questsOpen then
		columnHeight += HudLayout.questPanelHeight() + HudLayout.STACK_PADDING
	end

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, px(-HudLayout.EDGE_INSET), HudLayout.BOTTOM_ANCHOR, 0),
			Size = UDim2.new(HudLayout.COLUMN_WIDTH, 0, 0, px(columnHeight)),
			BackgroundTransparency = 1,
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, px(HudLayout.STACK_PADDING)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
	}, {
		-- Sits above the buttons (lowest LayoutOrder in a bottom-aligned list).
		QuestPanel = c(QuestPanel, {
			Visible = questsOpen,
			LayoutOrder = 0,
		}),

		Quests = c(NormalButton, {
			--PlusButton = true,
			--Icon = "rbxassetid://13382286492",
			Size = UDim2.new(1, 0, 0, px(HudLayout.BUTTON_HEIGHT)),
			Color = Styles.PURPLE,
			Text = "Quests",
			-- Toggles the panel rather than opening a page.
			OnClick = function()
				setQuestsOpen(function(open)
					return not open
				end)
			end,
			LayoutOrder = 3,
		}),
		DailyRewards = c(NormalButton, {
			--PlusButton = true,
			--Icon = "rbxassetid://13382286492",
			Size = UDim2.new(1, 0, 0, px(HudLayout.BUTTON_HEIGHT)),
			Color = Styles.GOLD_MID,
			Text = "Daily Rewards",
			OnClick = function()
				props.SetCurrentPage(UI.Pages.Rewards, "Daily Rewards")
			end,
			LayoutOrder = 2,
		}),
		-- Hidden for non-Celebrities: showing a button that opens a page they cannot use
		-- is worse than not offering it at all.
		Island = if isCelebrity
			then c(NormalButton, {
				Size = UDim2.new(1, 0, 0, px(HudLayout.BUTTON_HEIGHT)),
				Color = Styles.GOLD,
				Text = "Island",
				OnClick = function()
					props.SetCurrentPage(UI.Pages.Island, "Island")
				end,
				LayoutOrder = 4,
			})
			else nil,
	})
end
