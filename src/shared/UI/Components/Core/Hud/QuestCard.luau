--[[
    Component: QuestCard
    Description: Daily Quests pop-up card (REVIVAL-001 M4-QUESTS-REDO, DEC-013, DEC-038, DEC-048).
                 Closed by default; the Hud mounts it only while open. Centred on a Page,
                 closed by its own X or by the Quests button. Displays the daily quests with
                 progress bar, reward pills, Claim button for completed quests, and Reroll button.
    Props:
    - OnClose: Called after the closing animation; the Hud unmounts the card.
    - CloseRef: Optional ref the card fills with its animated close function.
    - Quests: Optional preset quests (stories / previews).
    - Embedded: Render only the scrolling list, filling its parent (Menu Quests tab).
--]]

--!nonstrict

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

local Styles = require(UI.Styles)
local Pane = require(UI.Components.Pane)
local Page = require(UI.Components.Core.Page)
local CloseButton = require(UI.Components.Buttons.CloseButton)
local QuestConfig = require(Shared.Configuration.QuestConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local usePx = require(UI.Hooks.usePx)
local useCamera = require(UI.Hooks.useCamera)

export type QuestEntry = QuestConfig.QuestEntry

---> Private

local c = React.createElement

-- Mirrors App.luau PAGE_SWAP_DELAY: lets the close spring start before unmounting.
local CLOSE_DELAY = 0.025

-- Page.luau scales its content to GOAL_SCALE (0.8); touch targets are authored at
-- 56 so they stay >= 44 px effective.
local ACTION_HEIGHT = 56
local ACTION_WIDTH = 104
local HEADER_HEIGHT = 60
local CARD_WIDTH = 330
-- Page pane is 0.8 of the screen; the scrolling body may use 0.65 of it.
local PAGE_SCREEN_FRACTION = 0.8
local BODY_MAX_FRACTION = 0.65
-- CloseButton lays itself out as fractions of its parent (0.0919732 x 0.123874 of the
-- menu, centred at 0.980770, 0.147523). A transparent frame sized so the button is
-- CLOSE_SIZE square lets it sit in the header without changing the shared component.
local CLOSE_SIZE = 56
local CLOSE_BUTTON_W = 0.0919732
local CLOSE_BUTTON_H = 0.123874
local CLOSE_BUTTON_X = 0.980770
local CLOSE_BUTTON_Y = 0.147523

local PREVIEW_WEEKLY_QUESTS: { QuestEntry } = {
	{
		Id = "preview_w1",
		Type = "CustomersServed",
		Target = 30,
		Progress = 12,
		Completed = false,
		Claimed = false,
		RewardBobaBucks = 0,
		RewardXP = 0,
		RewardCapsule = "Regular Pet Capsule",
	},
	{
		Id = "preview_w2",
		Type = "ShiftsCompleted",
		Target = 5,
		Progress = 5,
		Completed = true,
		Claimed = false,
		RewardBobaBucks = 0,
		RewardXP = 0,
		RewardCapsule = "Regular Pet Capsule",
	},
}

local PREVIEW_QUESTS: { QuestEntry } = {
	{
		Id = "preview_1",
		Type = "BobaOrdered",
		Target = 5,
		Progress = 3,
		Completed = false,
		Claimed = false,
		RewardBobaBucks = 50,
		RewardXP = 25,
	},
	{
		Id = "preview_2",
		Type = "CustomersServed",
		Target = 10,
		Progress = 10,
		Completed = true,
		Claimed = false,
		RewardBobaBucks = 60,
		RewardXP = 30,
	},
	{
		Id = "preview_3",
		Type = "SpillsCleaned",
		Target = 4,
		Progress = 4,
		Completed = true,
		Claimed = true,
		RewardBobaBucks = 40,
		RewardXP = 20,
	},
}

local function checkFreeRerolls(): number
	local ok, dataController = pcall(function()
		return Knit.GetController("DataController")
	end)
	if ok and dataController and dataController.LocalPlayerData then
		local quests = dataController.LocalPlayerData.Quests
		if quests and typeof(quests.FreeRerollsRemaining) == "number" then
			return quests.FreeRerollsRemaining
		end
	end

	local passOk, owns = pcall(function()
		return GamepassUtil:PlayerOwnsPassAsync(Players.LocalPlayer, QuestConfig.FREE_REROLL_PASS)
	end)
	if passOk and owns == true then
		return 1
	end
	return 0
end

local function QuestActionButton(props: {
	Text: string,
	Color: Color3,
	TextColor: Color3?,
	Size: UDim2?,
	LayoutOrder: number?,
	Disabled: boolean?,
	OnClick: (() -> ())?,
})
	local px = usePx()
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local isDisabled = props.Disabled == true

	local springs = ReactSpring.useSpring({
		scale = (not isDisabled and isPressing) and 0.95 or ((not isDisabled and isHovering) and 1.05 or 1.0),
		config = Styles.SPRING_STANDARD,
	})

	local baseColor = props.Color
	local strokeColor = baseColor:Lerp(Color3.new(0, 0, 0), 0.15)

	return c(Pane, {
		ClassName = "TextButton",
		CornerRadius = Styles.CORNER_BUTTON,
		Scale = springs.scale,
		OnClick = if isDisabled then nil else props.OnClick,
		OnPress = function()
			if not isDisabled then
				setIsPressing(true)
			end
		end,
		OnRelease = function()
			if not isDisabled then
				setIsPressing(false)
			end
		end,
		OnHover = function()
			if not isDisabled then
				setIsHovering(true)
			end
		end,
		OnLeave = function()
			setIsHovering(false)
			setIsPressing(false)
		end,
		Stroke = {
			Color = strokeColor,
			Thickness = 1,
		},
		Native = {
			Active = not isDisabled,
			AnchorPoint = Vector2.new(1, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = baseColor,
			BackgroundTransparency = if isDisabled then 0.5 else 0,
			LayoutOrder = props.LayoutOrder,
			Position = UDim2.fromScale(1, 0.5),
			Size = props.Size or UDim2.fromOffset(px(ACTION_WIDTH), px(ACTION_HEIGHT)),
			Text = "",
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = px(18),
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.8),
				Text = props.Text,
				TextColor3 = props.TextColor or Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			},
		}),
	})
