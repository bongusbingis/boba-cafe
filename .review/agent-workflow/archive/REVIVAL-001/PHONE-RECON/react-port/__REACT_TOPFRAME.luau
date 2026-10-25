c("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 0.063),
    ZIndex = 2,
}, {
    frame = c("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.new(),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromScale(0.5, 1),
    }, {
        uICorner = c("UICorner", {
            BottomLeftRadius = UDim.new(0.5, 0),
            BottomRightRadius = UDim.new(0.5, 0),
            TopLeftRadius = UDim.new(0.5, 0),
            TopRightRadius = UDim.new(0.5, 0),
        }),

        frame = c("Frame", {
            BackgroundColor3 = Color3.new(),
            BorderColor3 = Color3.fromRGB(27, 42, 53),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 0.5),
        }),
    }),
})
