local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local PromptButton = require(UI.Components.Buttons.PromptButton)

---> configuration
local Titles = require(Shared.Configuration.Titles)

---> private
local c = React.createElement

-- Category section header matching ShopCategory anatomy (header slice
-- asset 13465572823, GREEN_LIGHT tint, white Fredoka text).
local function SectionHeader(props: {
	Title: string,
	LayoutOrder: number,
})
	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13465572823",
			ImageColor3 = Styles.GREEN_LIGHT,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.981, 0.065),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			SliceCenter = Rect.new(0, 0, 1019, 40),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.13),
				Size = UDim2.fromScale(0.94, 0.7),
				Text = props.Title,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),
	})
end

-- Category section footer matching ShopCategory anatomy (footer slice
-- asset 13465749908, GREEN_LIGHT tint) that sandwiches section content.
local function SectionFooter(props: {
	LayoutOrder: number,
})
	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13465749908",
			ImageColor3 = Styles.GREEN_LIGHT,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.981, 0.02),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
		},
	})
end

-- One title row: ShopItem row anatomy (0.981 x 0.065 RelativeXX, left inset
-- 0.03, white Fredoka label) with an Equip / Unequip PromptButton on the right.
local function TitleRow(props: {
	Def: Titles.TitleDef,
	Owned: boolean,
	Equipped: boolean,
	LayoutOrder: number,
	OnEquip: (titleId: string) -> (),
})
	local def = props.Def
	local isSecret = Titles.IsSecret(def, props.Owned)
	local fill = if props.Equipped then Styles.GREEN elseif props.Owned then Styles.GREEN_DIM else Styles.GRAY

	local labelText = if isSecret
		then "???"
		elseif def.Source == "Level" then `Level {def.Level} — {def.Text}`
		else def.Text
	local descText = if isSecret then "???" else def.Description

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundColor3 = fill,
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.981, 0.065),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Padding = {
			PaddingLeft = UDim.new(0.03, 0),
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(0.55, 0.57),
				Text = labelText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),
		Action = if props.Equipped
			then c(PromptButton, {
				Text = "Unequip",
				Color = Styles.CORAL,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.3, 0.77),
				OnClick = function()
					props.OnEquip("")
				end,
			})
			elseif props.Owned then c(PromptButton, {
				Text = "Equip",
				Color = Styles.GREEN,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.3, 0.77),
				OnClick = function()
					props.OnEquip(def.Id)
				end,
			})
			else c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.3, 0.57),
					Text = descText,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}),
	})
end

return function()
	local titlesData, setTitlesData = React.useState(function()
		return Titles.Normalize(nil)
	end)
	local isLoading, setIsLoading = React.useState(RunService:IsRunning())
	local inFlightRef = React.useRef(false)

	React.useEffect(function()
		if not RunService:IsRunning() then
			-- Story preview: show the level titles locked, as a new player sees them.
			local preview = Titles.Normalize(nil)
			for titleId in Titles.LevelOwned(1) do
				preview.Owned[titleId] = true
			end
			preview.Equipped = Titles.HighestLevelTitleId(1)
			setTitlesData(preview)
			return
		end
		local DataController = Knit.GetController("DataController")
		DataController:GetDataAsync():andThen(function(data)
			local merged = Titles.Normalize(data.Titles)
			for titleId in Titles.LevelOwned(data.Level or 1) do
				merged.Owned[titleId] = true
			end
			if merged.Equipped == "" then
				merged.Equipped = Titles.HighestLevelTitleId(data.Level or 1)
			end
			setTitlesData(merged)
			setIsLoading(false)
		end)
	end, {})

	local function equip(titleId: string)
		if inFlightRef.current then
			return
		end
		if not RunService:IsRunning() then
			setTitlesData(function(current)
				local next = Titles.Normalize(current)
				next.Equipped = titleId
				return next
			end)
			return
		end
		inFlightRef.current = true
		task.spawn(function()
			local ok, result = pcall(function()
				return Knit.GetService("ProgressionService"):EquipTitle(titleId):expect()
			end)
			inFlightRef.current = false
			if ok and result and result.Success then
				setTitlesData(function(current)
					local next = Titles.Normalize(current)
					next.Equipped = titleId
					return next
				end)
			end
		end)
	end

	local bodyChildren = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
			Size = UDim2.new(1, 0, 0, 60),
			Visible = true,
		}),
	}

	if isLoading then
		bodyChildren.Loading = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			LayoutOrder = 0,
			Size = UDim2.fromScale(1, 0.08),
			Text = "Loading titles...",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		})
	else
		local allTitles = Titles.All()
		local levelDefs = {}
		local manualDefs = {}
		for _, def in allTitles do
			if def.Source == "Level" then
				table.insert(levelDefs, def)
			else
				local isOwned = titlesData.Owned[def.Id] == true
				if not Titles.IsHidden(def, isOwned) then
					table.insert(manualDefs, def)
				end
			end
		end

		bodyChildren.LevelHeader = c(SectionHeader, {
			Title = "Level Titles",
			LayoutOrder = 100,
		})

		for i, def in ipairs(levelDefs) do
			bodyChildren[def.Id] = c(TitleRow, {
				Def = def,
				Owned = titlesData.Owned[def.Id] == true,
				Equipped = titlesData.Equipped == def.Id,
				LayoutOrder = 100 + i,
				OnEquip = equip,
			})
		end

		bodyChildren.LevelFooter = c(SectionFooter, {
			LayoutOrder = 100 + #levelDefs + 1,
		})

		if #manualDefs > 0 then
			bodyChildren.ManualHeader = c(SectionHeader, {
				Title = "Event Titles",
				LayoutOrder = 1000,
			})

			for i, def in ipairs(manualDefs) do
				bodyChildren[def.Id] = c(TitleRow, {
					Def = def,
					Owned = titlesData.Owned[def.Id] == true,
					Equipped = titlesData.Equipped == def.Id,
					LayoutOrder = 1000 + i,
					OnEquip = equip,
				})
			end

			bodyChildren.ManualFooter = c(SectionFooter, {
				LayoutOrder = 1000 + #manualDefs + 1,
			})
		end
	end

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
			Text = "Titles",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),
		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.085),
			Text = "Earn titles by levelling up and at events. Equip one to show it over your head!",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}),

		Body = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.19),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.81),
		}, bodyChildren),
	})
end