end

local function QuestRow(props: {
	index: number,
	quest: QuestEntry,
	hasFreeReroll: boolean,
	isActing: boolean,
	onClaim: (index: number) -> (),
	onReroll: (index: number) -> (),
	order: number?,
	showReroll: boolean?,
})
	local px = usePx()
	local quest = props.quest
	local actionWidth = px(ACTION_WIDTH)
	local actionHeight = px(ACTION_HEIGHT)
	local sideWidth = actionWidth + px(8)
	local title = QuestConfig.GetQuestTitle(quest)
	local progress = math.clamp(quest.Progress or 0, 0, quest.Target or 1)
	local target = math.max(1, quest.Target or 1)
	local progressFraction = math.clamp(progress / target, 0, 1)
	local rewardText = if quest.RewardCapsule ~= nil
		then "+1 Pet Capsule"
		else string.format("+%d BB · +%d XP", quest.RewardBobaBucks or 0, quest.RewardXP or 0)

	local topRow = c("Frame", {
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.new(1, -(px(110) + px(8)), 0, 0),
			Text = title,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = px(18),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		RewardPill = c("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Styles.GOLD_MID,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(px(110), px(24)),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Stroke = c("UIStroke", {
				Color = Styles.GOLD_DEEP,
				Thickness = 1,
				Transparency = 0.4,
			}),
			Label = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.8),
				Text = rewardText,
				TextColor3 = Styles.GOLD_DEEP,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}, {
				TextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(14) }),
			}),
		}),
	})

	local actionElement
	if quest.Claimed then
		actionElement = c("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(actionWidth, actionHeight),
			Text = "Claimed",
			TextColor3 = Styles.GRAY,
			TextSize = px(18),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	elseif quest.Completed then
		actionElement = c(QuestActionButton, {
			Text = "Claim",
			Color = Styles.GREEN,
			Size = UDim2.fromOffset(actionWidth, actionHeight),
			Disabled = props.isActing,
			OnClick = function()
				props.onClaim(props.index)
			end,
		})
	elseif props.showReroll == false then
		actionElement = c("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(actionWidth, actionHeight),
			Text = "Weekly",
			TextColor3 = Styles.GRAY,
			TextSize = px(18),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	else
		-- UI-REVISION: the button names its action ("20 BB" alone read like a second
		-- reward pill) and is not GOLD (FEEDBACK-VOICE 5: gold is money/rank, not buttons).
		actionElement = c(QuestActionButton, {
			Text = if props.hasFreeReroll then "Free\nReroll" else `Reroll\n{QuestConfig.REROLL_COST_BOBABUCKS} BB`,
			Color = Styles.GREEN_LIGHT,
			TextColor = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(actionWidth, actionHeight),
			Disabled = props.isActing,
			OnClick = function()
				props.onReroll(props.index)
			end,
		})
	end

	local bottomRow = c("Frame", {
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, actionHeight),
	}, {
		ProgressBar = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Styles.GRAY,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, -sideWidth, 0, px(24)),
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = if quest.Completed then Styles.GREEN else Styles.GREEN_LIGHT,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(progressFraction, 1),
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			}),
			Label = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = string.format("%d / %d", progress, target),
				TextColor3 = Styles.OFFWHITE,
				TextSize = px(15),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.5,
				ZIndex = 2,
			}),
		}),

		Action = actionElement,
	})

	return c("Frame", {
		LayoutOrder = props.order or props.index * 2,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
	}, {
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, px(8)),
			PaddingBottom = UDim.new(0, px(8)),
		}),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, px(4)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Top = topRow,
		Bottom = bottomRow,
	})
