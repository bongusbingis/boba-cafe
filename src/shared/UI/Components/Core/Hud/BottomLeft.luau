--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)
local RankUtil = require(Shared.Utility.RankUtil)

---> constants
local SKIP_HATCH_PRODUCT_ID = 1143554452
local HATCH_DURATION_SECONDS = 15 * 60
local BUTTON_SIZE = UDim2.fromScale(1, 1)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)
local SmallNotification = require(script.Parent.SmallNotification)

---> private
local c = React.createElement

local function extractTimeLeft(s: string)
	local t: {} = s:split(":")
	local minutes: string = t[1]
	local seconds: string = t[2]
	local minutesNum = tonumber(minutes) or 0
	local secondsNum = tonumber(seconds) or 0
	return minutesNum * 60 + secondsNum
end

local function formatClock(totalSeconds: number)
	totalSeconds = math.max(0, totalSeconds)
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local atJoin = os.time()

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local currency, setCurrency = React.useState({
		BobaBucks = 0,
		Points = 0,
	})

	local capsuleHatching, setCapsuleHatching = React.useState(nil)
	local hatchClockText, setHatchClockText = React.useState("00:00")
	local requestedReadyHatchRef = React.useRef(false)

	local rank, setRank = React.useState(0)
	local shiftTimerEnabled, setShiftTimerEnabled = React.useState(false)
	local shiftTimerText, setShiftTimerText = React.useState("00:00")

	local isStaff = rank > 3
	local isAdmin = rank > 10

	React.useEffect(function()
		if not capsuleHatching or capsuleHatching == false then
			setHatchClockText("00:00")
			requestedReadyHatchRef.current = false
			return
		end

		local baseAccumulated = 0
		if typeof(capsuleHatching) == "table" and capsuleHatching.TimeAccumulated then
			baseAccumulated = capsuleHatching.TimeAccumulated
		end

		local function updateClock(elapsedInSession: number)
			local remaining = HATCH_DURATION_SECONDS - (baseAccumulated + elapsedInSession)
			setHatchClockText(formatClock(remaining))

			if remaining <= 0 and not requestedReadyHatchRef.current then
				requestedReadyHatchRef.current = true
				setCapsuleHatching(false)
				Knit.GetService("CapsuleService"):TryCompleteReadyHatch()
			end
		end

		updateClock(0)

		local this = task.spawn(function()
			local elapsedInSession = 0
			while true do
				elapsedInSession += 1
				updateClock(elapsedInSession)
				task.wait(1)
			end
		end)

		return function()
			task.cancel(this)
		end
	end, { capsuleHatching })

	React.useEffect(function()
		if not isAdmin then
			return
		end

		local this = task.spawn(function()
			while true do
				local elapsed = os.time() - atJoin
				setShiftTimerText(formatClock(elapsed))
				task.wait(1)
			end
		end)

		return function()
			task.cancel(this)
		end
	end, { rank })

	if RunService:IsRunning() then
		React.useEffect(function()
			setRank(RankUtil:GetRankAsync(Players.LocalPlayer))
			Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
				setCurrency(playerData.Currency)

				local currentHatching = playerData.HatchingPet
				if currentHatching and currentHatching ~= false then
					setCapsuleHatching(currentHatching)
				end

				-- task.spawn(function()
				-- 	while true do
				-- 		task.wait(1)
				-- 		if playerData.HatchingPet ~= false then
				-- 			setCapsuleHatching(playerData.HatchingPet)
				-- 		end
				-- 	end
				-- end)

				playerData:ListenToChange({ "HatchingPet" }, function(newValue)
					setCapsuleHatching(newValue or false)
				end)

				setShiftTimerEnabled(playerData.Settings.ShiftTimerEnabled)
				playerData:ListenToChange({ "Settings" }, function(newValue)
					setShiftTimerEnabled(newValue.ShiftTimerEnabled)
				end)

				playerData:ListenToChange({ "HatchingPet", "TimeAccumulated" }, function(newTimeAccumulated)
					if playerData.HatchingPet and playerData.HatchingPet ~= false then
						local current = playerData.HatchingPet
						setCapsuleHatching({
							CapsuleName = current.CapsuleName,
							TimeAccumulated = newTimeAccumulated,
						})
					end
				end)

				for type, _ in playerData.Currency do
					playerData:ListenToChange({ "Currency", type }, function(newValue: number)
						setCurrency(function(prev)
							local new = table.clone(prev)
							new[type] = newValue
							return new
						end)
					end)
				end
			end)
		end, {})
	end

	-- outer frame: vertical stack anchored at bottom-left
	-- LayoutOrder -6 notification sits above the horizontal button row
	return c(Pane, {
		ClassName = "Frame",
		AutomaticSize = Enum.AutomaticSize.Y,
		Native = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 0.985, 0),
			Size = UDim2.fromScale(0.3, 0),
			BackgroundTransparency = 1,
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
	}, {
		-- notification card springs in above the buttons (LayoutOrder -6)
		-- width is clamped to match the CurrencyPanel (0.5 scale of the 300px outer frame)
		-- Notification = c("Frame", {
		-- 	AutomaticSize = Enum.AutomaticSize.Y,
		-- 	BackgroundTransparency = 1,
		-- 	ClipsDescendants = false,
		-- 	LayoutOrder = -6,
		-- 	Size = UDim2.fromScale(0.6, 0),
		-- }, {
		-- 	c(SmallNotification.Component, {}),
		-- }),

		-- horizontal button row
		ButtonRow = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 60),
				LayoutOrder = 1,
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		}, {
			CapsuleButton = capsuleHatching and c(Pane, {
				ClassName = "ImageButton",
				AspectRatio = 1,
				OnClick = function()
					if extractTimeLeft(hatchClockText) <= 30 then
						return
					end
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, SKIP_HATCH_PRODUCT_ID)
				end,
				Native = {
					Image = "rbxassetid://6073658218",
					LayoutOrder = 2,
					Size = UDim2.fromScale(1.25, 1.25),
				},
			}, {
				c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.725),
					Size = UDim2.fromScale(0.85, 0.3),
					Text = hatchClockText,
					TextScaled = true,
					TextColor3 = Styles.OFFWHITE,
					ZIndex = 2,
				}, {
					UIStroke = c("UIStroke", {
						Color = Color3.new(0, 0, 0),
						Thickness = 2,
					}),
				}),
			}) or nil,

			CurrencyPanel = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					Padding = UDim.new(0.2, 0),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
				},
				Native = {
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.6, 1),
				},
			}, {
				Notification = c(SmallNotification.Component, {}),

				ShiftTimer = isAdmin and shiftTimerEnabled and c(NormalButton, {
					Icon = "rbxassetid://8184068342",
					Size = BUTTON_SIZE,
					Color = Styles.ROSE_MID,
					Text = shiftTimerText,
				}),

				Bucks = c(NormalButton, {
					PlusButton = true,
					Icon = "rbxassetid://13382286492",
					Size = BUTTON_SIZE,
					Color = Styles.GREEN_LIGHT,
					Text = currency.BobaBucks,
					OnClick = function()
						props.SetCurrentPage(UI.Pages.Shop, "Currency")
					end,
				}),

				Points = isStaff and c(NormalButton, {
					PlusButton = true,
					Icon = "rbxassetid://13391365805",
					Size = BUTTON_SIZE,
					Color = Styles.CORAL,
					Text = currency.Points,
					OnClick = function()
						props.SetCurrentPage(UI.Pages.Shop, "Currency")
					end,
				}),
			}),
		}),
	})
end
