--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	The stack collapses to a bucks-only tray via the Show More / Show Less
	handle; the hatching-capsule button lives outside the stack and stays put.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)
local RankUtil = require(Shared.Utility.RankUtil)

---> constants
local SKIP_HATCH_PRODUCT_ID = 1143554452
local HATCH_DURATION_SECONDS = 15 * 60
local BUTTON_SIZE = UDim2.fromScale(1, 1)
local CLOCKED_IN_ATTRIBUTE = "ClockedIn" -- owned by the server's ShiftService
local COUNT_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_SCALE = 1.07
local CLOCK_OUT_TITLE = "Clock Out?"
local CLOCK_OUT_TEXT = "Your shift progress is saved. Clock back in to pick up where you left off."

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)
local SmallNotification = require(script.Parent.SmallNotification)
local LevelBar = require(script.Parent.LevelBar)

---> private
local c = React.createElement
local atJoin = os.time()
local nextOrder = require(UI.Utility.nextOrderFunctionFactory)()

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

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local currency, setCurrency = React.useState({
		BobaBucks = 0,
		Points = 0,
	})

	local bucksPop, bucksPopApi = ReactSpring.useSpring(function()
		return { Scale = 1, config = Styles.SPRING_STANDARD }
	end)
	-- Collapse spring: the stack pops when the tray opens or shuts.
	local collapsed, setCollapsed = React.useState(false)
	local panelPop, panelPopApi = ReactSpring.useSpring(function()
		return { Scale = 1, config = Styles.SPRING_STANDARD }
	end)

	local function toggleCollapsed()
		setCollapsed(function(was)
			return not was
		end)
		panelPopApi.start({ from = { Scale = 0.94 }, to = { Scale = 1 }, config = Styles.SPRING_STANDARD })
	end
	local shownBucks, setShownBucks = React.useState(0)
	local prevBucksRef = React.useRef(nil :: number?)
	React.useEffect(function()
		local target = currency.BobaBucks
		local prev = prevBucksRef.current
		prevBucksRef.current = target
		if not RunService:IsRunning() then
			setShownBucks(target)
			return
		end
		if prev ~= nil and target > prev then
			bucksPopApi.start({ from = { Scale = POP_SCALE }, to = { Scale = 1 }, config = Styles.SPRING_STANDARD })
		end
		local counter = Instance.new("NumberValue")
		counter.Value = prev or 0
		local changed = counter.Changed:Connect(function(v)
			setShownBucks(math.floor(v + 0.5))
		end)
		local tween = TweenService:Create(counter, COUNT_TWEEN, { Value = target })
		tween:Play()
		return function()
			tween:Cancel()
			changed:Disconnect()
			counter:Destroy()
		end
	end, { currency.BobaBucks })

	local capsuleHatching, setCapsuleHatching = React.useState(nil)
	local hatchClockText, setHatchClockText = React.useState("00:00")
	local requestedReadyHatchRef = React.useRef(false)

	local rank, setRank = React.useState(0)
	local _shiftTimerEnabled, setShiftTimerEnabled = React.useState(false)
	local _shiftTimerText, setShiftTimerText = React.useState("00:00")

	-- Players start clocked in (ShiftService default), so assume that until the
	-- attribute replicates.
	local clockedIn, setClockedIn = React.useState(true)

	local isAdmin = rank > 10

	-- Shift k/N readout from the ShiftCount / ShiftTarget player attributes.
	local shiftCount, setShiftCount = React.useState(nil :: number?)
	local shiftTarget, setShiftTarget = React.useState(nil :: number?)
	if RunService:IsRunning() then
		React.useEffect(function()
			local player = game:GetService("Players").LocalPlayer
			local function refresh()
				setShiftCount(player:GetAttribute("ShiftCount"))
				setShiftTarget(player:GetAttribute("ShiftTarget"))
			end
			refresh()
			local countConn = player:GetAttributeChangedSignal("ShiftCount"):Connect(refresh)
			local targetConn = player:GetAttributeChangedSignal("ShiftTarget"):Connect(refresh)
			return function()
				countConn:Disconnect()
				targetConn:Disconnect()
			end
		end, {})
	end

	local function sendClockedIn(wantClockedIn: boolean)
		-- The server sets the attribute; the listener below updates the button.
		task.spawn(function()
			local ok, err = pcall(function()
				Knit.GetService("ShiftService"):SetClockedIn(wantClockedIn)
			end)
			if not ok then
				warn("[BottomLeft] Clock in/out request failed:", err)
			end
		end)
	end

	local function toggleClockedIn()
		local wantClockedIn = not clockedIn
		if not RunService:IsRunning() then
			setClockedIn(wantClockedIn) -- story preview
			return
		end
		if clockedIn then
			local prompt = Knit.GetController("DialogController").new("ButtonPrompt", {
				Title = CLOCK_OUT_TITLE,
				Text = CLOCK_OUT_TEXT,
				Buttons = {
					{ Text = "Clock Out", Color = Styles.GOLD_MID },
					{ Text = "Cancel", Color = Styles.RED },
				},
			})
			prompt:Fire():andThen(function(choice)
				if choice == "Clock Out" then
					sendClockedIn(false)
				end
			end)
			return
		end
		sendClockedIn(true)
	end

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
			local player = Players.LocalPlayer
			local function syncClockedIn()
				setClockedIn(player:GetAttribute(CLOCKED_IN_ATTRIBUTE) ~= false)
			end
			syncClockedIn()

			local connection = player:GetAttributeChangedSignal(CLOCKED_IN_ATTRIBUTE):Connect(syncClockedIn)
			return function()
				connection:Disconnect()
			end
		end, {})

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
			CapsuleButton = capsuleHatching and capsuleHatching ~= false and c(Pane, {
				ClassName = "ImageButton",
				AspectRatio = 1,
				OnClick = function()
					-- DEC-006: Skip Hatch is only purchasable while a pet is hatching.
					if not capsuleHatching or capsuleHatching == false then
						return
					end
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
				Scale = panelPop.Scale,
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

				LevelBar = not collapsed and c(LevelBar.Component, { LayoutOrder = -1 }) or nil,

				ShiftTimer = not collapsed and clockedIn and shiftCount ~= nil and shiftTarget ~= nil and c(
					NormalButton,
					{
						Icon = "rbxassetid://8184068342",
						Size = BUTTON_SIZE,
						Color = Styles.ROSE_MID,
						Text = `Shift {shiftCount}/{shiftTarget}`,
						LayoutOrder = 0,
					}
				) or nil,

				Shift = not collapsed and c(NormalButton, {
					Size = BUTTON_SIZE,
					Color = if clockedIn then Styles.GOLD_MID else Styles.GREEN_MID,
					Text = if clockedIn then "Clock Out" else "Clock In",
					OnClick = toggleClockedIn,
					LayoutOrder = 1,
				}) or nil,

				Recipes = not collapsed and c(NormalButton, {
					Icon = "",
					Size = BUTTON_SIZE,
					Color = Styles.ROSE_DEEP,
					Text = "Recipe Book",
					OnClick = function()
						props.SetCurrentPage(UI.Pages.Recipes)
					end,
					LayoutOrder = 2,
				}) or nil,

				Invite = not collapsed and c(NormalButton, {
					Icon = "",
					Size = BUTTON_SIZE,
					Color = Styles.GREEN_MID,
					Text = "Invite Friends",
					OnClick = function()
						pcall(function()
							local SocialService = game:GetService("SocialService")
							SocialService:PromptGameInvite(Players.LocalPlayer)
						end)
					end,
					LayoutOrder = 3,
				}) or nil,

				BucksWrap = c(Pane, {
					ClassName = "Frame",
					Scale = bucksPop.Scale,
					AspectRatio = 7, -- NormalButton wrapper ratio
					Native = { BackgroundTransparency = 1, Size = BUTTON_SIZE, LayoutOrder = 4 },
				}, {
					Bucks = c(NormalButton, {
						PlusButton = true,
						Icon = "rbxassetid://13382286492",
						Position = UDim2.fromScale(0.5, 0.5), -- wrapper is anchored (0.5,0.5)
						Size = UDim2.fromScale(1, 1),
						Color = Styles.GREEN_LIGHT,
						Text = shownBucks,
						OnClick = function()
							props.SetCurrentPage(UI.Pages.Shop, "Currency")
						end,
					}),
				}),

				-- Collapse handle: shuts the stack down to a bucks-only tray.
				CollapseToggle = c(NormalButton, {
					Size = BUTTON_SIZE,
					Color = if collapsed then Styles.GREEN_DIM else Styles.GRAY,
					Text = if collapsed then "Show More" else "Show Less",
					OnClick = toggleCollapsed,
					LayoutOrder = 5,
				}),
			}),
		}),
	})
end
