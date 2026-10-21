--[[
	Regulars (BIG-B5)
	Menu tab: one stamp card per named regular, in the Statistics card style.
	A regular you have not served yet shows "???" in the secret-stat colours,
	exactly as hidden statistics do. The line under the title shows progress and
	the completion reward. Data comes from RegularsService:GetBook on mount and
	again on BookChanged; offline (stories) it renders a sample book.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)
local RegularsConfig = require(Shared.Configuration.RegularsConfig)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function formatThousands(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function favouriteLabel(key: string): string
	for _, entry in CustomerConfig.ORDER_POOL do
		if entry.Key == key then
			return entry.Label
		end
	end
	return key
end

-- Offline preview: the roster with the first few stamped.
local function sampleBook()
	local entries = {}
	for index, regular in RegularsConfig.ROSTER do
		table.insert(entries, {
			Id = regular.Id,
			Name = regular.Name,
			Favourite = favouriteLabel(regular.Favourite),
			Visits = if index <= 4 then 5 - index else 0,
			Order = index,
		})
	end
	return {
		Loaded = true,
		Entries = entries,
		Stamped = 4,
		Total = #RegularsConfig.ROSTER,
		RewardBobaBucks = RegularsConfig.REWARD_BOBA_BUCKS,
		RewardTitle = "Cafe Favourite",
		RewardClaimed = false,
	}
end

-- Statistics.StatCard, with a third line for the visit count.
local function StampCard(props: {
	Name: string,
	Favourite: string,
	Visits: number,
	LayoutOrder: number,
})
	local hidden = props.Visits <= 0
	local labelColor = if hidden then Styles.GOLD_MID else Styles.GREEN_LIGHT
	local valueColor = if hidden then Styles.GOLD else Styles.GREEN
	local visitsText = if props.Visits == 1 then "1 visit" else `{props.Visits} visits`

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		UICorner = c("UICorner", { CornerRadius = Styles.CORNER_CARD }),
		UIPadding = c("UIPadding", {
			PaddingLeft = UDim.new(0.07, 0),
			PaddingRight = UDim.new(0.07, 0),
			PaddingTop = UDim.new(0.08, 0),
			PaddingBottom = UDim.new(0.08, 0),
		}),
		UIListLayout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.03, 0),
		}),
		NameText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.3),
			Text = if hidden then "???" else props.Name,
			TextColor3 = labelColor,
			TextScaled = true,
			FontFace = Styles.FONT_DENKONE,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		FavouriteText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.36),
			Text = if hidden then "???" else props.Favourite,
			TextColor3 = valueColor,
			TextScaled = true,
			FontFace = Styles.FONT_FREDOKA,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		VisitsText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0.22),
			Text = if hidden then "Not met yet" else visitsText,
			TextColor3 = if hidden then Styles.GRAY else Styles.GREEN_BADGE,
			TextScaled = true,
			FontFace = Styles.FONT_FREDOKA,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

---> public
return function()
	local book, setBook = React.useState(nil)

	React.useEffect(function()
		if not RunService:IsRunning() then
			setBook(sampleBook())
			return
		end
		local alive = true
		local ok, service = pcall(function()
			return Knit.GetService("RegularsService")
		end)
		if not ok or service == nil then
			return
		end
		local function refresh()
			service
				:GetBook()
				:andThen(function(latest)
					if alive and latest then
						setBook(latest)
					end
				end)
				:catch(function(err)
					warn("[Regulars] Failed to fetch the book:", err)
				end)
		end
		refresh()
		local connection = service.BookChanged:Connect(refresh)
		return function()
			alive = false
			connection:Disconnect()
		end
	end, {})

	local gridChildren = {
		UIGridLayout = c("UIGridLayout", {
			-- Three columns, four rows: the twelve regulars fit without scrolling.
			CellSize = UDim2.fromScale(0.31, 0.225),
			CellPadding = UDim2.fromScale(0.025, 0.025),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local statusText = "Loading regulars..."
	local statusColor = Styles.GRAY
	if book ~= nil then
		for _, entry in book.Entries do
			gridChildren[entry.Id] = c(StampCard, {
				Name = entry.Name,
				Favourite = entry.Favourite,
				Visits = entry.Visits,
				LayoutOrder = entry.Order,
			})
		end
		if book.RewardClaimed then
			statusText = `{book.Stamped}/{book.Total} served · {book.RewardTitle} title earned!`
			statusColor = Styles.GREEN_BADGE
		else
			statusText = `{book.Stamped}/{book.Total} served · Serve them all for {formatThousands(
				book.RewardBobaBucks
			)} Boba Bucks and the {book.RewardTitle} title.`
		end
	end

	-- UI-REVISION: tab title and hint line copied from the 14-page pattern (STYLE
	-- 4.1a, Pets hint), so the status wraps instead of shrinking to one tiny line.
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Regulars",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),
		Status = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.085),
			Text = statusText,
			TextColor3 = statusColor,
			TextScaled = true,
			TextWrapped = true,
		}),
		Grid = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.2),
			Size = UDim2.fromScale(1, 0.8),
		}, gridChildren),
	})
end
