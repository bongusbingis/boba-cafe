-- EXCERPT of StarterGui.UIArchive.OldUI.BobaPhone.Frame.__REACT_SCREEN: lines 1-541 (root + Home), then the `apps`
-- wrapper (lines 543-548), then closeApps + uIAspectRatioConstraint (lines 1636-1660). The `apps` children (boba,
-- web, chat, jokes, wordOfTheDay; lines 549-3443) are omitted here: boba is in __REACT_SCREEN.boba-app.luau and the
-- others are retired apps. Verbatim apart from this header; not standalone (`c` is a free global, no return).
c("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -16, 1, -16),
}, {
    appsHandler = c("LocalScript"),

    home = c("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "http://www.roblox.com/asset/?id=8261032060",
        ScaleType = Enum.ScaleType.Crop,
        Size = UDim2.fromScale(1, 1),
    }, {
        timeHandler = c("LocalScript"),

        applications = c("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 0.2),
            Size = UDim2.fromScale(1, 0.6),
        }, {
            uIGridLayout = c("UIGridLayout", {
                CellPadding = UDim2.fromScale(0.05, 0.1),
                CellSize = UDim2.fromScale(0.25, 0.2),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),

            boba = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 2,
                Size = UDim2.fromOffset(100, 100),
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(164, 189, 71)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 131, 49)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=5634393881",
                        Position = UDim2.fromScale(0.5, 0.4),
                        Size = UDim2.fromScale(1.3, 1.3),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Boba",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            subs = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 4,
                Size = UDim2.fromOffset(100, 100),
                Visible = false,
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 0)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(225, 37, 144)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8261190497",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Subs",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            web = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 7,
                Size = UDim2.fromOffset(100, 100),
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(114, 201, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(89, 125, 225)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8261164391",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Web",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            jokes = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 6,
                Size = UDim2.fromOffset(100, 100),
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 229, 30)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 81, 47)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8265686238",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Jokes",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            games = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 3,
                Size = UDim2.fromOffset(100, 100),
                Visible = false,
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 33, 33)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(162, 40, 232)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8265727394",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Games",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            chat = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 1,
                Size = UDim2.fromOffset(100, 100),
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(49, 207, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 109, 232)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8265756341",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Chat",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            gifts = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 5,
                Size = UDim2.fromOffset(100, 100),
                Visible = false,
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 97, 6)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 161, 47)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8265827640",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Gifts",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),

            event = c("ImageButton", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                LayoutOrder = 100,
                Size = UDim2.fromOffset(100, 100),
                Visible = false,
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(0.25, 0),
                    BottomRightRadius = UDim.new(0.25, 0),
                    TopLeftRadius = UDim.new(0.25, 0),
                    TopRightRadius = UDim.new(0.25, 0),
                }),

                uIGradient = c("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(243, 63, 127)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 94, 97)),
                    }),
                    Rotation = 45,
                }),

                uIStroke = c("UIStroke", {
                    Color = Color3.new(1, 1, 1),
                    Thickness = 2,
                }),

                frame = c("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=9368023125",
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                    }),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.25, 0),
                        BottomRightRadius = UDim.new(0.25, 0),
                        TopLeftRadius = UDim.new(0.25, 0),
                        TopRightRadius = UDim.new(0.25, 0),
                    }),
                }),

                textLabel = c("TextLabel", {
                    BackgroundTransparency = 1,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Position = UDim2.new(0, 0, 1, 5),
                    Size = UDim2.fromScale(1, 0.25),
                    Text = "Easter",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                }),
            }),
        }),

        date = c("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
            Position = UDim2.fromScale(0.5, 0.135),
            Size = UDim2.fromScale(0.85, 0.04),
            Text = "December 15, 2021",
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),

        time = c("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            FontFace = Font.new(
                "rbxasset://fonts/families/GothamSSm.json",
                Enum.FontWeight.Heavy,
                Enum.FontStyle.Normal
            ),
            Position = UDim2.fromScale(0.5, 0.075),
            Size = UDim2.fromScale(0.85, 0.07),
            Text = "11:00 AM",
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),

        uICorner = c("UICorner", {
            BottomLeftRadius = UDim.new(0.11, 0),
            BottomRightRadius = UDim.new(0.11, 0),
            TopLeftRadius = UDim.new(0.11, 0),
            TopRightRadius = UDim.new(0.11, 0),
        }),
    }),

    apps = c("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromScale(1, 0),
    }, {
        -- ... boba (see __REACT_SCREEN.boba-app.luau), web, chat, jokes, wordOfTheDay omitted ...

        closeApps = c("ImageButton", {
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 0.95),
            Size = UDim2.fromScale(1, 0.05),
            ZIndex = 10,
        }, {
            frame = c("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(),
                BackgroundTransparency = 0.8,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(0.5, 0.3),
            }, {
                uICorner = c("UICorner", {
                    BottomLeftRadius = UDim.new(1, 0),
                    BottomRightRadius = UDim.new(1, 0),
                    TopLeftRadius = UDim.new(1, 0),
                    TopRightRadius = UDim.new(1, 0),
                }),
            }),
        }),

        uIAspectRatioConstraint = c("UIAspectRatioConstraint", {
            AspectRatio = 0.483,
        }),
    }),
})