end

local function QuestCardBody(props: {
	Quests: { QuestEntry }?,
	WeeklyQuests: { QuestEntry }?,
	Embedded: boolean?,
	OnCloseRequested: () -> (),
})
	local px = usePx()
	local camera = useCamera()
	local initialQuests = props.Quests or (if not RunService:IsRunning() then PREVIEW_QUESTS else {})
	local quests, setQuests = React.useState(initialQuests :: { QuestEntry })
	local initialWeekly = props.WeeklyQuests or (if not RunService:IsRunning() then PREVIEW_WEEKLY_QUESTS else {})
	local weeklyQuests, setWeeklyQuests = React.useState(initialWeekly :: { QuestEntry })
	local freeRerolls, setFreeRerolls = React.useState(0)
	local isActing, setIsActing = React.useState(false)

	if RunService:IsRunning() then
		React.useEffect(function()
			local questService = Knit.GetService("QuestService")

			local function handleQuests(newQuests)
				if typeof(newQuests) == "table" then
					setQuests(newQuests)
					setFreeRerolls(checkFreeRerolls())
				end
			end

			local function handleWeeklyQuests(newQuests)
				if typeof(newQuests) == "table" then
					setWeeklyQuests(newQuests)
				end
			end

			local res = questService:GetQuests()
			if typeof(res) == "table" and res.andThen then
				res:andThen(handleQuests)
			elseif typeof(res) == "table" then
				handleQuests(res)
			end

			local weeklyRes = questService:GetWeeklyQuests()
			if typeof(weeklyRes) == "table" and weeklyRes.andThen then
				weeklyRes:andThen(handleWeeklyQuests)
			elseif typeof(weeklyRes) == "table" then
				handleWeeklyQuests(weeklyRes)
			end

			setFreeRerolls(checkFreeRerolls())

			local ok, dataController = pcall(function()
				return Knit.GetController("DataController")
			end)
			if ok and dataController and dataController.GetDataAsync then
				dataController:GetDataAsync():andThen(function()
					setFreeRerolls(checkFreeRerolls())
				end)
			end

			local conn = questService.QuestsUpdated:Connect(handleQuests)
			local weeklyConn = questService.WeeklyQuestsUpdated:Connect(handleWeeklyQuests)

			return function()
				conn:Disconnect()
				weeklyConn:Disconnect()
			end
		end, {})
	end

	local handleClaim = React.useCallback(function(index: number)
		if isActing or not RunService:IsRunning() then
			return
		end
		setIsActing(true)
		local claimedEntry = quests[index]
		task.spawn(function()
			local ok, success, err = pcall(function()
				local questService = Knit.GetService("QuestService")
				local res = questService:ClaimQuest(index)
				if typeof(res) == "table" and res.await then
					local _, s, e = res:await()
					return s, e
				end
				return res
			end)
			setIsActing(false)
			if not ok or success == false then
				warn("[QuestCard] Claim failed:", err)
			elseif claimedEntry then
				pcall(function()
					local text = "Quest claimed!"
					local bucks = claimedEntry.RewardBobaBucks
					local xp = claimedEntry.RewardXP
					local hasBucks = typeof(bucks) == "number" and bucks > 0
					local hasXp = typeof(xp) == "number" and xp > 0
					if hasBucks then
						text ..= " +" .. bucks .. " Boba Bucks"
					end
					if hasXp then
						text ..= (if hasBucks then " · +" else " +") .. xp .. " XP"
					end
					local dialogController = Knit.GetController("DialogController")
					if dialogController and dialogController.Toast then
						dialogController:Toast(text)
					end
				end)
			end
		end)
	end, { isActing, quests })

	local handleReroll = React.useCallback(function(index: number)
		if isActing or not RunService:IsRunning() then
			return
		end
		setIsActing(true)
		task.spawn(function()
			local ok, success, err = pcall(function()
				local questService = Knit.GetService("QuestService")
				local res = questService:RerollQuest(index)
				if typeof(res) == "table" and res.await then
					local _, s, e = res:await()
					return s, e
				end
				return res
			end)
			setIsActing(false)
			if ok and success == false and err == "InsufficientFunds" then
				pcall(function()
					local dialogController = Knit.GetController("DialogController")
					if dialogController and dialogController.Toast then
						dialogController:Toast("Not enough Boba Bucks to reroll!")
					end
				end)
			end
			setFreeRerolls(checkFreeRerolls())
		end)
	end, { isActing })

	local handleWeeklyClaim = React.useCallback(function(index: number)
		if isActing or not RunService:IsRunning() then
			return
		end
		setIsActing(true)
		local claimedEntry = weeklyQuests[index]
		task.spawn(function()
			local ok, success, err = pcall(function()
				local questService = Knit.GetService("QuestService")
				local res = questService:ClaimWeeklyQuest(index)
				if typeof(res) == "table" and res.await then
					local _, s, e = res:await()
					return s, e
				end
				return res
			end)
			setIsActing(false)
			if not ok or success == false then
				warn("[QuestCard] Weekly claim failed:", err)
				if err == "InventoryFull" then
					pcall(function()
						local dialogController = Knit.GetController("DialogController")
						if dialogController and dialogController.Toast then
							dialogController:Toast("Capsule storage is full!")
						end
					end)
				end
			elseif claimedEntry then
				pcall(function()
					local text = "Weekly quest claimed!"
					if claimedEntry.RewardCapsule ~= nil then
						text ..= " +1 " .. claimedEntry.RewardCapsule
					end
					local dialogController = Knit.GetController("DialogController")
					if dialogController and dialogController.Toast then
						dialogController:Toast(text)
					end
				end)
			end
		end)
	end, { isActing, weeklyQuests })

	local hasFreeReroll = freeRerolls > 0
	local isEmpty = RunService:IsRunning() and #quests == 0

	local questItems = {}
	for index, quest in quests do
		if index > 1 then
			questItems["Divider_" .. index] = c("Frame", {
				LayoutOrder = index * 2 - 1,
				BackgroundColor3 = Styles.GRAY,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
			})
		end
		questItems["Quest_" .. index] = c(QuestRow, {
			index = index,
			quest = quest,
			hasFreeReroll = hasFreeReroll,
			isActing = isActing,
			onClaim = handleClaim,
			onReroll = handleReroll,
		})
	end

	-- Weekly section reusing the same QuestRow component. Weekly quests
	-- cannot be rerolled, so the reroll button is replaced with a label.
	local WEEKLY_ORDER_BASE = 1000
	if #weeklyQuests > 0 then
		questItems["WeeklyHeader"] = c("TextLabel", {
			LayoutOrder = WEEKLY_ORDER_BASE,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.fromScale(1, 0),
			Text = "Weekly Quests",
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = px(20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		for index, quest in weeklyQuests do
			questItems["WDivider_" .. index] = c("Frame", {
				LayoutOrder = WEEKLY_ORDER_BASE + index * 2 - 1,
				BackgroundColor3 = Styles.GRAY,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
			})
			questItems["WQuest_" .. index] = c(QuestRow, {
				index = index,
				order = WEEKLY_ORDER_BASE + index * 2,
				quest = quest,
				hasFreeReroll = false,
				isActing = isActing,
				showReroll = false,
				onClaim = handleWeeklyClaim,
				onReroll = handleReroll,
			})
		end
	end

	questItems.Padding = c("UIPadding", {
		PaddingTop = UDim.new(0, px(6)),
		PaddingBottom = UDim.new(0, px(8)),
		PaddingLeft = UDim.new(0, px(8)),
		PaddingRight = UDim.new(0, px(8)),
	})
	questItems.Layout = c("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, px(6)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	-- Page content is laid out in the Page pane's own pixel space (0.8 of the screen).
	local bodyMaxHeight = math.floor(camera.ViewportSize.Y * PAGE_SCREEN_FRACTION * BODY_MAX_FRACTION)

	local headerHeight = px(HEADER_HEIGHT)
	local closeSize = px(CLOSE_SIZE)

	local header = c("Frame", {
		LayoutOrder = 1,
		BackgroundColor3 = Styles.GREEN,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, headerHeight),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		BottomSquare = c("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 6),
		}),
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.new(0, px(10), 0.5, 0),
			Size = UDim2.new(1, -(closeSize + px(24)), 0.7, 0),
			Text = "Daily Quests",
			TextColor3 = Styles.OFFWHITE,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			TextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(22) }),
		}),
		-- Sized so the shared CloseButton (fraction-based) renders closeSize square, centred
		-- at the header's right end.
		CloseHolder = c("Frame", {
			AnchorPoint = Vector2.new(CLOSE_BUTTON_X, CLOSE_BUTTON_Y),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -(px(6) + closeSize / 2), 0.5, 0),
			Size = UDim2.fromOffset(closeSize / CLOSE_BUTTON_W, closeSize / CLOSE_BUTTON_H),
		}, {
			CloseButton = c(CloseButton, { OnClick = props.OnCloseRequested }),
		}),
	})

	local body
	if isEmpty then
		body = c("Frame", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, px(72)),
		}, {
			EmptyLabel = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.5),
				Text = "You don't have any quests!",
				TextColor3 = Styles.GREEN,
				TextScaled = true,
				TextTransparency = 0.4,
			}),
		})
	else
		body = c("ScrollingFrame", {
			LayoutOrder = 2,
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			AutomaticSize = if props.Embedded then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = if props.Embedded then UDim2.fromScale(1, 1) else UDim2.fromScale(1, 0),
		}, {
			SizeLimit = if props.Embedded
				then nil
				else c("UISizeConstraint", { MaxSize = Vector2.new(math.huge, bodyMaxHeight) }),
			Content = c("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
			}, questItems),
		})
	end

	if props.Embedded then
		return c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Body = body,
		})
	end

	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Styles.OFFWHITE,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = c("UIStroke", {
			Color = Styles.GREEN_DIM,
			Thickness = 1,
		}),
		WidthLimit = c("UISizeConstraint", { MaxSize = Vector2.new(px(CARD_WIDTH), math.huge) }),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = header,
		Body = body,
	})
