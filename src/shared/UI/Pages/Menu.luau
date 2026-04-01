local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local OpenableMenu = require(UI.Components.Core.OpenableMenu)
local HudTabButton = require(UI.Components.Buttons.HudTabButton)

local c = React.createElement
local tabs = {
    "Food Menu",
    "Promo Codes",
    "Statistics",
    "Purchases",
    "Server Info",
    "Settings",
    "Credits",
}

return function()
    local sideButtonChildren = {}
    for k, tab in ipairs(tabs) do
        sideButtonChildren[tab] = c(HudTabButton, {
            BackgroundEnabled = true,
            LayoutOrder = k,
            Size = UDim2.fromScale(0.85, 0.095),
            TextColor3 = Styles.GREEN_LIGHT,
            Text = tab,
        })
    end

    return c(OpenableMenu, {
        TitleText = "Menu",
        TitleColor = Styles.GREEN,
        SideButtonChildren = sideButtonChildren,
    })
end