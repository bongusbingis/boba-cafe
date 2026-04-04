--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Styles = require(Shared.UI.Styles)

local ActionPrompt = require(Shared.UI.Components.Dialogs.ActionPrompt)

local c = React.createElement

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", "<font color='#f5c242'>%1</font> ")
		:gsub("%|(.-)%|", "<font color='#fa2545'>%1</font> ")
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(ActionPrompt, {
		Title = "Pet Capsule",
		-- Text = formatBrackets(
		-- 	"This [Pet Capsule] contains a random pet! Hatch it in order to find which one it is!"
		-- ),
		Text = "Select an action!",
		Buttons = {
			{ Text = "Hatch Pet" },
			{ Text = "Hatch Pet" },
			{ Text = "Hatch Pet", Color = Styles.ROSE },
			
		},
		CloseText = "Close",
		OnResolution = function(buttonText)
			print("ActionPrompt resolved:", buttonText)
		end,
	}))

	return function()
		root:unmount()
	end
end
