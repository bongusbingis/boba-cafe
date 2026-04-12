local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles / components
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local SECTION_HEADER_COLOR = Styles.GREEN
local BODY_TEXT_COLOR = Styles.GREEN_DEEP
local INPUT_BG_COLOR = Styles.GREEN_LIGHT
local BUTTON_BG_COLOR = Styles.GREEN_MID
local BUTTON_BG_DISABLED = Styles.GRAY

--- A bold section heading that matches the screenshot style.
local function SectionHeader(props: { Text: string, LayoutOrder: number })
	return c("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Styles.FONT_FREDOKA,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
		Text = props.Text,
		TextColor3 = SECTION_HEADER_COLOR,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

--- A wrapped body paragraph matching the smaller text in the screenshot.
local function BodyText(props: { Text: string, LayoutOrder: number })
	return c("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Styles.FONT_FREDOKA,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
		Text = props.Text,
		TextColor3 = BODY_TEXT_COLOR,
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

---> public
return function()
	local inputText, setInputText = React.useState("")
	local isSubmitting, setIsSubmitting = React.useState(false)
	-- { Success: boolean, Message: string } while a result is shown; nil otherwise
	local feedback, setFeedback = React.useState(nil)

	local boxRef = React.useRef(nil :: TextBox?)

	local function clearInput()
		setInputText("")
		if boxRef.current then
			boxRef.current.Text = ""
		end
	end

	local function handleSubmit()
		local trimmed = inputText:match("^%s*(.-)%s*$") or ""
		if isSubmitting or #trimmed == 0 then
			return
		end

		setIsSubmitting(true)
		setFeedback(nil)

		task.spawn(function()
			local RedeemCode = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("RedeemCode")

			local ok, result = pcall(function()
				return RedeemCode:InvokeServer(trimmed)
			end)

			if ok and result then
				setFeedback(result)
				if result.Success then
					clearInput()
				end
			else
				setFeedback({ Success = false, Message = "An error occurred. Please try again." })
			end

			setIsSubmitting(false)
		end)
	end

	local canSubmit = not isSubmitting and #(inputText:match("^%s*(.-)%s*$") or "") > 0
	local buttonColor = if canSubmit then BUTTON_BG_COLOR else BUTTON_BG_DISABLED

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Page title
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Promo Codes",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		-- Scrollable body
		Body = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.1),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.9),
		}, {
			Layout = c("UIListLayout", {
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Padding = c("UIPadding", {
				PaddingRight = UDim.new(0, 6),
			}),

			-- ── "Where to find codes?" ─────────────────────────────────────────
			FindHeader = c(SectionHeader, {
				Text = "Where to find codes?",
				LayoutOrder = 1,
			}),
			FindBody = c(BodyText, {
				Text = "Promo codes are released by the development team through official"
					.. " game announcements and community events. Keep an eye on the"
					.. " official Boba Cafe communications to stay up to date!",
				LayoutOrder = 2,
			}),

			-- ── Divider ────────────────────────────────────────────────────────
			Divider1 = c("Frame", {
				BackgroundColor3 = Styles.GREEN_LIGHT,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 1),
			}),

			-- ── "Redeem Code" + inline feedback ───────────────────────────────
			RedeemHeader = c("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
			}, {
				UIListLayout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Label = c("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(0, 24),
					Text = "Redeem Code",
					TextColor3 = SECTION_HEADER_COLOR,
					TextScaled = false,
					TextSize = 20,
				}),
				FeedbackLabel = feedback and c("TextLabel", {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, 24),
					Text = feedback.Message,
					TextColor3 = if feedback.Success then Styles.GREEN_BADGE else Styles.RED,
					TextScaled = false,
					TextSize = 16,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}) or nil,
			}),

			-- Text input
			InputFrame = c("Frame", {
				BackgroundColor3 = INPUT_BG_COLOR,
				BorderSizePixel = 0,
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 50),
			}, {
				UICorner = c("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
				Input = c("TextBox", {
					ref = boxRef,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ClearTextOnFocus = true,
					FontFace = Styles.FONT_FREDOKA,
					PlaceholderColor3 = Color3.new(1, 1, 1),
					PlaceholderText = "Enter your code here!",
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.93, 0.72),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					[React.Change.Text] = function(box: TextBox)
						setInputText(box.Text)
						setFeedback(nil)
					end,
					[React.Event.FocusLost] = function(_, enterPressed: boolean)
						if enterPressed then
							handleSubmit()
						end
					end,
				}),
			}),

			-- Submit button
			SubmitWrapper = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 40),
			}, {
				Button = c("TextButton", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutoButtonColor = false,
					BackgroundColor3 = buttonColor,
					BorderSizePixel = 0,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.55, 1),
					Text = if isSubmitting then "Redeeming..." else "Submit",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					[React.Event.Activated] = handleSubmit,
				}, {
					UICorner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),

			-- ── Divider ────────────────────────────────────────────────────────
			Divider2 = c("Frame", {
				BackgroundColor3 = Styles.GREEN_LIGHT,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 1),
			}),

			-- ── "Codes not working?" ───────────────────────────────────────────
			TroubleshootHeader = c(SectionHeader, {
				Text = "Codes not working?",
				LayoutOrder = 8,
			}),
			TroubleshootBody = c(BodyText, {
				Text = "Codes may not work if the server you are on has not been updated yet."
					.. " Try joining a new server, or redeem your code in a VIP server."
					.. " If the issue persists, the code may have expired or reached its"
					.. " maximum number of redemptions.",
				LayoutOrder = 9,
			}),

			Spacer = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 999,
				Size = UDim2.fromScale(1, 0),
			}),
		}),
	})
end
