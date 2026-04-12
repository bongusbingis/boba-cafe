--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local SelectorModels = ReplicatedStorage:FindFirstChild("SelectorModels")

local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)
local Styles = require(UI.Styles)
local usePx = require(UI.Hooks.usePx)

local Pane = require(UI.Components.Pane)
local ViewportModel = require(UI.Components.ViewportModel)

local c = React.createElement

local BASE_COLOR = Styles.GREEN_DIM
local OPEN_SPRING = { mass = 0.85, tension = 430, friction = 30 }
local CLOSE_SPRING = { mass = 0.85, tension = 1000, friction = 34 }
local REVEAL_STAGGER = 0.05

type PromptSelectionItem = {
	Name: string,
	Model: Instance?,
	ModelName: string?,
	Color: Color3?,
	IsTip: boolean?,
}

type PromptSelectionProps = {
	Title: string?,
	Text: string?,
	Items: { any }?,
	OffsetX: number?,
	OnResolution: (number?) -> (),
	Native: { [string]: any }?,
}

type IndexedItem = {
	Index: number,
	Data: PromptSelectionItem,
}

local function normalizeItems(rawItems: { any }?): { PromptSelectionItem }
	local function resolveSelectorModel(name: string?): Instance?
		if not SelectorModels or typeof(name) ~= "string" or name == "" then
			return nil
		end

		local model = SelectorModels:FindFirstChild(name, true)
		if model and (model:IsA("Model") or model:IsA("BasePart")) then
			return model
		end

		return nil
	end

	local function resolveModel(entry: { [string]: any }, itemName: string): Instance?
		local selectorModelName = if typeof(entry.ModelName) == "string" then entry.ModelName else itemName
		local selectorModel = resolveSelectorModel(selectorModelName)
		if selectorModel then
			return selectorModel
		end

		local rawModel = entry.Model
		if typeof(rawModel) == "Instance" and (rawModel:IsA("Model") or rawModel:IsA("BasePart")) then
			return rawModel
		end

		return nil
	end

	local normalized = {}
	if not rawItems then
		return normalized
	end

	for index, entry in ipairs(rawItems) do
		if typeof(entry) ~= "table" then
			continue
		end

		local rawName = entry.Name
		local name = if typeof(rawName) == "string" and rawName ~= ""
			then rawName
			else string.format("Option %d", index)
		local model = resolveModel(entry, name)

		table.insert(normalized, {
			Name = name,
			Model = model,
			ModelName = if typeof(entry.ModelName) == "string" then entry.ModelName else nil,
			Color = entry.Color,
			IsTip = entry.IsTip == true,
		})
	end

	return normalized
end

local function buildRows(items: { PromptSelectionItem }, maxPerRow: number): { { IndexedItem } }
	local rows = {}
	local currentRow = {}

	for index, item in ipairs(items) do
		table.insert(currentRow, { Index = index, Data = item })
		if #currentRow >= maxPerRow then
			table.insert(rows, currentRow)
			currentRow = {}
		end
	end

	if #currentRow > 0 then
		table.insert(rows, currentRow)
	end

	return rows
end

local function ChoiceButton(props: {
	Entry: IndexedItem,
	Delay: number,
	ButtonSizePx: number,
	OnPicked: (number) -> (),
})
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local isShown, setIsShown = React.useState(false)

	React.useEffect(function()
		local cancelled = false
		task.delay(props.Delay, function()
			if not cancelled then
				setIsShown(true)
			end
		end)

		return function()
			cancelled = true
		end
	end, { props.Delay })

	local spring = ReactSpring.useSpring({
		scale = if not isShown then 0 else (isPressing and 0.93 or (isHovering and 1.06 or 1)),
		config = {
            mass = 0.7,
            tension = 500,
            friction = 20,
        },
	})

	local item = props.Entry.Data

	return c(Pane, {
		ClassName = "ImageButton",
		AspectRatio = 1,
		CornerRadius = 1,
		Scale = spring.scale,
		OnClick = function()
			props.OnPicked(props.Entry.Index)
		end,
		OnPress = function()
			setIsPressing(true)
		end,
		OnRelease = function()
			setIsPressing(false)
		end,
		OnHover = function()
			setIsHovering(true)
		end,
		OnLeave = function()
			setIsHovering(false)
			setIsPressing(false)
		end,
		Stroke = {
			Color = Styles.GREEN_LIGHT,
			Thickness = 2,
		},
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = item.Color or BASE_COLOR,
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			LayoutOrder = props.Entry.Index,
			Size = UDim2.fromOffset(props.ButtonSizePx, props.ButtonSizePx),
			ZIndex = 62,
		},
	}, {
		Viewport = item.Model and c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.39),
				Size = UDim2.fromScale(0.96, 0.76),
				ZIndex = 63,
			},
		}, {
			Model = c(ViewportModel, {
				Model = item.Model,
				Size = UDim2.fromScale(1, 1),
				ElevationAngle = 20,
				FieldOfView = 38,
				ZIndex = 63,
			}),
		}) or nil,

		Label = c(Pane, {
			ClassName = "TextLabel",
			MaxTextSize = 24,
			Native = {
				AnchorPoint = Vector2.new(0.5, if item.Model then 1 else 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = if item.Model then UDim2.fromScale(0.5, 1) else UDim2.fromScale(0.5, 0.5),
				Size = if item.Model then UDim2.fromScale(0.92, 0.42) else UDim2.fromScale(0.9, 0.42),
				Text = item.Name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeTransparency = 0.5,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 63,
			},
		}),
	})
end

