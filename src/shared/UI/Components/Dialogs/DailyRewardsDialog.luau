--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Knit = require(Packages.Knit)
local Styles = require(UI.Styles)
local WorldPath = require(Shared.Utility.WorldPath)
local DailyRewardConfig = require(Shared.Configuration.DailyRewardConfig)

local Banner = require(UI.Components.Buttons.Banner)
local CloseButton = require(UI.Components.Buttons.CloseButton)
local Page = require(UI.Components.Core.Page)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)

local c = React.createElement

local BUCKS_ICON = "rbxassetid://13382286492"
local REGULAR_CAPSULE_ICON = "rbxassetid://6073658218"
local RARE_CAPSULE_ICON = "rbxassetid://7621095542"

export type DailyRewardsDialogProps = {
	Status: { [string]: any }?,
	OffsetX: number?,
	OnResolution: ((any) -> ())?,
	OnClose: (() -> ())?,
	Native: { [string]: any }?,
}

-- UI sounds are authored in the place (SoundService.SFX.UI, else SoundService.UISounds).
-- A missing sound is skipped.
local function playUiSound(name: string)
	local sound = WorldPath.find(SoundService, { "SFX", "UI", name })
		or WorldPath.find(SoundService, { "UISounds", name })
		or WorldPath.find(SoundService, { "SFX", name })
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function formatCountdown(totalSeconds: number): string
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local seconds = totalSeconds % 60
	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	else
		return string.format("%02d:%02d", minutes, seconds)
	end
end

