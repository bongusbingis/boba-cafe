local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared   = ReplicatedStorage:WaitForChild("Shared")
local UI       = Shared:WaitForChild("UI")

---> dependencies
local React       = require(Packages.React)
local Knit        = require(Packages.Knit)
local ReactSpring = require(Packages.ReactSpring)
local Promise     = require(Packages.Promise)

---> styles / config
local Styles         = require(UI.Styles)
local SettingsConfig = require(Shared.Configuration.SettingsConfig)
local RankUtil       = require(Shared.Utility.RankUtil)
local GamepassUtil   = require(Shared.Utility.GamepassUtil)

---> components / hooks
local Pane     = require(UI.Components.Pane)
local usePx    = require(UI.Hooks.usePx)
local useClock = require(UI.Hooks.useClock)

---> private
local c = React.createElement

local SPRING_CFG      = Styles.SPRING_STANDARD
local CATEGORY_COLOR  = Styles.GREEN_LIGHT
local SUBTITLE_COLOR  = Color3.fromRGB(210, 230, 200)

---> loading spinner (matches InventoryComponent)
local SPIN_PERIOD = 1.4
local function easeInOutBack(t: number): number
	local c1 = 1.70158
	local c2 = c1 * 1.525
	if t < 0.5 then
		return ((2 * t) ^ 2 * ((c2 + 1) * (2 * t) - c2)) / 2
	else
		local x = 2 * t - 2
		return (x ^ 2 * ((c2 + 1) * x + c2) + 2) / 2
	end
end

-- Same 9-slice header/footer assets used by ShopCategory
local HEADER_IMAGE = "http://www.roblox.com/asset/?id=13465572823"
local FOOTER_IMAGE = "http://www.roblox.com/asset/?id=13465749908"

