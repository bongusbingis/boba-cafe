--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local NormalButton = require(UI.Components.Buttons.NormalButton)

---> private
local c = React.createElement

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local currency, setCurrency = React.useState({
		BobaBucks = 0,
		Points = 0,
	})

	if RunService:IsRunning() then
		React.useEffect(function()
			Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
				setCurrency(playerData.Currency)
				for type, _ in playerData.Currency do
					playerData:ListenToChange({ "Currency", type }, function(newValue: number)
						setCurrency(function(prev)
							local new = table.clone(prev)
							new[type] = newValue
							return new
						end)
					end)
				end
			end)
		end, {})
	end


	return c(Pane, {
		ClassName = "Frame",
		ListLayout = {
			Padding = UDim.new(0.03, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		},
		Native = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0.025, 0.981),
			Size = UDim2.fromScale(0.175, 0.3),
			--BackgroundTransparency = 0.5
		},
	}, {
		Bucks = c(NormalButton, {
			PlusButton = true,
			Icon = "rbxassetid://13382286492",
			Color = Styles.GREEN_LIGHT,
			Text = currency.BobaBucks,
			OnClick = function()
				props.SetCurrentPage(UI.Pages.Shop, "Currency")
			end
		}),

		Points = c(NormalButton, {
			PlusButton = true,
			Icon = "rbxassetid://13391365805",
			Color = Styles.CORAL,
			Text = currency.Points,
			OnClick = function()
				props.SetCurrentPage(UI.Pages.Shop, "Currency")
			end
		}),
	})
end
