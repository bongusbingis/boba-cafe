local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCategory = require(UI.Pages.Shop.ShopCategory)

---> private
local c = React.createElement

-- Groups a flat purchase list into month buckets sorted newest-first.
-- Each entry in the returned array is { label: string, items: { ShopCategory.Item } }.
local function groupByMonth(purchases: { any })
    local buckets: { [number]: { label: string, items: { ShopCategory.Item } } } = {}
    local order: { number } = {}

    for _, purchase in ipairs(purchases) do
        local t = os.date("*t", purchase.Timestamp) :: any
        local key = t.year * 100 + t.month

        if not buckets[key] then
            buckets[key] = {
                label = os.date("%B %Y", purchase.Timestamp) :: string,
                items = {},
            }
            table.insert(order, key)
        end

        table.insert(buckets[key].items, {
            Label = purchase.ProductName,
            Price = os.date("%b %d", purchase.Timestamp) :: string,
        })
    end

    table.sort(order, function(a, b)
        return a > b -- newest month first
    end)

    local groups = {}
    for _, key in ipairs(order) do
        table.insert(groups, buckets[key])
    end
    return groups
end

---> public
return function()
    -- nil  = loading, false = rate-limited/error, table = loaded
    local purchases, setPurchases = React.useState(nil)

    React.useEffect(function()
        local GetPurchases = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("GetPurchases")
        task.spawn(function()
            local ok, result = pcall(function()
                return GetPurchases:InvokeServer()
            end)
            setPurchases(if ok and result then result else {})
        end)
    end, {})

    -- Body content: loading placeholder, empty notice, or category list
    local bodyChildren = {
        UIListLayout = c("UIListLayout", {
            Padding = UDim.new(0.02, 0),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        Spacer = c("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = math.huge,
            Size = UDim2.fromScale(1, 0.05),
        }),
    }

    if purchases == nil then
        bodyChildren["Loading"] = c("TextLabel", {
            BackgroundTransparency = 1,
            FontFace = Styles.FONT_FREDOKA,
            LayoutOrder = 0,
            Size = UDim2.fromScale(1, 0.08),
            Text = "Loading purchases...",
            TextColor3 = Styles.GRAY,
            TextScaled = true,
        })
    elseif #purchases == 0 then
        bodyChildren["Empty"] = c("TextLabel", {
            BackgroundTransparency = 1,
            FontFace = Styles.FONT_FREDOKA,
            LayoutOrder = 0,
            Size = UDim2.fromScale(1, 0.08),
            Text = "No purchases found.",
            TextColor3 = Styles.GRAY,
            TextScaled = true,
        })
    else
        local groups = groupByMonth(purchases)
        for i, group in ipairs(groups) do
            bodyChildren[group.label] = c(ShopCategory, {
                Title = group.label,
                Items = group.items,
                LayoutOrder = i,
            })
        end
    end

    return c("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, {
        Title = c("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            FontFace = Styles.FONT_FREDOKA,
            Position = UDim2.fromScale(0.470149, 0),
            Size = UDim2.fromScale(0.94, 0.09),
            Text = "Purchases",
            TextColor3 = Styles.GREEN,
            TextScaled = true,
        }),

        Categories = c("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            CanvasSize = UDim2.new(),
            Position = UDim2.fromScale(0, 0.112),
            ScrollBarImageColor3 = Color3.new(),
            ScrollBarThickness = 5,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Size = UDim2.fromScale(1, 0.888),
        }, bodyChildren),
    })
end