return function(props: PromptSelectionProps)
	local px = usePx()
	local items = normalizeItems(props.Items)
	local isDense = #items >= 20
	local maxPerRow = if isDense then 6 else (if #items >= 10 then 5 else 4)
	local rows = buildRows(items, maxPerRow)
	local rowCount = math.max(#rows, 1)
	local shownColumns = if #rows > 0 then #rows[1] else 1

	local buttonSizePx = math.max(px(if isDense then 62 else 84), if isDense then 56 else 70)
	local buttonGapPx = math.max(px(if isDense then 8 else 10), if isDense then 6 else 8)
	local rowGapPx = math.max(px(if isDense then 9 else 11), if isDense then 7 else 9)
	local edgePaddingPx = math.max(px(if isDense then 14 else 16), if isDense then 12 else 14)

	local bodyWidthPx = shownColumns * buttonSizePx + math.max(shownColumns - 1, 0) * buttonGapPx
	local bodyHeightPx = rowCount * buttonSizePx + math.max(rowCount - 1, 0) * rowGapPx
	local titleHeightPx = math.max(px(if isDense then 34 else 40), if isDense then 28 else 32)
	local textHeightPx = if props.Text and props.Text ~= ""
		then math.max(px(if isDense then 26 else 30), if isDense then 22 else 24)
		else 0
	local topSectionPx = titleHeightPx + textHeightPx

	local promptWidthPx = bodyWidthPx + edgePaddingPx * 2
	local promptHeightPx = bodyHeightPx + topSectionPx + edgePaddingPx * 2

	local isClosableByOverlay = #items == 0 or not (items[1] and items[1].IsTip == true)
	local closingRef = React.useRef(false)

	local anim, api = ReactSpring.useSpring(function()
		return {
			OverlayTransparency = 1,
			PanelScale = 0.75,
			PanelY = 0.56,
			config = OPEN_SPRING,
		}
	end)

	React.useEffect(function()
		api.start({
			OverlayTransparency = 0.5,
			PanelScale = 1,
			PanelY = 0.5,
			config = OPEN_SPRING,
		})
	end, {})

	local function closeWith(value: number?)
		if closingRef.current then
			return
		end
		closingRef.current = true

		api.start({
			OverlayTransparency = 1,
			PanelScale = 0.78,
			PanelY = 0.56,
			config = CLOSE_SPRING,
		})

        task.delay(0.15, props.OnResolution, value)
	end

	local rowChildren = {
		UIListLayout = c("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, rowGapPx),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for rowIndex, row in ipairs(rows) do
		local rowButtons = {
			UIListLayout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, buttonGapPx),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		}

		for columnIndex, entry in ipairs(row) do
			local revealDelay = ((rowIndex - 1) * maxPerRow + (columnIndex - 1)) * REVEAL_STAGGER
			rowButtons["Button_" .. entry.Index] = c(ChoiceButton, {
				Entry = entry,
				Delay = revealDelay,
				ButtonSizePx = buttonSizePx,
				OnPicked = function(selectedIndex)
					closeWith(selectedIndex)
				end,
			})
		end

		rowChildren["List_" .. rowIndex] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = rowIndex,
			Size = UDim2.fromOffset(bodyWidthPx, buttonSizePx),
			ZIndex = 61,
		}, rowButtons)
	end

	if #rows == 0 then
		rowChildren.Empty = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 1,
				Size = UDim2.fromOffset(bodyWidthPx, buttonSizePx),
				Text = "No entries",
				TextColor3 = Styles.GRAY,
				TextScaled = true,
				ZIndex = 62,
			},
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		DisableClick = c(Pane, {
			ClassName = "TextButton",
			OnClick = if isClosableByOverlay
				then function()
					closeWith(nil)
				end
				else nil,
			Native = {
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = anim.OverlayTransparency,
                Position = UDim2.fromOffset(0, -36),
				Size = UDim2.fromScale(5, 5),
				Text = "",
				ZIndex = 50,
			},
		}),

		PromptSelection = c(Pane, {
			ClassName = "Frame",
			Scale = anim.PanelScale,
			CornerRadius = UDim.new(math.clamp(0.5 / rowCount, 0.08, 0.35), 0),
			Stroke = {
				Color = Styles.GREEN_DIM,
				Thickness = 4,
			},
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Styles.OFFWHITE,
				BackgroundTransparency = 0,
				ClipsDescendants = true,
				Position = anim.PanelY:map(function(y: number)
					return UDim2.fromScale(0.5 + (props.OffsetX or 0), y)
				end),
				Size = UDim2.fromOffset(promptWidthPx, promptHeightPx),
				ZIndex = 60,
			},
		}, {
			UIPadding = c("UIPadding", {
				PaddingTop = UDim.new(0, edgePaddingPx),
				PaddingBottom = UDim.new(0, edgePaddingPx),
				PaddingLeft = UDim.new(0, edgePaddingPx),
				PaddingRight = UDim.new(0, edgePaddingPx),
			}),

			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromOffset(0, px(-6)),
					Size = UDim2.fromOffset(bodyWidthPx, titleHeightPx),
					Text = props.Title or "Select",
					TextColor3 = Styles.GREEN,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 61,
				},
			}),

			Text = props.Text and props.Text ~= "" and c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_DENKONE,
					Position = UDim2.fromOffset(0, titleHeightPx - 6),
					Size = UDim2.fromOffset(bodyWidthPx, textHeightPx),
					Text = props.Text,
					TextColor3 = Styles.GREEN_DEEP,
					TextScaled = true,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 61,
				},
			}) or nil,

			ButtonsHolder = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, topSectionPx),
				Size = UDim2.fromOffset(bodyWidthPx, bodyHeightPx),
				ZIndex = 61,
			}, rowChildren),
		}),
	})
end