return function(props: DailyRewardsDialogProps)
	local closeFnRef = React.useRef(nil)
	local status, setStatus = React.useState(props.Status)
	local isClaiming, setIsClaiming = React.useState(false)

	-- Sync status if props.Status changes
	React.useEffect(function()
		if props.Status then
			setStatus(props.Status)
		end
	end, { props.Status })

	-- If no status passed, query DailyRewardService on mount
	React.useEffect(function()
		if not status and RunService:IsRunning() then
			local ok, service = pcall(function()
				return Knit.GetService("DailyRewardService")
			end)
			if ok and service then
				service
					:GetRewardStatus()
					:andThen(function(latestStatus)
						if latestStatus then
							setStatus(latestStatus)
						end
					end)
					:catch(function(err)
						warn("[DailyRewardsDialog] Failed to fetch reward status:", err)
					end)
			end
		end
	end, {})

	-- Fallback status for offline preview / specs
	local currentStatus = status
		or {
			CanClaim = true,
			DayToClaim = 1,
			SecondsUntilNextClaim = 0,
			Expired = false,
			CurrentStreak = 0,
			LastClaimTime = 0,
			IsVIP = false,
			Reward = DailyRewardConfig.REWARDS[1],
			DataLoaded = true,
		}

	local secondsLeft, setSecondsLeft = React.useState(function()
		return currentStatus.SecondsUntilNextClaim or 0
	end)

	React.useEffect(function()
		if currentStatus then
			setSecondsLeft(currentStatus.SecondsUntilNextClaim or 0)
		end
	end, { currentStatus })

	-- Cooldown countdown timer
	React.useEffect(function()
		if not currentStatus or currentStatus.CanClaim or secondsLeft <= 0 then
			return
		end

		local running = true
		task.spawn(function()
			while running and secondsLeft > 0 do
				task.wait(1)
				if not running then
					break
				end
				setSecondsLeft(function(prev)
					if prev <= 1 then
						-- Cooldown expired; refresh status from server
						if RunService:IsRunning() then
							task.spawn(function()
								local ok, service = pcall(function()
									return Knit.GetService("DailyRewardService")
								end)
								if ok and service then
									local sOk, sStatus = service:GetRewardStatus():await()
									if sOk and sStatus then
										setStatus(sStatus)
									end
								end
							end)
						end
						return 0
					end
					return prev - 1
				end)
			end
		end)

		return function()
			running = false
		end
	end, { currentStatus.CanClaim, secondsLeft > 0 })

	local function handleClose()
		if closeFnRef.current then
			closeFnRef.current()
		end
		if props.OnResolution then
			props.OnResolution("Close")
		end
		if props.OnClose then
			props.OnClose()
		end
	end

	local function handleClaim()
		if isClaiming or not currentStatus.CanClaim then
			return
		end
		setIsClaiming(true)

		if not RunService:IsRunning() then
			-- Offline / story preview mode
			setIsClaiming(false)
			playUiSound("Success")
			setStatus(function(prev)
				local s = prev or currentStatus
				local nextStreak = s.DayToClaim
				return {
					CanClaim = false,
					DayToClaim = (nextStreak % 7) + 1,
					SecondsUntilNextClaim = DailyRewardConfig.CLAIM_COOLDOWN_SECONDS,
					CurrentStreak = nextStreak,
					LastClaimTime = os.time(),
					IsVIP = s.IsVIP,
					Reward = DailyRewardConfig.REWARDS[(nextStreak % 7) + 1],
					DataLoaded = true,
				}
			end)
			return
		end

		task.spawn(function()
			local ok, service = pcall(function()
				return Knit.GetService("DailyRewardService")
			end)
			if not ok or not service then
				setIsClaiming(false)
				return
			end

			local claimOk, reason, grantResult = service:ClaimReward():await()
			setIsClaiming(false)

			if claimOk then
				playUiSound("Success")

				setStatus(function(prev)
					local prevStatus = prev or currentStatus
					local nextStreak = grantResult and grantResult.Streak or prevStatus.DayToClaim
					return {
						CanClaim = false,
						DayToClaim = (nextStreak % 7) + 1,
						SecondsUntilNextClaim = DailyRewardConfig.CLAIM_COOLDOWN_SECONDS,
						CurrentStreak = nextStreak,
						LastClaimTime = os.time(),
						IsVIP = prevStatus.IsVIP,
						Reward = DailyRewardConfig.REWARDS[(nextStreak % 7) + 1],
						DataLoaded = true,
					}
				end)

				local bucksGranted = grantResult and grantResult.BobaBucks or 0
				local capsuleGranted = grantResult and grantResult.Capsule
				local toastText = `Claimed {bucksGranted} Boba Bucks!`
				if capsuleGranted then
					toastText = `Claimed {bucksGranted} Boba Bucks and {capsuleGranted}!`
				end

				local okController, dialogController = pcall(function()
					return Knit.GetController("DialogController")
				end)
				if okController and dialogController and dialogController.Toast then
					dialogController:Toast(toastText)
				end
			else
				warn("[DailyRewardsDialog] Claim failed:", reason)
			end
		end)
	end

	local canClaim = currentStatus.CanClaim == true
	local dayToClaim = currentStatus.DayToClaim or 1
	local streak = currentStatus.CurrentStreak or 0
	local isVIP = currentStatus.IsVIP == true
	local vipMultiplier = if isVIP then DailyRewardConfig.VIP_MULTIPLIER else 1

	-- Determine subtitle message
	local subtitleText
	if canClaim then
		subtitleText =
			`Streak: {streak} {if streak == 1 then "Day" else "Days"} • Claim today's Day {dayToClaim} reward!`
	elseif secondsLeft > 0 then
		subtitleText =
			`Streak: {streak} {if streak == 1 then "Day" else "Days"} • Next reward in {formatCountdown(secondsLeft)}`
	else
		subtitleText = `Streak: {streak} {if streak == 1 then "Day" else "Days"} • 7-Day Cycle Complete!`
	end

	-- Render 7 Day Cards
	local dayCards: { [string]: any } = {}
	for day = 1, 7 do
		local reward = DailyRewardConfig.REWARDS[day]
		local bucksAmount = if reward then reward.BobaBucks * vipMultiplier else 0
		local capsuleName = if reward then reward.Capsule else nil

		-- Status logic
		local isClaimed = false
		local isCurrent = false
		local isLocked = false

		if canClaim then
			if day < dayToClaim then
				isClaimed = true
			elseif day == dayToClaim then
				isCurrent = true
			else
				isLocked = true
			end
		else
			if (streak > 0 and (streak % 7 == 0)) or day <= (streak % 7) then
				isClaimed = true
			else
				isLocked = true
			end
		end

		local cardStrokeColor = Styles.GRAY
		local cardStrokeThickness = 1
		local dayLabelColor = Styles.GRAY

		if isCurrent then
			cardStrokeColor = Styles.GOLD
			cardStrokeThickness = 3.5
			dayLabelColor = Styles.GOLD_DEEP
		elseif isClaimed then
			cardStrokeColor = Styles.GRAY
			cardStrokeThickness = 1.5
			dayLabelColor = Styles.GREEN_DEEP
		end

		local capsuleImage = if day == 4 then REGULAR_CAPSULE_ICON else RARE_CAPSULE_ICON

		dayCards[`DayCard_{day}`] = c(Pane, {
			ClassName = if isCurrent and canClaim then "ImageButton" else "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = {
				Color = cardStrokeColor,
				Thickness = cardStrokeThickness,
			},
			Native = {
				BackgroundColor3 = if isCurrent then Styles.OFFWHITE else Color3.fromRGB(246, 246, 246),
				BackgroundTransparency = 0,
				LayoutOrder = day,
				Size = UDim2.fromScale(0.13, 0.98),
			},
			OnClick = if isCurrent and canClaim then handleClaim else nil,
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.015, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		}, {
			-- Day Header
			DayHeader = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.9, 0.14),
					Text = `Day {day}`,
					TextColor3 = dayLabelColor,
					TextScaled = true,
				},
			}),

			-- Main Graphic (Capsule for Day 4/7, Bucks icon for others)
			MainGraphic = c(Pane, {
				ClassName = "ImageLabel",
				AspectRatio = 1,
				Native = {
					BackgroundTransparency = 1,
					Image = if capsuleName then capsuleImage else BUCKS_ICON,
					ImageTransparency = if isLocked then 0.35 else 0,
					LayoutOrder = 2,
					Size = UDim2.fromScale(0.65, 0.30),
				},
			}),

			-- Capsule Label (if day has capsule)
			CapsuleLabel = capsuleName and c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 3,
					Size = UDim2.fromScale(0.95, 0.11),
					Text = if day == 4 then "Regular Capsule" else "Rare Capsule",
					TextColor3 = if isCurrent
						then Styles.GOLD_DEEP
						elseif isClaimed then Styles.GREEN_DEEP
						else Styles.GRAY,
					TextScaled = true,
				},
			}) or nil,

			-- BobaBucks Amount Row
			BucksRow = c(Pane, {
				ClassName = "Frame",
				Native = {
					BackgroundTransparency = 1,
					LayoutOrder = 4,
					Size = UDim2.fromScale(0.9, 0.13),
				},
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0.05, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
			}, {
				Icon = c(Pane, {
					ClassName = "ImageLabel",
					AspectRatio = 1,
					Native = {
						BackgroundTransparency = 1,
						Image = BUCKS_ICON,
						LayoutOrder = 1,
						Size = UDim2.fromScale(0.35, 0.85),
					},
				}),
				Amount = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = 2,
						Size = UDim2.fromScale(0.6, 0.9),
						Text = `+{bucksAmount}`,
						TextColor3 = if isCurrent
							then Styles.GOLD_DEEP
							elseif isClaimed then Styles.GREEN_DEEP
							else Styles.GRAY,
						TextScaled = true,
					},
				}),
			}),

			-- VIP 2x Multiplier Badge (if player has VIP)
			VipBadge = isVIP and c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_FULL,
				Native = {
					BackgroundColor3 = Styles.GOLD,
					BackgroundTransparency = 0,
					LayoutOrder = 5,
					Size = UDim2.fromScale(0.85, 0.1),
				},
			}, {
				VipText = c(Pane, {
					ClassName = "TextLabel",
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.95, 0.85),
						Text = "2x VIP",
						TextColor3 = Styles.OFFWHITE,
						TextScaled = true,
					},
				}),
			}) or nil,

			-- Status Footer (Claimed checkmark, Claim active, or Locked)
			StatusFooter = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 6,
					Size = UDim2.fromScale(0.9, 0.13),
					Text = if isClaimed then "✓ Claimed" elseif isCurrent then "Claim!" else "Locked",
					TextColor3 = if isClaimed then Styles.GREEN elseif isCurrent then Styles.GOLD_DEEP else Styles.GRAY,
					TextScaled = true,
				},
			}),
		})
	end

	-- Dialog modal container
	local modalContent = c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.7,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = {
			Color = Styles.GREEN_DIM,
			Thickness = 4,
		},
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Styles.OFFWHITE,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5 + (props.OffsetX or 0), 0.5),
			Size = UDim2.fromScale(0.85, 0.72),
			ZIndex = 60,
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(880, 520),
			MinSize = Vector2.new(520, 320),
		}),

		-- Header Banner with GREEN banner and OFFWHITE Fredoka text
		Header = c(Banner, {
			Text = "Daily Login Rewards",
			Color = Styles.GREEN,
			Position = UDim2.fromScale(0.5, 0.04),
			Size = UDim2.fromScale(0.65, 0.16),
		}),

		-- Close Button at top-right
		Close = c(CloseButton, {
			OnClick = handleClose,
		}),

		-- Subtitle indicating streak and claim status
		Subtitle = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.17),
				Size = UDim2.fromScale(0.9, 0.055),
				Text = subtitleText,
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
			},
		}),

		-- 7-Day Calendar Cards Row
		CardsContainer = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.53),
				Size = UDim2.fromScale(0.96, 0.56),
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.012, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		}, dayCards),

		-- Bottom Action Area with Claim button
		BottomBar = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.88),
				Size = UDim2.fromScale(0.42, 0.13),
			},
		}, {
			ClaimButton = if canClaim
				then c(PromptButton, {
					Text = `Claim Day {dayToClaim} Reward`,
					Color = Styles.GREEN,
					Size = UDim2.fromScale(1, 1),
					OnClick = handleClaim,
				})
				else c(PromptButton, {
					Text = if secondsLeft > 0 then `Next in {formatCountdown(secondsLeft)}` else "All Claimed!",
					Color = Styles.GRAY,
					Disabled = true,
					Size = UDim2.fromScale(1, 1),
				}),
		}),
	})

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Darkened backdrop overlay
		Backdrop = c(Pane, {
			ClassName = "TextButton",
			OnClick = handleClose,
			Native = {
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,
				Position = UDim2.fromOffset(0, -36),
				Size = UDim2.fromScale(5, 5),
				Text = "",
				ZIndex = 50,
			},
		}),

		-- Modal container wrapped in Page for spring physics
		ModalPage = c(Page, {
			IsVisible = true,
			PageContent = modalContent,
			OnClosing = function(cb)
				closeFnRef.current = cb
			end,
		}),
	})
end