-- ─────────────────────────────────────────────────────────────────────────────
--  Slider toggle  (spring-animated knob, green track = ON / gray = OFF)
-- ─────────────────────────────────────────────────────────────────────────────
local function Toggle(props: {
	Value: boolean,
	Disabled: boolean?,
	OnToggle: () -> (),
})
	local px = usePx()

	-- Elliptical knob: wider than tall, small vertical padding from track edges
	local TRACK_W  = px(80)
	local TRACK_H  = px(30)
	local KNOB_W   = px(34)
	local KNOB_H   = px(22)
	local KNOB_PAD = px(3)

	local knobOnX  = TRACK_W - KNOB_W - KNOB_PAD
	local knobOffX = KNOB_PAD

	-- Label areas: the half of the track not occupied by the knob
	-- OFF: label sits right of knob rest (x = KNOB_PAD + KNOB_W + KNOB_PAD)
	-- ON:  label sits left of knob rest  (x = KNOB_PAD)
	local labelAreaW = TRACK_W - KNOB_W - KNOB_PAD * 3
	local labelX     = if props.Value then KNOB_PAD else (KNOB_W + KNOB_PAD * 2)

	local trackOn  = CATEGORY_COLOR
	local trackOff = Color3.fromRGB(170, 170, 170)

	local styles = ReactSpring.useSpring({
		knobX      = if props.Value then knobOnX  else knobOffX,
		trackColor = if props.Value then trackOn  else trackOff,
		config     = SPRING_CFG,
	})

	return c("TextButton", {
		AutoButtonColor  = false,
		BackgroundColor3 = styles.trackColor,
		BorderSizePixel  = 0,
		Size             = UDim2.fromOffset(TRACK_W, TRACK_H),
		Text             = "",
		[React.Event.Activated] = if not props.Disabled then props.OnToggle else nil,
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),

		-- Elliptical sliding knob
		Knob = c("Frame", {
			AnchorPoint      = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel  = 0,
			Position         = styles.knobX:map(function(x)
				return UDim2.new(0, x, 0.5, 0)
			end),
			Size = UDim2.fromOffset(KNOB_W, KNOB_H),
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		-- ON / OFF label — anchored in the non-knob half, never overlaps knob
		Label = c("TextLabel", {
			AnchorPoint            = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace               = Styles.FONT_FREDOKA,
			Position               = UDim2.new(0, labelX, 0.5, 0),
			Size                   = UDim2.fromOffset(labelAreaW, TRACK_H * 0.6),
			Text                   = if props.Value then "ON" else "OFF",
			TextColor3             = Color3.new(1, 1, 1),
			TextScaled             = true,
			TextXAlignment         = Enum.TextXAlignment.Center,
		}),
	})
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Action button  (same outer dimensions as Toggle; white track, green pill)
-- ─────────────────────────────────────────────────────────────────────────────
local function ActionButton(props: {
	Label: string?,
	Disabled: boolean?,
	OnAction: () -> (),
})
	local px = usePx()

	local TRACK_W  = px(80)
	local TRACK_H  = px(30)
	local KNOB_H   = px(22)
	local KNOB_PAD = px(3)

	-- Green button spans the full knob travel range: left pad → right pad
	local btnW = TRACK_W - KNOB_PAD * 2

	return c("TextButton", {
		AutoButtonColor  = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel  = 0,
		Size             = UDim2.fromOffset(TRACK_W, TRACK_H),
		Text             = "",
		[React.Event.Activated] = if not props.Disabled then props.OnAction else nil,
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),

		Button = c("Frame", {
			AnchorPoint             = Vector2.new(0, 0.5),
			BackgroundColor3        = CATEGORY_COLOR,
			BackgroundTransparency  = if props.Disabled then 0.5 else 0,
			BorderSizePixel         = 0,
			Position                = UDim2.new(0, KNOB_PAD, 0.5, 0),
			Size                    = UDim2.fromOffset(btnW, KNOB_H),
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),

			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace               = Styles.FONT_FREDOKA,
				Size                   = UDim2.fromScale(1, 1),
				Text                   = props.Label or "",
				TextColor3             = Color3.new(1, 1, 1),
				TextTransparency       = if props.Disabled then 0.45 else 0,
				TextScaled             = true,
				TextXAlignment         = Enum.TextXAlignment.Center,
			}),
		}),
	})
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Single setting row — plain Frame (toggle or action button on the right)
-- ─────────────────────────────────────────────────────────────────────────────
local function SettingRow(props: {
	Label: string,
	-- Toggle settings
	Value: boolean?,
	OnToggle: (() -> ())?,
	-- Action settings
	OnAction: (() -> ())?,
	ActionLabel: string?,
	-- Shared
	Disabled: boolean?,
	LayoutOrder: number,
})
	local px = usePx()
	local itemColor = Styles.GREEN  -- matches ShopCategory's default item color
	local textAlpha = if props.Disabled then 0.45 else 0

	return c("Frame", {
		BackgroundColor3    = itemColor,
		BackgroundTransparency = 0,
		BorderSizePixel     = 0,
		LayoutOrder         = props.LayoutOrder,
		Size                = UDim2.fromScale(0.981, 0.065),
		SizeConstraint      = Enum.SizeConstraint.RelativeXX,
	}, {
		-- Setting name (left-aligned)
		Label = c("TextLabel", {
			AnchorPoint         = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace            = Styles.FONT_FREDOKA,
			Position            = UDim2.new(0, px(12), 0.5, 0),
			Size                = UDim2.fromScale(0.65, 0.57),
			Text                = props.Label,
			TextColor3          = Color3.new(1, 1, 1),
			TextTransparency    = textAlpha,
			TextScaled          = true,
			TextXAlignment      = Enum.TextXAlignment.Left,
		}),

		-- Toggle or action button (right-aligned)
		ControlHolder = c("Frame", {
			AnchorPoint         = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position            = UDim2.new(1, -px(12), 0.5, 0),
			Size                = UDim2.fromOffset(px(80), px(30)),
		}, {
			Control = if props.OnAction
				then c(ActionButton, {
					Label    = props.ActionLabel,
					Disabled = props.Disabled,
					OnAction = props.OnAction,
				})
				else c(Toggle, {
					Value    = props.Value,
					Disabled = props.Disabled,
					OnToggle = props.OnToggle,
				}),
		}),
	})
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Category card — ShopCategory-style header / rows / footer
-- ─────────────────────────────────────────────────────────────────────────────
local function SettingCategory(props: {
	Title: string,
	Settings: { any },
	Values: { [string]: boolean },
	PlayerRank: number,
	LayoutOrder: number,
	OnToggle: (key: string, newValue: boolean) -> (),
})
	local px = usePx()
	local gap = UDim.new(0, px(3))

	local rows: { [string]: any } = {
		Layout = c("UIListLayout", {
			Padding   = gap,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, setting in ipairs(props.Settings) do
		local isDisabled = setting.MinRank ~= nil and props.PlayerRank < setting.MinRank

		if setting.Type == "Action" then
			rows[setting.Key] = c(SettingRow, {
				Label       = setting.Label,
				ActionLabel = setting.ButtonLabel,
				Disabled    = isDisabled,
				LayoutOrder = i,
				OnAction    = if not isDisabled and setting.ClientCallback
					then setting.ClientCallback
					else nil,
			})
		else
			local value = if props.Values[setting.Key] ~= nil
				then props.Values[setting.Key]
				else setting.Default

			rows[setting.Key] = c(SettingRow, {
				Label       = setting.Label,
				Value       = value,
				Disabled    = isDisabled,
				LayoutOrder = i,
				OnToggle    = function()
					props.OnToggle(setting.Key, not value)
				end,
			})
		end
	end

	return c("Frame", {
		AutomaticSize          = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder            = props.LayoutOrder,
		Size                   = UDim2.fromScale(1, 0),
	}, {
		-- Consistent gap between header, rows, and footer
		Layout = c("UIListLayout", {
			Padding   = gap,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Header (slightly taller than ShopCategory to fit "SETTING" subtitle)
		Header = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image                  = HEADER_IMAGE,
				ImageColor3            = CATEGORY_COLOR,
				LayoutOrder            = 1,
				Size                   = UDim2.fromScale(0.981, 0.085),
				SizeConstraint         = Enum.SizeConstraint.RelativeXX,
				SliceCenter            = Rect.new(0, 0, 1019, 40),
			},
		}, {
			Title = c("TextLabel", {
				AnchorPoint         = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				FontFace            = Styles.FONT_FREDOKA,
				Position            = UDim2.fromOffset(px(14), px(6)),
				Size                = UDim2.new(1, -px(14), 0, px(30)),
				Text                = props.Title,
				TextColor3          = Color3.new(1, 1, 1),
				TextScaled          = true,
				TextXAlignment      = Enum.TextXAlignment.Left,
			}),

			Subtitle = c("TextLabel", {
				AnchorPoint         = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				FontFace            = Styles.FONT_FREDOKA,
				Position            = UDim2.fromOffset(px(14), px(38)),
				Size                = UDim2.new(1, -px(14), 0, px(13)),
				Text                = "SETTING",
				TextColor3          = SUBTITLE_COLOR,
				TextScaled          = false,
				TextSize            = px(11),
				TextXAlignment      = Enum.TextXAlignment.Left,
			}),
		}),

		-- Setting rows
		Rows = c("Frame", {
			AutomaticSize          = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder            = 2,
			Size                   = UDim2.fromScale(1, 0),
		}, rows),

		-- Footer
		Footer = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image                  = FOOTER_IMAGE,
				ImageColor3            = CATEGORY_COLOR,
				LayoutOrder            = 3,
				Size                   = UDim2.fromScale(0.981, 0.02),
				SizeConstraint         = Enum.SizeConstraint.RelativeXX,
			},
		}),
	})
