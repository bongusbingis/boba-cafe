--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Styles = require(Shared.UI.Styles)
local PromptSelection = require(Shared.UI.Components.Dialogs.PromptSelection)

local c = React.createElement

local function getModel(folder, name)
	if not folder then
		return nil
	end

	local instance = folder:FindFirstChild(name)
	if instance and (instance:IsA("Model") or instance:IsA("BasePart")) then
		return instance
	end

	return nil
end

local selectorModels = ReplicatedStorage:FindFirstChild("SelectorModels")
local cupModels = if selectorModels then selectorModels:FindFirstChild("Cup") else nil
local pastryModels = if selectorModels then selectorModels:FindFirstChild("Pastry") else nil

local SAMPLE_ITEMS = {
	{ Name = "Small Cup", Model = getModel(cupModels, "Small Cup"), Color = Styles.GREEN_DIM },
	{ Name = "Medium Cup", Model = getModel(cupModels, "Medium Cup"), Color = Styles.GREEN },
	{ Name = "Large Cup", Model = getModel(cupModels, "Large Cup"), Color = Styles.GREEN_LIGHT },
}

local function storyComponent()
	local isOpen, setIsOpen = React.useState(true)
	local lastSelection, setLastSelection = React.useState("None")

	local function openDialog()
		setIsOpen(true)
	end

	return c("Frame", {
		BackgroundColor3 = Styles.CREAM,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Result = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.5, 0.04),
			Size = UDim2.fromScale(0.9, 0.05),
			Text = "Last Selection: " .. lastSelection,
			TextColor3 = Styles.GREEN_DEEP,
			TextScaled = true,
		}),

		Reopen = c("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			AutoButtonColor = false,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.5, 0.11),
			Size = UDim2.fromScale(0.28, 0.065),
			Text = "Open Prompt",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			[React.Event.Activated] = openDialog,
		}, {
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(0.4, 0),
			}),
		}),

		Dialog = isOpen and c(PromptSelection, {
			Title = "Choose A Cup",
			Items = SAMPLE_ITEMS,
            IsClosableByOverlay = false,
			OnResolution = function(selectedIndex)
				setIsOpen(false)
				if selectedIndex and SAMPLE_ITEMS[selectedIndex] then
					setLastSelection(SAMPLE_ITEMS[selectedIndex].Name)
				else
					setLastSelection("Dismissed")
				end
			end,
		}) or nil,
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(storyComponent))

	return function()
		root:unmount()
	end
end
