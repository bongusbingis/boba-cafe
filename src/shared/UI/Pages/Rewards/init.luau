--[[
    Page: Rewards
    Description: The daily login reward cycle — one tile per day, showing which are
    claimed, which is claimable now, and how long until the next one.

    Backed by DailyRewardsService:GetState / :Claim.

    Uses OpenableMenu so the title tab, close button, bordered base and background
    pattern match Menu/Shop/Inventory exactly; this page only supplies inner content.
--]]

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
local OpenableMenu = require(UI.Components.Core.OpenableMenu)

---> hooks
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

--- Tile geometry in pre-scale pixels. Fixed dimensions rather than a fraction of the row
--- so the tiles keep a portrait shape on every viewport; dividing the row width by seven
--- is what made them stretch into slivers.
local TILE_WIDTH = 78
local TILE_HEIGHT = 132
local MILESTONE_WIDTH = 104
local TILE_GAP = 6

local function formatWait(seconds: number): string
	local remaining = math.max(0, math.floor(seconds or 0))

	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)

	if hours > 0 then
		return `Next reward in {hours}h {minutes}m`
	end
	if minutes > 0 then
		return `Next reward in {minutes}m`
	end
	return "Next reward available soon"
end

---> public
return function(props)
	local px = usePx()

	-- nil = loading, table = loaded
	local state, setState = React.useState(nil)
	local claiming, setClaiming = React.useState(false)

	local refresh = React.useCallback(function()
		task.spawn(function()
			local service = Knit.GetService("DailyRewardsService")
			local ok, result = service:GetState():await()
			if ok and result then
				setState(result)
			end
		end)
	end, {})

	React.useEffect(function()
		refresh()

		local service = Knit.GetService("DailyRewardsService")
		local claimed = service.RewardClaimed:Connect(refresh)

		return function()
			claimed:Disconnect()
		end
	end, { refresh })

	local function claim()
		if claiming or not state or not state.CanClaim then
			return
		end

		setClaiming(true)
		task.spawn(function()
			Knit.GetService("DailyRewardsService"):Claim():await()
			setClaiming(false)
			refresh()
		end)
	end

	---> One row of day tiles. Tiles are sized in scaled pixels rather than as a fraction
	---> of the row, so they keep a fixed portrait shape instead of stretching to fill.
	---> The final day is the milestone and gets a wider, highlighted tile — the pattern
	---> every reference uses to mark the payoff day.
	local tileChildren: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, px(TILE_GAP)),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	local cycle = state and state.Cycle or {}

	for day, entry in cycle do
		local isClaimed = day <= (state.CurrentDay or 0)
		local isClaimable = day == state.NextDay and state.CanClaim
		local isMilestone = day == #cycle

		-- Three unambiguous states: claimed recedes, claimable is the brightest thing on
		-- the page, upcoming is plain.
		local accent = if isClaimable
			then Styles.GOLD
			elseif isClaimed then Styles.GREEN_BADGE
			elseif isMilestone then Styles.GOLD_MID
			else Styles.GREEN_LIGHT

		tileChildren[`Day{day}`] = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = { Color = accent, Thickness = if isClaimable then 4 else 2 },
			Native = {
				BackgroundColor3 = if isClaimable
					then Styles.CREAM
					elseif isMilestone then Styles.CREAM
					else Styles.OFFWHITE,
				BackgroundTransparency = if isClaimed then 0.45 else 0,
				LayoutOrder = day,
				Size = UDim2.fromOffset(px(if isMilestone then MILESTONE_WIDTH else TILE_WIDTH), px(TILE_HEIGHT)),
			},
		}, {
			DayLabel = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0, 0.07),
					Size = UDim2.fromScale(1, 0.15),
					Text = if isMilestone then "Day 7 ★" else `Day {day}`,
					-- Dark on light throughout; the old mix put pale text on pale tiles.
					TextColor3 = if isClaimable then Styles.GOLD_DEEP else Styles.GREEN_DEEP,
					TextScaled = true,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(18) }),
			}),

			Icon = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Image = entry.Icon,
					ImageTransparency = if isClaimed then 0.55 else 0,
					Position = UDim2.fromScale(0.5, 0.26),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.62, 0.34),
				},
			}),

			Amount = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.05, 0.63),
					Size = UDim2.fromScale(0.9, 0.18),
					Text = entry.Description,
					TextColor3 = Styles.GREEN_DEEP,
					TextScaled = true,
				},
			}, {
				UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(22) }),
			}),

			---> state pill, so claimed/ready is legible at a glance
			StatePill = if isClaimed or isClaimable
				then c(Pane, {
					ClassName = "Frame",
					CornerRadius = Styles.CORNER_FULL,
					Native = {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = if isClaimed then Styles.GREEN_BADGE else Styles.GOLD,
						BackgroundTransparency = 0,
						Position = UDim2.fromScale(0.5, 0.96),
						Size = UDim2.fromScale(0.86, 0.16),
					},
				}, {
					Label = c(Pane, {
						ClassName = "TextLabel",
						Native = {
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							Size = UDim2.fromScale(1, 1),
							Text = if isClaimed then "Claimed" else "Ready!",
							-- Dark text on both pill colours; white was illegible on gold.
							TextColor3 = if isClaimed then Styles.OFFWHITE else Styles.GOLD_DEEP,
							TextScaled = true,
						},
					}, {
						UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = px(14) }),
					}),
				})
				else nil,
		})
	end

	local canClaim = state ~= nil and state.CanClaim and not claiming

	local content = c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		Heading = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.02),
				Size = UDim2.fromScale(1, 0.1),
				Text = "Daily Rewards",
				TextColor3 = Styles.GREEN,
				TextScaled = true,
			},
		}),

		Subtitle = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.13),
				Size = UDim2.fromScale(1, 0.055),
				Text = if state
					then `Claim one reward each day — {state.TotalDays or 0} claimed so far.`
					else "",
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
			},
		}),

		-- Shorter band than before: at 7 across, a tall container made each tile a thin
		-- vertical sliver.
		-- Row height matches the fixed tile height so the strip neither clips nor leaves
		-- a band of dead space around it.
		Tiles = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.48),
				Size = UDim2.new(1, 0, 0, px(TILE_HEIGHT)),
			},
		}, tileChildren),

		ClaimButton = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_PILL,
			-- No white stroke: on the grey waiting state it haloed the white label into
			-- an unreadable smear.
			Stroke = { Color = if canClaim then Styles.GOLD_DEEP else Styles.GREEN_DEEP, Thickness = 2 },
			OnClick = claim,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				Active = canClaim,
				AutoButtonColor = canClaim,
				BackgroundColor3 = if canClaim then Styles.GOLD else Styles.CREAM,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.97),
				-- Wider when it holds a countdown sentence rather than the word "Claim".
				Size = if canClaim then UDim2.fromScale(0.3, 0.12) else UDim2.fromScale(0.46, 0.12),
				Text = if state == nil
					then "Loading..."
					elseif claiming then "Claiming..."
					elseif state.CanClaim then "Claim"
					else formatWait(state.SecondsRemaining),
				-- Dark text on both states; white on gold and white-on-grey both failed.
				TextColor3 = if canClaim then Styles.GOLD_DEEP else Styles.GREEN_DEEP,
				TextScaled = true,
			},
		}, {
			-- Stops the label ballooning on wide screens.
			UITextSizeConstraint = c("UITextSizeConstraint", {
				MaxTextSize = px(34),
			}),
			UIPadding = c("UIPadding", {
				PaddingBottom = UDim.new(0, px(4)),
				PaddingLeft = UDim.new(0, px(12)),
				PaddingRight = UDim.new(0, px(12)),
				PaddingTop = UDim.new(0, px(4)),
			}),
		}),
	})

	return c(OpenableMenu, {
		TitleText = "Rewards",
		TitleColor = Styles.GOLD_MID,
		Pages = {
			{
				Key = "Daily",
				Label = "Daily",
				LayoutOrder = 1,
				Content = { Page = content },
				ButtonColor = Styles.GOLD_MID,
				ButtonTextColor = Styles.GOLD_DEEP,
			},
		},
		OnClose = function()
			props.ClosePage()
		end,
	})
end
