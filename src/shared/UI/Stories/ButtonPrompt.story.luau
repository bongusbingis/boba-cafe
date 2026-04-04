--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Styles = require(Shared.UI.Styles)
local ButtonPrompt = require(Shared.UI.Components.Dialogs.ButtonPrompt)

---> private
local c = React.createElement

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", "<font color='#f5c242'>%1</font> ")
		:gsub("%|(.-)%|", "<font color='#fa2545'>%1</font> ")
end

return function(target)
	local root = ReactRoblox.createRoot(target)
    
	root:render(c(ButtonPrompt, {
		Title = "Confirm Purchase",
		Text = formatBrackets("Are you sure you want to purchase [+5 Inventory Storage] for 5 Boba Bucks?"),
		Buttons = {
			{
				Text = "Yes",
				Color = Styles.GREEN,
				OnClick = function()
					print("Yes clicked")
				end
			},
			{
				Text = "No",
				Color = Styles.RED,
				OnClick = function()
					print("No clicked")
				end
			}
		},
		OnResolution = function(buttonText)
			print("Button clicked:", buttonText)
		end
	}))

	return function()
		root:unmount()
	end
end
