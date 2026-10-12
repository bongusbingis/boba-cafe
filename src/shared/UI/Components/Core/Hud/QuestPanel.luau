--[[
    Component: QuestPanel
    Description: The expandable daily-quest panel that sits above the bottom-right HUD
    buttons, mirroring how the notification card expands the bottom-left column.

    Replaces V3's StarterGui.MainUI.BottomRightCorner.Quests: four fixed slots, each with
    the quest text over a progress bar and its reward, the fourth showing a lock when the
    bonus-slot pass is not owned, and the reset timer underneath.

    Height is deterministic (see HudLayout.questPanelHeight) because BottomRight sizes its
    column explicitly — AutomaticSize cannot be used there, see HudLayout.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> config
local QuestConfig = require(Shared.Configuration.QuestConfig)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local HudLayout = require(script.Parent.HudLayout)

---> hooks
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

local SLOT_COUNT = #QuestConfig.SLOTS
local BONUS_SLOT = QuestConfig.BONUS_SLOT_INDEX

local TIER_COLORS = {
	Easy = Styles.GREEN_LIGHT,
	Moderate = Styles.GOLD_MID,
	Hard = Styles.CORAL,
}

local function formatRemaining(expires: number): string
	local remaining = math.max(0, (expires or 0) - os.time())

	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)

	if hours > 0 then
		return `Resets in {hours}h {minutes}m`
	end
	if minutes > 0 then
		return `Resets in {minutes}m`
	end
	return "Resetting soon"
end

---> public
return function(props: {
	Visible: boolean,
	LayoutOrder: number?,
})
	local px = usePx()

	-- nil = loading, table = loaded
	local data, setData = React.useState(nil)

	local refresh = React.useCallback(function()
		task.spawn(function()
			local ok, result = Knit.GetService("QuestService"):GetQuests():await()
			if ok and result then
				setData(result)
			end
		end)
	end, {})

	React.useEffect(function()
		-- Only fetch while open; a collapsed panel should not poll the server.
		if not props.Visible then
			return
		end

		refresh()

		local questService = Knit.GetService("QuestService")
		local completed = questService.QuestCompleted:Connect(refresh)
		local changed = questService.QuestsChanged:Connect(refresh)

		return function()
			completed:Disconnect()
			changed:Disconnect()
		end
	end, { props.Visible, refresh })

	if not props.Visible then
		return nil
	end

	local quests = (data and data.Quests) or {}

	local slots: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0, px(HudLayout.QUEST_SLOT_PADDING)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for slot = 1, SLOT_COUNT do
		local quest = quests[slot]

		-- The bonus slot is locked when the server assigned no quest for it, which is
		-- how a missing pass surfaces to the client.
		local isLocked = slot == BONUS_SLOT and quest == nil
		local isLoading = data == nil

		local accent = if quest and quest.Completed
			then Styles.GREEN_BADGE
			elseif quest then (TIER_COLORS[quest.Tier] or Styles.GREEN_LIGHT)
			else Styles.GRAY

		local ratio = if quest and quest.Goal > 0
			then math.clamp(quest.Progress / quest.Goal, 0, 1)
			else 0

		slots[`Slot{slot}`] = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = { Color = accent, Thickness = 2 },
			Native = {
				BackgroundColor3 = Styles.OFFWHITE,
				BackgroundTransparency = if isLocked or isLoading then 0.45 else 0,
				LayoutOrder = slot,
				Size = UDim2.new(1, 0, 0, px(HudLayout.QUEST_SLOT_HEIGHT)),
			},
		}, {
			UIPadding = c("UIPadding", {
				PaddingBottom = UDim.new(0, px(5)),
				PaddingLeft = UDim.new(0, px(8)),
				PaddingRight = UDim.new(0, px(8)),
				PaddingTop = UDim.new(0, px(5)),
			}),

			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.fromScale(0.78, 0.5),
					Text = if isLoading
						then "Loading..."
						elseif isLocked then "Locked"
						elseif quest then quest.Text
						else "No quest",
					TextColor3 = if isLocked or isLoading then Styles.GRAY else Styles.GREEN_DEEP,
					TextScaled = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(17) }),
			}),

			Reward = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(1, 0),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.2, 0.5),
					Text = if isLocked then "🔒" elseif quest then `+{quest.Reward}` else "",
					TextColor3 = if quest and quest.Completed then Styles.GREEN_BADGE else Styles.GOLD_DEEP,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(17) }),
			}),

			---> progress bar, as in V3
			Track = c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_FULL,
				Native = {
					BackgroundColor3 = Styles.GRAY,
					BackgroundTransparency = 0.55,
					Position = UDim2.fromScale(0, 0.62),
					Size = UDim2.fromScale(1, 0.3),
				},
			}, {
				Fill = c(Pane, {
					ClassName = "Frame",
					CornerRadius = Styles.CORNER_FULL,
					Native = {
						BackgroundColor3 = accent,
						BackgroundTransparency = 0,
						-- Zero-width bars still show a rounded nub, so hide at 0.
						Size = UDim2.fromScale(ratio, 1),
						Visible = ratio > 0,
					},
				}),

				Count = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Size = UDim2.fromScale(1, 1),
						Text = if quest then `{quest.Progress} / {quest.Goal}` else "",
						TextColor3 = Styles.GREEN_DEEP,
						TextScaled = true,
					},
				}, {
					UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(13) }),
				}),
			}),
		})
	end

	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.OFFWHITE, Thickness = 2.5 },
		Native = {
			BackgroundColor3 = Styles.GREEN_MID,
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder or 0,
			Size = UDim2.new(1, 0, 0, px(HudLayout.questPanelHeight())),
		},
	}, {
		UIPadding = c("UIPadding", {
			PaddingBottom = UDim.new(0, px(6)),
			PaddingLeft = UDim.new(0, px(8)),
			PaddingRight = UDim.new(0, px(8)),
			PaddingTop = UDim.new(0, px(6)),
		}),

		Header = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.new(1, 0, 0, px(HudLayout.QUEST_HEADER_HEIGHT)),
				Text = "Daily Quests",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(20) }),
		}),

		Slots = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, px(HudLayout.QUEST_HEADER_HEIGHT + 4)),
				Size = UDim2.new(
					1,
					0,
					0,
					px((HudLayout.QUEST_SLOT_HEIGHT + HudLayout.QUEST_SLOT_PADDING) * SLOT_COUNT)
				),
			},
		}, slots),

		---> reset timer beneath the slots, as in V3
		Resets = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, px(HudLayout.QUEST_FOOTER_HEIGHT)),
				Text = if data then formatRemaining(data.Expires) else "",
				TextColor3 = Styles.CREAM,
				TextScaled = true,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(15) }),
		}),
	})
end