end

---> Component

return function(props: {
	OnClose: (() -> ())?,
	CloseRef: { current: (() -> ())? }?,
	Quests: { QuestEntry }?,
	WeeklyQuests: { QuestEntry }?,
	Embedded: boolean?,
})
	local closeFnRef = React.useRef(nil)
	local onCloseRef = React.useRef(props.OnClose)
	onCloseRef.current = props.OnClose
	local isClosingRef = React.useRef(false)

	-- Stable identity: Page restarts its spring whenever PageContent changes.
	local handleClose = React.useCallback(function()
		if isClosingRef.current then
			return
		end
		isClosingRef.current = true
		if closeFnRef.current then
			closeFnRef.current()
		end
		task.spawn(function()
			task.wait(CLOSE_DELAY)
			if onCloseRef.current then
				onCloseRef.current()
			end
		end)
	end, {})

	React.useEffect(function()
		if props.CloseRef then
			props.CloseRef.current = handleClose
		end
		return function()
			if props.CloseRef and props.CloseRef.current == handleClose then
				props.CloseRef.current = nil
			end
		end
	end, { props.CloseRef })

	if props.Embedded then
		return c(QuestCardBody, {
			Quests = props.Quests,
			WeeklyQuests = props.WeeklyQuests,
			Embedded = true,
			OnCloseRequested = function() end,
		})
	end

	local pageContent = React.useMemo(function()
		return c(QuestCardBody, {
			Quests = props.Quests,
			WeeklyQuests = props.WeeklyQuests,
			OnCloseRequested = handleClose,
		})
	end, { props.Quests, props.WeeklyQuests })

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Page = c(Page, {
			IsVisible = true,
			PageContent = pageContent,
			OnClosing = function(cb)
				closeFnRef.current = cb
			end,
		}),
	})
end
