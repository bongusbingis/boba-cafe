--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Styles = require(Shared.UI.Styles)

local TextInputPrompt = require(Shared.UI.Components.Dialogs.TextInputPrompt)

local c = React.createElement

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", "<font color='#f5c242'>%1</font> ")
		:gsub("%|(.-)%|", "<font color='#fa2545'>%1</font> ")
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(TextInputPrompt, {
		Title = "Roleplay Name",
		-- Text = formatBrackets(
		-- 	"This [Pet Capsule] contains a random pet! Hatch it in order to find which one it is!"
		-- ),
		Text = "Choose a roleplay nickname! This cannot be changed later, so choose wisely!",
		Buttons = {},
		CloseText = "Close",
		PlaceholderText = "Nickname",
		OnResolution = function(buttonText)
			print("TextInputPrompt resolved:", buttonText)
		end,
	}))

	return function()
		root:unmount()
	end
end
