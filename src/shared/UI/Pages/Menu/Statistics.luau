local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local timeAtJoin = os.time()

-- Ordered stat definitions. Secret stats display as "???" until the player
-- earns at least one, matching the legacy behaviour for hidden achievements.
local STATS = {
	{ Key = "TimePlayed", Label = "Time Played", Live = true },
	{ Key = "ItemsOrdered", Label = "Items Ordered" },
	{ Key = "BobasOrdered", Label = "Bobas Ordered" },
	{ Key = "BobaBucksEarned", Label = "Boba Bucks Earned" },
	{ Key = "BobaBucksSpent", Label = "Boba Bucks Spent" },
	{ Key = "OrdersCreated", Label = "Orders Created" },
	{ Key = "OrdersPrepared", Label = "Orders Prepared" },
	{ Key = "SpillsCleaned", Label = "Spills Cleaned" },
	{ Key = "CelebritiesMet", Label = "Celebrities Met", Secret = true },
	{ Key = "TreasureChestsFound", Label = "Treasure Chests", Secret = true },
}

local function formatHMS(totalSeconds: number): string
	local h = math.floor(totalSeconds / 3600)
	local m = math.floor((totalSeconds % 3600) / 60)
	local s = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function resolveSessionStart(playtime: { FirstJoin: number, MostRecentJoin: number }?): number
	if not playtime then
		return timeAtJoin
	end

	if (playtime.MostRecentJoin or 0) > 0 then
		return playtime.MostRecentJoin
	end

	if (playtime.FirstJoin or 0) > 0 then
		return playtime.FirstJoin
	end

	return timeAtJoin
end

local function StatCard(props: {
	Label: string,
	Value: string,
	Hidden: boolean,
	LayoutOrder: number,
})
	local labelColor = if props.Hidden then Styles.GOLD_MID else Styles.GREEN_LIGHT
	local valueColor = if props.Hidden then Styles.GOLD else Styles.GREEN

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		UICorner = c("UICorner", { CornerRadius = Styles.CORNER_CARD }),
		UIPadding = c("UIPadding", {
			PaddingLeft = UDim.new(0.07, 0),
			PaddingRight = UDim.new(0.07, 0),
			PaddingTop = UDim.new(0.1, 0),
			PaddingBottom = UDim.new(0.1, 0),
		}),
		UIListLayout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.04, 0),
		}),
		LabelText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.35),
			Text = if props.Hidden then "???" else props.Label,
			TextColor3 = labelColor,
			TextScaled = true,
			FontFace = Styles.FONT_DENKONE,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		ValueText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.55),
			Text = if props.Hidden then "???" else props.Value,
			TextColor3 = valueColor,
			TextScaled = true,
			FontFace = Styles.FONT_FREDOKA,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return function()
	local playerData, setPlayerData = React.useState(nil)
	-- Ticks every second so the live time-played counter updates.
	local now, setNow = React.useState(os.time())

	React.useEffect(function()
		local DataController = Knit.GetController("DataController")
		DataController:GetDataAsync():andThen(function(data)
			setPlayerData(data)
		end)
	end, {})

	React.useEffect(function()
		local running = true
		local function tick()
			if not running then
				return
			end
			setNow(os.time())
			task.delay(1, tick)
		end
		tick()
		return function()
			running = false
		end
	end, {})

	local gridChildren = {
		UIGridLayout = c("UIGridLayout", {
			-- Two columns with a small gap; 5 rows of 10 stats fit within the grid frame.
			CellSize = UDim2.fromScale(0.47, 0.17),
			CellPadding = UDim2.fromScale(0.025, 0.025),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, stat in ipairs(STATS) do
		local rawValue = 0
		local isLoaded = playerData ~= nil

		if isLoaded then
			rawValue = playerData.Statistics[stat.Key] or 0
			if stat.Live then
				local sessionStart = resolveSessionStart(playerData.Playtime)
				rawValue += math.max(0, now - sessionStart)
			end
		end

		local hidden = stat.Secret == true and rawValue == 0
		local displayValue = if not isLoaded then "..." elseif stat.Live then formatHMS(rawValue) else tostring(rawValue)

		gridChildren[stat.Key] = c(StatCard, {
			Label = stat.Label,
			Value = displayValue,
			Hidden = hidden,
			LayoutOrder = i,
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.fromScale(1, 0.09),
			Text = "Statistics",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Grid = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.11),
			Size = UDim2.fromScale(1, 0.89),
		}, gridChildren),
	})
end
