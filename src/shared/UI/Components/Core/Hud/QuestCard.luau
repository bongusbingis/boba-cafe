--[[
    Component: QuestCard
    Description: Daily Quests HUD card (REVIVAL-001 M4-UI-QUESTS, DEC-013, DEC-032).
                 Displays 3–4 daily quests with progress bar, reward pills,
                 Claim button for completed quests, and Reroll button.
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
local QuestConfig = require(Shared.Configuration.QuestConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

export type QuestEntry = QuestConfig.QuestEntry

---> Private

local c = React.createElement

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
			AutoButtonColor = false,
			BackgroundColor3 = baseColor,
			BackgroundTransparency = if isDisabled then 0.5 else 0,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromOffset(72, 20),
			Text = "",
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 12,
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
})
	local quest = props.quest
	local title = QuestConfig.GetQuestTitle(quest)
	local progress = math.clamp(quest.Progress or 0, 0, quest.Target or 1)
	local target = math.max(1, quest.Target or 1)
	local progressFraction = math.clamp(progress / target, 0, 1)

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
			Size = UDim2.new(1, -78, 0, 0),
			Text = title,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		RewardPill = c("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Styles.GOLD_MID,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(72, 16),
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
				Text = string.format("+%d BB · +%d XP", quest.RewardBobaBucks or 0, quest.RewardXP or 0),
				TextColor3 = Styles.GOLD_DEEP,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			}, {
				TextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 10 }),
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
			Size = UDim2.fromOffset(72, 20),
			Text = "Claimed",
			TextColor3 = Styles.GRAY,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	elseif quest.Completed then
		actionElement = c(QuestActionButton, {
			Text = "Claim",
			Color = Styles.GREEN,
			Size = UDim2.fromOffset(72, 20),
			Disabled = props.isActing,
			OnClick = function()
				props.onClaim(props.index)
			end,
		})
	else
		actionElement = c(QuestActionButton, {
			Text = if props.hasFreeReroll then "Free" else `{QuestConfig.REROLL_COST_BOBABUCKS} BB`,
			Color = if props.hasFreeReroll then Styles.GREEN_LIGHT else Styles.GOLD_MID,
			TextColor = if props.hasFreeReroll then Color3.new(1, 1, 1) else Styles.GOLD_DEEP,
			Size = UDim2.fromOffset(72, 20),
			Disabled = props.isActing,
			OnClick = function()
				props.onReroll(props.index)
			end,
		})
	end

	local bottomRow = c("Frame", {
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
	}, {
		ProgressBar = c("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Styles.GRAY,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, -78, 0, 16),
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
				TextSize = 11,
				TextStrokeColor3 = Color3.fromRGB(40, 40, 40),
				TextStrokeTransparency = 0.5,
				ZIndex = 2,
			}),
		}),

		Action = actionElement,
	})

	return c("Frame", {
		LayoutOrder = props.index * 2,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
	}, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Top = topRow,
		Bottom = bottomRow,
	})
end

---> Component

return function(props: {
	Quests: { QuestEntry }?,
	Preview: boolean?,
})
	local initialQuests = props.Quests or (if not RunService:IsRunning() then PREVIEW_QUESTS else {})
	local quests, setQuests = React.useState(initialQuests :: { QuestEntry })
	local isExpanded, setIsExpanded = React.useState(true)
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

			local res = questService:GetQuests()
			if typeof(res) == "table" and res.andThen then
				res:andThen(handleQuests)
			elseif typeof(res) == "table" then
				handleQuests(res)
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

			return function()
				conn:Disconnect()
			end
		end, {})
	end

	local handleClaim = React.useCallback(function(index: number)
		if isActing or not RunService:IsRunning() then
			return
		end
		setIsActing(true)
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
			end
		end)
	end, { isActing })

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

	if RunService:IsRunning() and #quests == 0 then
		return nil
	end

	local hasFreeReroll = freeRerolls > 0

	local header = c(Pane, {
		ClassName = "TextButton",
		LayoutOrder = 1,
		OnClick = function()
			setIsExpanded(function(prev)
				return not prev
			end)
		end,
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 28),
			Text = "",
		},
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		BottomSquare = if isExpanded
			then c("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Styles.GREEN,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 6),
			})
			else nil,
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.new(1, -40, 0.7, 0),
			Text = "Daily Quests",
			TextColor3 = Styles.OFFWHITE,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			TextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 15 }),
		}),
		Toggle = c("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 20, 0.7, 0),
			Text = if isExpanded then "▲" else "▼",
			TextColor3 = Styles.OFFWHITE,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, {
			TextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 14 }),
		}),
	})

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

	local listChildren = table.clone(questItems)
	listChildren.Padding = c("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	listChildren.Layout = c("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local listContainer = if isExpanded
		then c("Frame", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
		}, listChildren)
		else nil

	return c("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Styles.OFFWHITE,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.fromOffset(230, 0),
		ZIndex = 10,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = c("UIStroke", {
			Color = Styles.GREEN_DIM,
			Thickness = 1,
		}),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = header,
		List = listContainer,
	})
end
