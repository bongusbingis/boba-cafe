local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

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
            TextColor3 = Color3.fromRGB(150, 189, 136),
            Text = tab,
        })
    end

    return c(OpenableMenu, {
        TitleText = "Menu",
        TitleColor = Color3.fromRGB(143, 169, 127),
        SideButtonChildren = sideButtonChildren,
    })
end