end

-- ─────────────────────────────────────────────────────────────────────────────
--  Page root
-- ─────────────────────────────────────────────────────────────────────────────
return function()
	local settings, setSettings         = React.useState(nil :: { [string]: boolean }?)
	local playerRank, setPlayerRank     = React.useState(0)
	local ownedPassIds, setOwnedPassIds = React.useState({} :: { [number]: boolean })
	local isLoading, setIsLoading       = React.useState(true)
	local clockBinding                  = useClock()

	React.useEffect(function()
		local cancelled = false

		-- Collect every unique GamepassId up-front so the pass-check promise
		-- can be built before any async work starts.
		local uniqueIds: { number } = {}
		local seen: { [number]: boolean } = {}
		for _, category in ipairs(SettingsConfig) do
			for _, setting in ipairs(category.Settings) do
				if setting.GamepassId and not seen[setting.GamepassId] then
					seen[setting.GamepassId] = true
					table.insert(uniqueIds, setting.GamepassId)
				end
			end
		end

		local DataController = Knit.GetController("DataController")

		-- All three operations run concurrently; the page reveals only when
		-- every one of them has settled.
		Promise.all({
			-- 1. Player settings data
			DataController:GetDataAsync():andThen(function(data)
				if not cancelled then
					setSettings(data.Settings or {})
				end
			end),

			-- 2. Group rank
			Promise.new(function(resolve)
				local rank = RankUtil:GetRankAsync(Players.LocalPlayer)
				if not cancelled then
					setPlayerRank(rank)
				end
				resolve()
			end),

			-- 3. Gamepass ownership for every gated setting
			Promise.new(function(resolve)
				local owned: { [number]: boolean } = {}
				for _, passId in ipairs(uniqueIds) do
					owned[passId] = GamepassUtil:PlayerOwnsPassAsync(Players.LocalPlayer, passId)
				end
				if not cancelled then
					setOwnedPassIds(owned)
				end
				resolve()
			end),
		}):andThen(function()
			if not cancelled then
				setIsLoading(false)
			end
		end)

		return function()
			cancelled = true
		end
	end, {})

	local function handleToggle(key: string, newValue: boolean)
		-- Optimistic local update
		setSettings(function(prev)
			local next = table.clone(prev or {})
			next[key] = newValue
			return next
		end)

		-- Persist; revert on failure
		task.spawn(function()
			local SettingsService = Knit.GetService("SettingsService")
			local ok, success = pcall(function()
				local _, s = SettingsService:SetSetting(key, newValue):await()
				return s
			end)
			if not ok or not success then
				setSettings(function(prev)
					local next = table.clone(prev or {})
					next[key] = not newValue
					return next
				end)
			end
		end)
	end

	-- Build the visible settings list for a category:
	-- settings with a GamepassId are only included when the player owns that pass.
	local function getVisibleSettings(category)
		local visible = {}
		for _, setting in ipairs(category.Settings) do
			if not setting.GamepassId or ownedPassIds[setting.GamepassId] then
				table.insert(visible, setting)
			end
		end
		return visible
	end

	-- Hide a category when:
	--   • it has no visible settings after the gamepass filter, OR
	--   • every remaining setting is rank-gated above the player's rank
	local visibleCategories = {}
	for _, category in ipairs(SettingsConfig) do
		local visibleSettings = getVisibleSettings(category)
		if #visibleSettings == 0 then continue end

		local allGated    = true
		local categoryMin = math.huge
		for _, setting in ipairs(visibleSettings) do
			if not setting.MinRank then
				allGated = false
			else
				categoryMin = math.min(categoryMin, setting.MinRank)
			end
		end
		if not (allGated and playerRank < categoryMin) then
			table.insert(visibleCategories, { Data = category, Settings = visibleSettings })
		end
	end

	local cards: { [string]: any } = {
		Layout = c("UIListLayout", {
			Padding   = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder            = math.huge,
			Size                   = UDim2.fromScale(1, 0.04),
		}),
	}

	for i, entry in ipairs(visibleCategories) do
		cards[entry.Data.Category] = c(SettingCategory, {
			Title       = entry.Data.Category,
			Settings    = entry.Settings,
			Values      = settings or {},
			PlayerRank  = playerRank,
			LayoutOrder = i,
			OnToggle    = handleToggle,
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size                   = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint         = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace            = Styles.FONT_FREDOKA,
			Position            = UDim2.fromScale(0.470149, 0),
			Size                = UDim2.fromScale(0.94, 0.09),
			Text                = "Settings",
			TextColor3          = Styles.GREEN,
			TextScaled          = true,
		}),

		Body = c("ScrollingFrame", {
			Active                 = true,
			AutomaticCanvasSize    = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize             = UDim2.new(),
			Position               = UDim2.fromScale(0, 0.1),
			ScrollBarImageColor3   = Color3.new(),
			ScrollBarThickness     = 4,
			ScrollingDirection     = Enum.ScrollingDirection.Y,
			Size                   = UDim2.fromScale(1, 0.9),
			Visible                = not isLoading,
		}, cards),

		LoadingSpinner = isLoading and c("ImageLabel", {
			AnchorPoint            = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image                  = "rbxassetid://5634393881",
			Position               = UDim2.fromScale(0.5, 0.55),
			Size                   = UDim2.fromScale(0.175, 0.175),
			SizeConstraint         = Enum.SizeConstraint.RelativeXX,
			ScaleType              = Enum.ScaleType.Fit,
			Rotation               = clockBinding:map(function(clock: number)
				local t = (clock % SPIN_PERIOD) / SPIN_PERIOD
				return easeInOutBack(t) * 360
			end),
		}) or nil,
	})
end
