--[[
    Component: RecipeCard
    Description: Recipe step list for the HUD order ticket (M1.5b, M1.2 design
                 §3.8). Renders one row per OrderSpec.Steps entry, driven by the
                 equipped tool's attributes: done, current or pending rows, plus
                 Wrong and Close problem states. Renders nothing when the spec
                 has no steps (teas, water and similar).

    Props:
        spec: OrderSpec
        attrs: tool attributes from GetAttributes(), or nil when nothing is held
        tool: the equipped Tool instance, or nil (feeds the cup viewport)
        patience: patience fraction 0..1, or nil to hide the bar
        shiftText: e.g. "Shift 1", or nil to hide the shift prefix
--]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Ordering = Shared:WaitForChild("Ordering")

local React = require(Packages.React)

local Styles = require(UI.Styles)
local OrderSpec = require(Ordering.OrderSpec)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local ViewportModel = require(UI.Components.ViewportModel)

---> Private

local c = React.createElement

-- Plain-text state glyphs (DEC-020 Q1).
local GLYPH_DONE = "✓"
local GLYPH_CURRENT = "●"
local GLYPH_TODO = "○"
local GLYPH_WRONG = "✗"
local GLYPH_CLOSE = "!"

local FOOTER_DONE = "Serve your customer!"

-- Mirrors the NPC bubble patience colours (STYLE.md §1.1): full GREEN,
-- GOLD_MID "Yellow", RED "Red". GOLD_MID stands in for the approved Q2
-- yellow token, which lives outside this lane's write scope.
local function patienceColor(fraction: number)
	if fraction < 0.25 then
		return Styles.RED
	end
	if fraction < 0.5 then
		return Styles.GOLD_MID
	end
	return Styles.GREEN
end

-- One step row: a plain-text state glyph plus the step label.
local function StepRow(props)
	return c("Frame", {
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
	}, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		Glyph = c("TextLabel", {
			LayoutOrder = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(0, 16, 0, 0),
			Text = props.glyph,
			TextColor3 = props.glyphColor,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		Label = c("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, -20, 0, 0),
			Text = props.text,
			TextColor3 = props.textColor,
			TextSize = props.textSize,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

---> RecipeCard

return function(props)
	local spec = props.spec
	local steps = OrderSpec.Steps(spec)
	if #steps == 0 then
		return nil
	end

	local current, problem = OrderSpec.StepState(spec, props.attrs)
	local total = #steps
	local doneCount = math.clamp(current - 1, 0, total)

	-- Header sub-line: "Shift 1 · 1/4", or just "1/4" with no shift source.
	local countText = ("%d/%d"):format(doneCount, total)
	local subText = if props.shiftText ~= nil then (props.shiftText .. " · " .. countText) else countText
	-- Fast-bonus cue (T4): shown while patience is at or above the Fast threshold.
	if typeof(props.patience) == "number" and props.patience >= CustomerConfig.FAST_FRACTION and current <= total then
		subText ..= " · Fast bonus!"
	end

	local rows = {}
	for index, step in steps do
		local glyph, glyphColor = GLYPH_TODO, Styles.GRAY
		local text, textColor, textSize = step.Label, Styles.GRAY, 13
		if index < current then
			glyph, glyphColor = GLYPH_DONE, Styles.GREEN_DEEP
		elseif index == current then
			glyph, glyphColor = GLYPH_CURRENT, Styles.GREEN_DEEP
			textColor, textSize = Styles.GREEN_DEEP, 15
		end
		if problem ~= nil and problem.Step == index then
			if problem.Severity == "Wrong" then
				glyph, glyphColor = GLYPH_WRONG, Styles.RED
			else
				glyph, glyphColor = GLYPH_CLOSE, Styles.GOLD_MID
			end
			text = ("%s (%s: %s)"):format(step.Label, problem.Severity, problem.Reason)
			textColor = glyphColor
		end
		rows["Step_" .. index] = c(StepRow, {
			layoutOrder = index,
			glyph = glyph,
			glyphColor = glyphColor,
			text = text,
			textColor = textColor,
			textSize = textSize,
		})
	end

	-- A mistake with no row (ice or sugar nobody asked for) still shows.
	if problem ~= nil and problem.Step == nil then
		local bannerColor = if problem.Severity == "Wrong" then Styles.RED else Styles.GOLD_MID
		rows.ProblemBanner = c(StepRow, {
			layoutOrder = total + 1,
			glyph = if problem.Severity == "Wrong" then GLYPH_WRONG else GLYPH_CLOSE,
			glyphColor = bannerColor,
			text = ("(%s: %s)"):format(problem.Severity, problem.Reason),
			textColor = bannerColor,
			textSize = 13,
		})
	end

	local header = c("Frame", {
		LayoutOrder = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
	}, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		Cup = if props.tool ~= nil
			then c(ViewportModel, {
				LayoutOrder = 0,
				Model = props.tool,
				Size = UDim2.fromOffset(44, 44),
			})
			else nil,
		Info = c("Frame", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, if props.tool ~= nil then -52 else 0, 0, 0),
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ItemName = c("TextLabel", {
				LayoutOrder = 0,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.new(1, 0, 0, 18),
				Text = if typeof(spec.Label) == "string" then spec.Label else "?",
				TextColor3 = Styles.GREEN_DEEP,
				TextSize = 15,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Sub = c("TextLabel", {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.new(1, 0, 0, 14),
				Text = subText,
				TextColor3 = Styles.GRAY,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Patience = if typeof(props.patience) == "number"
				then c("Frame", {
					LayoutOrder = 2,
					BackgroundColor3 = Styles.GRAY,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 6),
				}, {
					Fill = c("Frame", {
						BackgroundColor3 = patienceColor(math.clamp(props.patience, 0, 1)),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(math.clamp(props.patience, 0, 1), 1),
					}),
				})
				else nil,
		}),
	})

	local footer = if current > total
		then c("Frame", {
			LayoutOrder = total + 2,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
		}, {
			Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.new(1, 0, 0, 20),
				Text = FOOTER_DONE,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			}),
		})
		else nil

	return c(
		"Frame",
		{
			LayoutOrder = props.layoutOrder,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Styles.OFFWHITE,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
		},
		(function()
			local children = table.clone(rows)
			children.Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			children.Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			})
			children.Header = header
			children.Footer = footer
			return children
		end)()
	)
end
