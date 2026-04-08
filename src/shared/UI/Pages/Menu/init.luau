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

---> pages
local FoodMenu = require(script.FoodMenu)
local Credits = require(script.Credits)
local ServerInfo = require(script.ServerInfo)
local c = React.createElement

return function()
    return c(OpenableMenu, {
        TitleText = "Menu",
        TitleColor = Styles.GREEN,
        Pages = {
            {
                Key = "FoodMenu",
                Label = "Food Menu",
                LayoutOrder = 1,
                Content = {
                    Page = c(FoodMenu, {}),
                },
            },
            {
                Key = "PromoCodes",
                Label = "Promo Codes",
                LayoutOrder = 2,
            },
            {
                Key = "Statistics",
                Label = "Statistics",
                LayoutOrder = 3,
            },
            {
                Key = "Purchases",
                Label = "Purchases",
                LayoutOrder = 4,
            },
            {
                Key = "ServerInfo",
                Label = "Server Info",
                LayoutOrder = 5,
                Content = {
                    Page = c(ServerInfo, {}),
                },
            },
            {
                Key = "Settings",
                Label = "Settings",
                LayoutOrder = 6,
            },
            {
                Key = "Credits",
                Label = "Credits",
                LayoutOrder = 7,
                Content = {
                    Page = c(Credits, {}),
                },
            },
        },
    })
end
