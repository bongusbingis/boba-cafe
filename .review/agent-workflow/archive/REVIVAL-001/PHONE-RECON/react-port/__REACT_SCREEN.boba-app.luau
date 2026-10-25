-- EXCERPT of lines 549-1380 of StarterGui.UIArchive.OldUI.BobaPhone.Frame.__REACT_SCREEN (the `boba` child of `apps`).
-- Verbatim apart from this header; original indentation kept (8 spaces). Not standalone: `c` is a free global.
        boba = c("ImageLabel", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            ScaleType = Enum.ScaleType.Crop,
            Size = UDim2.fromScale(1, 1),
            TileSize = UDim2.fromOffset(300, 300),
            Visible = false,
        }, {
            uICorner = c("UICorner", {
                BottomLeftRadius = UDim.new(0.11, 0),
                BottomRightRadius = UDim.new(0.11, 0),
                TopLeftRadius = UDim.new(0.11, 0),
                TopRightRadius = UDim.new(0.11, 0),
            }),

            bottom = c("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0, 0.85),
                Size = UDim2.fromScale(1, 0.1),
            }, {
                uIListLayout = c("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    Padding = UDim.new(0.03, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),

                imageButton = c("ImageButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = Enum.SizeConstraint.RelativeYY,
                    Visible = false,
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8267151132",
                        ImageColor3 = Color3.fromRGB(96, 202, 94),
                        Position = UDim2.fromScale(0.5, 0.1),
                        Size = UDim2.fromScale(0.6, 0.6),
                    }),

                    textLabel = c("TextLabel", {
                        BackgroundTransparency = 1,
                        FontFace = Font.new(
                            "rbxasset://fonts/families/GothamSSm.json",
                            Enum.FontWeight.Bold,
                            Enum.FontStyle.Normal
                        ),
                        Position = UDim2.fromScale(0, 0.75),
                        Size = UDim2.fromScale(1, 0.25),
                        Text = "Home",
                        TextColor3 = Color3.fromRGB(96, 202, 94),
                        TextScaled = true,
                    }),
                }),

                imageButton2 = c("ImageButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = Enum.SizeConstraint.RelativeYY,
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8267206830",
                        ImageColor3 = Color3.fromRGB(96, 202, 94),
                        Position = UDim2.fromScale(0.5, 0.1),
                        Size = UDim2.fromScale(0.6, 0.6),
                    }),

                    textLabel = c("TextLabel", {
                        BackgroundTransparency = 1,
                        FontFace = Font.new(
                            "rbxasset://fonts/families/GothamSSm.json",
                            Enum.FontWeight.Bold,
                            Enum.FontStyle.Normal
                        ),
                        Position = UDim2.fromScale(0, 0.75),
                        Size = UDim2.fromScale(1, 0.25),
                        Text = "Order",
                        TextColor3 = Color3.fromRGB(96, 202, 94),
                        TextScaled = true,
                    }),
                }),

                imageButton3 = c("ImageButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = Enum.SizeConstraint.RelativeYY,
                    Visible = false,
                }, {
                    imageLabel = c("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Image = "http://www.roblox.com/asset/?id=8267150291",
                        ImageColor3 = Color3.fromRGB(128, 128, 128),
                        Position = UDim2.fromScale(0.5, 0.1),
                        Size = UDim2.fromScale(0.6, 0.6),
                    }),

                    textLabel = c("TextLabel", {
                        BackgroundTransparency = 1,
                        FontFace = Font.new(
                            "rbxasset://fonts/families/GothamSSm.json",
                            Enum.FontWeight.Bold,
                            Enum.FontStyle.Normal
                        ),
                        Position = UDim2.fromScale(0, 0.75),
                        Size = UDim2.fromScale(1, 0.25),
                        Text = "History",
                        TextColor3 = Color3.fromRGB(128, 128, 128),
                        TextScaled = true,
                    }),
                }),
            }),

            menus = c("Folder", nil, {
                home = c("ImageLabel", {
                    BackgroundTransparency = 1,
                    ScaleType = Enum.ScaleType.Crop,
                    Size = UDim2.fromScale(1, 1),
                    TileSize = UDim2.fromOffset(300, 300),
                    Visible = false,
                }, {
                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.11, 0),
                        BottomRightRadius = UDim.new(0.11, 0),
                        TopLeftRadius = UDim.new(0.11, 0),
                        TopRightRadius = UDim.new(0.11, 0),
                    }),

                    center = c("Frame", {
                        BackgroundColor3 = Color3.fromRGB(228, 228, 228),
                        BorderColor3 = Color3.fromRGB(27, 42, 53),
                        BorderSizePixel = 0,
                        Position = UDim2.fromScale(0, 0.2),
                        Size = UDim2.fromScale(1, 0.65),
                    }),

                    top = c("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.fromScale(1, 0.2),
                    }, {
                        textLabel = c("TextLabel", {
                            BackgroundTransparency = 1,
                            FontFace = Font.new(
                                "rbxasset://fonts/families/GothamSSm.json",
                                Enum.FontWeight.Medium,
                                Enum.FontStyle.Normal
                            ),
                            Position = UDim2.fromScale(0.05, 0.5),
                            Size = UDim2.fromScale(0.9, 0.25),
                            Text = "Hi, xSa_m",
                            TextColor3 = Color3.new(),
                            TextScaled = true,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }),
                    }),
                }),

                order = c("ImageLabel", {
                    BackgroundTransparency = 1,
                    ScaleType = Enum.ScaleType.Crop,
                    Size = UDim2.fromScale(1, 1),
                    TileSize = UDim2.fromOffset(300, 300),
                }, {
                    menuHandler = c("LocalScript", {
                        Disabled = true,
                    }),

                    phoneMenuController = c("ModuleScript"),

                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.11, 0),
                        BottomRightRadius = UDim.new(0.11, 0),
                        TopLeftRadius = UDim.new(0.11, 0),
                        TopRightRadius = UDim.new(0.11, 0),
                    }),

                    center = c("Frame", {
                        BackgroundColor3 = Color3.fromRGB(228, 228, 228),
                        BorderColor3 = Color3.fromRGB(27, 42, 53),
                        BorderSizePixel = 0,
                        Position = UDim2.fromScale(0, 0.2),
                        Size = UDim2.fromScale(1, 0.65),
                    }, {
                        menu = c("ScrollingFrame", {
                            Active = true,
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            BackgroundTransparency = 1,
                            ElasticBehavior = Enum.ElasticBehavior.Never,
                            ScrollBarImageColor3 = Color3.new(),
                            ScrollBarThickness = 0,
                            Size = UDim2.fromScale(1, 1),
                        }, {
                            uIListLayout = c("UIListLayout", {
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),

                            template = c("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.fromScale(1, 0.7),
                                SizeConstraint = Enum.SizeConstraint.RelativeXX,
                                Visible = false,
                            }, {
                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/GothamSSm.json",
                                        Enum.FontWeight.Bold,
                                        Enum.FontStyle.Normal
                                    ),
                                    Position = UDim2.fromScale(0.05, 0.05),
                                    Size = UDim2.fromScale(0.9, 0.125),
                                    Text = "Category",
                                    TextColor3 = Color3.fromRGB(48, 48, 48),
                                    TextScaled = true,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),

                                scrollingFrame = c("ScrollingFrame", {
                                    Active = true,
                                    BackgroundTransparency = 1,
                                    BottomImage = "",
                                    CanvasSize = UDim2.fromScale(2, 0),
                                    MidImage = "http://www.roblox.com/asset/?id=1912796145",
                                    Position = UDim2.fromScale(0.05, 0.2),
                                    ScrollBarImageColor3 = Color3.new(),
                                    ScrollBarImageTransparency = 0.75,
                                    ScrollBarThickness = 10,
                                    Size = UDim2.fromScale(0.9, 0.8),
                                    TopImage = "",
                                }, {
                                    uIListLayout = c("UIListLayout", {
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        Padding = UDim.new(0, 5),
                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                    }),

                                    template = c("ImageButton", {
                                        BackgroundTransparency = 1,
                                        Size = UDim2.fromScale(0.7, 1),
                                        SizeConstraint = Enum.SizeConstraint.RelativeYY,
                                        Visible = false,
                                    }, {
                                        viewportFrame = c("ViewportFrame", {
                                            BackgroundColor3 = Color3.fromRGB(136, 170, 122),
                                            Size = UDim2.fromScale(1, 1),
                                            SizeConstraint = Enum.SizeConstraint.RelativeXX,
                                        }, {
                                            uICorner = c("UICorner", {
                                                BottomLeftRadius = UDim.new(1, 0),
                                                BottomRightRadius = UDim.new(1, 0),
                                                TopLeftRadius = UDim.new(1, 0),
                                                TopRightRadius = UDim.new(1, 0),
                                            }),
                                        }),

                                        textLabel = c("TextLabel", {
                                            BackgroundTransparency = 1,
                                            FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                                            Position = UDim2.fromScale(0, 0.75),
                                            Size = UDim2.fromScale(1, 0.25),
                                            Text = "Item",
                                            TextColor3 = Color3.fromRGB(48, 48, 48),
                                            TextScaled = true,
                                            TextYAlignment = Enum.TextYAlignment.Top,
                                        }, {
                                            uITextSizeConstraint = c("UITextSizeConstraint", {
                                                MaxTextSize = 12,
                                            }),
                                        }),
                                    }),
                                }),

                                imageLabel = c("ImageLabel", {
                                    BackgroundColor3 = Color3.new(1, 1, 1),
                                    BorderColor3 = Color3.fromRGB(27, 42, 53),
                                    BorderSizePixel = 0,
                                    Image = "http://www.roblox.com/asset/?id=5150079965",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = 0.75,
                                    Position = UDim2.fromScale(0.05, 1),
                                    Size = UDim2.fromScale(0.9, 0.02),
                                }),
                            }),
                        }),

                        myOrder = c("Frame", {
                            BackgroundTransparency = 1,
                            Size = UDim2.fromScale(1, 1),
                            Visible = false,
                        }, {
                            orderFrame = c("ScrollingFrame", {
                                Active = true,
                                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                                BackgroundTransparency = 1,
                                BottomImage = "http://www.roblox.com/asset/?id=4983877983",
                                MidImage = "http://www.roblox.com/asset/?id=4983877983",
                                Position = UDim2.fromOffset(5, 5),
                                ScrollBarImageColor3 = Color3.fromRGB(179, 179, 179),
                                ScrollBarThickness = 5,
                                Size = UDim2.new(1, -10, 0.9, -10),
                                TopImage = "http://www.roblox.com/asset/?id=4983877983",
                                VerticalScrollBarInset = Enum.ScrollBarInset.Always,
                            }, {
                                template = c("Frame", {
                                    BackgroundColor3 = Color3.fromRGB(179, 179, 179),
                                    BorderColor3 = Color3.fromRGB(27, 42, 53),
                                    BorderSizePixel = 0,
                                    Size = UDim2.new(1, -5, 0, 20),
                                    Visible = false,
                                }, {
                                    topFrame = c("Frame", {
                                        BackgroundColor3 = Color3.fromRGB(153, 153, 153),
                                        BorderColor3 = Color3.fromRGB(27, 42, 53),
                                        BorderSizePixel = 0,
                                        Size = UDim2.new(1, 0, 0, 20),
                                    }, {
                                        itemName = c("TextLabel", {
                                            BackgroundTransparency = 1,
                                            FontFace = Font.new(
                                                "rbxasset://fonts/families/GothamSSm.json",
                                                Enum.FontWeight.Bold,
                                                Enum.FontStyle.Normal
                                            ),
                                            Position = UDim2.fromOffset(2, 2),
                                            Size = UDim2.new(1, -4, 1, -4),
                                            Text = "Item Name",
                                            TextColor3 = Color3.new(1, 1, 1),
                                            TextScaled = true,
                                            TextXAlignment = Enum.TextXAlignment.Left,
                                        }),

                                        removeItem = c("ImageButton", {
                                            BackgroundTransparency = 1,
                                            Image = "http://www.roblox.com/asset/?id=5017723314",
                                            Position = UDim2.new(1, -17, 0, 3),
                                            Size = UDim2.fromOffset(14, 14),
                                        }),
                                    }),

                                    uIListLayout = c("UIListLayout", {
                                        Padding = UDim.new(0, 3),
                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                    }),

                                    infoFrameTemplate = c("Frame", {
                                        BackgroundTransparency = 1,
                                        Size = UDim2.new(1, 0, 0, 10),
                                        Visible = false,
                                    }, {
                                        textLabel = c("TextLabel", {
                                            BackgroundTransparency = 1,
                                            FontFace = Font.new(
                                                "rbxasset://fonts/families/GothamSSm.json",
                                                Enum.FontWeight.Bold,
                                                Enum.FontStyle.Normal
                                            ),
                                            Position = UDim2.fromScale(0.1, 0),
                                            Size = UDim2.fromScale(0.9, 1),
                                            Text = "+ Whipped Cream",
                                            TextColor3 = Color3.new(1, 1, 1),
                                            TextScaled = true,
                                            TextXAlignment = Enum.TextXAlignment.Left,
                                        }),
                                    }),
                                }),

                                uIListLayout = c("UIListLayout", {
                                    Padding = UDim.new(0, 5),
                                    SortOrder = Enum.SortOrder.LayoutOrder,
                                }),
                            }),

                            button = c("ImageButton", {
                                BackgroundColor3 = Color3.fromRGB(92, 194, 90),
                                Position = UDim2.new(0, 5, 0.9, 0),
                                Size = UDim2.new(1, -10, 0.1, -5),
                            }, {
                                uICorner = c("UICorner", {
                                    BottomLeftRadius = UDim.new(0.2, 0),
                                    BottomRightRadius = UDim.new(0.2, 0),
                                    TopLeftRadius = UDim.new(0.2, 0),
                                    TopRightRadius = UDim.new(0.2, 0),
                                }),

                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                                    Position = UDim2.fromScale(0.1, 0.1),
                                    Size = UDim2.fromScale(0.8, 0.8),
                                    Text = "Place Order",
                                    TextColor3 = Color3.new(1, 1, 1),
                                    TextScaled = true,
                                }),
                            }),
                        }),
                    }),

                    top = c("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.fromScale(1, 0.2),
                    }, {
                        textLabel = c("TextLabel", {
                            BackgroundTransparency = 1,
                            FontFace = Font.new(
                                "rbxasset://fonts/families/GothamSSm.json",
                                Enum.FontWeight.Medium,
                                Enum.FontStyle.Normal
                            ),
                            Position = UDim2.fromScale(0.05, 0.4),
                            Size = UDim2.fromScale(0.9, 0.25),
                            Text = "Order",
                            TextColor3 = Color3.new(),
                            TextScaled = true,
                            TextXAlignment = Enum.TextXAlignment.Left,
                        }),

                        buttons = c("Frame", {
                            BackgroundTransparency = 1,
                            Position = UDim2.fromScale(0, 0.8),
                            Size = UDim2.fromScale(1, 0.2),
                        }, {
                            uIListLayout = c("UIListLayout", {
                                FillDirection = Enum.FillDirection.Horizontal,
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),

                            menu = c("ImageButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.fromScale(0.5, 1),
                            }, {
                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/GothamSSm.json",
                                        Enum.FontWeight.Medium,
                                        Enum.FontStyle.Normal
                                    ),
                                    Size = UDim2.fromScale(1, 0.8),
                                    Text = "Menu",
                                    TextColor3 = Color3.fromRGB(48, 48, 48),
                                    TextScaled = true,
                                }),

                                frame = c("Frame", {
                                    BackgroundColor3 = Color3.fromRGB(96, 202, 94),
                                    BorderColor3 = Color3.fromRGB(27, 42, 53),
                                    BorderSizePixel = 0,
                                    Position = UDim2.fromScale(0, 0.85),
                                    Size = UDim2.fromScale(1, 0.15),
                                }),
                            }),

                            myOrder = c("ImageButton", {
                                BackgroundTransparency = 1,
                                Size = UDim2.fromScale(0.5, 1),
                            }, {
                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/GothamSSm.json",
                                        Enum.FontWeight.Medium,
                                        Enum.FontStyle.Normal
                                    ),
                                    Size = UDim2.fromScale(1, 0.8),
                                    Text = "My Order",
                                    TextColor3 = Color3.fromRGB(128, 128, 128),
                                    TextScaled = true,
                                }),

                                frame = c("Frame", {
                                    BackgroundTransparency = 1,
                                    Position = UDim2.fromScale(0, 0.85),
                                    Size = UDim2.fromScale(1, 0.15),
                                }),
                            }),
                        }),
                    }),
                }),

                popUp = c("ImageButton", {
                    BackgroundColor3 = Color3.new(),
                    BackgroundTransparency = 0.5,
                    Size = UDim2.fromScale(1, 1),
                    Visible = false,
                    ZIndex = 2,
                }, {
                    uICorner = c("UICorner", {
                        BottomLeftRadius = UDim.new(0.11, 0),
                        BottomRightRadius = UDim.new(0.11, 0),
                        TopLeftRadius = UDim.new(0.11, 0),
                        TopRightRadius = UDim.new(0.11, 0),
                    }),

                    itemOptions = c("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.9, 0.5),
                        Visible = false,
                    }, {
                        uICorner = c("UICorner", {
                            BottomLeftRadius = UDim.new(0.05, 0),
                            BottomRightRadius = UDim.new(0.05, 0),
                            TopLeftRadius = UDim.new(0.05, 0),
                            TopRightRadius = UDim.new(0.05, 0),
                        }),

                        scrollingFrame = c("ScrollingFrame", {
                            Active = true,
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            BackgroundTransparency = 1,
                            BottomImage = "http://www.roblox.com/asset/?id=4983877983",
                            MidImage = "http://www.roblox.com/asset/?id=4983877983",
                            Position = UDim2.fromOffset(5, 5),
                            ScrollBarImageColor3 = Color3.fromRGB(204, 204, 204),
                            ScrollBarThickness = 5,
                            Size = UDim2.new(1, -10, 0.85, -10),
                            TopImage = "http://www.roblox.com/asset/?id=4983877983",
                            VerticalScrollBarInset = Enum.ScrollBarInset.Always,
                        }, {
                            uIListLayout = c("UIListLayout", {
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),

                            requiredSelectionTemplate = c("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 80),
                                Visible = false,
                            }, {
                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/GothamSSm.json",
                                        Enum.FontWeight.Heavy,
                                        Enum.FontStyle.Normal
                                    ),
                                    Position = UDim2.fromOffset(5, 20),
                                    Size = UDim2.new(1, -10, 0, 20),
                                    Text = "Syrup Flavor",
                                    TextColor3 = Color3.fromRGB(255, 104, 5),
                                    TextScaled = true,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),

                                itemInfo = c("ImageButton", {
                                    BackgroundTransparency = 1,
                                    Image = "http://www.roblox.com/asset/?id=5150445362",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = 0.8,
                                    Position = UDim2.fromOffset(0, 40),
                                    ScaleType = Enum.ScaleType.Slice,
                                    Size = UDim2.new(1, 0, 0, 40),
                                    SliceCenter = Rect.new(256, 256, 256, 256),
                                    SliceScale = 0.02,
                                }, {
                                    frame = c("Frame", {
                                        BackgroundColor3 = Color3.new(1, 1, 1),
                                        BorderColor3 = Color3.fromRGB(27, 42, 53),
                                        BorderSizePixel = 0,
                                        Position = UDim2.fromOffset(5, 5),
                                        Size = UDim2.new(1, -10, 1, -10),
                                    }, {
                                        imageLabel = c("ImageLabel", {
                                            BackgroundTransparency = 1,
                                            Position = UDim2.fromScale(0.1, 0.1),
                                            Size = UDim2.fromScale(0.8, 0.8),
                                        }),

                                        textLabel = c("TextLabel", {
                                            BackgroundTransparency = 1,
                                            FontFace = Font.new(
                                                "rbxasset://fonts/families/GothamSSm.json",
                                                Enum.FontWeight.Heavy,
                                                Enum.FontStyle.Normal
                                            ),
                                            Position = UDim2.fromScale(0.1, 0.1),
                                            Size = UDim2.fromScale(0.8, 0.8),
                                            Text = "Template",
                                            TextColor3 = Color3.new(1, 1, 1),
                                            TextSize = 12,
                                            TextStrokeTransparency = 0,
                                            TextWrapped = true,
                                        }),
                                    }),
                                }),
                            }),

                            selectTemplate = c("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 80),
                                Visible = false,
                            }, {
                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/GothamSSm.json",
                                        Enum.FontWeight.Heavy,
                                        Enum.FontStyle.Normal
                                    ),
                                    Position = UDim2.fromOffset(5, 20),
                                    Size = UDim2.new(1, -10, 0, 20),
                                    Text = "Size",
                                    TextColor3 = Color3.fromRGB(255, 104, 5),
                                    TextScaled = true,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),

                                selector = c("ImageLabel", {
                                    BackgroundTransparency = 1,
                                    Image = "http://www.roblox.com/asset/?id=5150445362",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = 0.8,
                                    Position = UDim2.fromOffset(0, 40),
                                    ScaleType = Enum.ScaleType.Slice,
                                    Size = UDim2.new(1, 0, 0, 40),
                                    SliceCenter = Rect.new(256, 256, 256, 256),
                                    SliceScale = 0.02,
                                }, {
                                    frame = c("Frame", {
                                        BackgroundColor3 = Color3.new(1, 1, 1),
                                        BorderColor3 = Color3.fromRGB(27, 42, 53),
                                        BorderSizePixel = 0,
                                        Position = UDim2.fromOffset(5, 5),
                                        Size = UDim2.new(1, -10, 1, -10),
                                    }, {
                                        selectionFrame = c("Frame", {
                                            BackgroundTransparency = 1,
                                            Size = UDim2.fromScale(1, 1),
                                        }, {
                                            uIListLayout = c("UIListLayout", {
                                                FillDirection = Enum.FillDirection.Horizontal,
                                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                                SortOrder = Enum.SortOrder.LayoutOrder,
                                            }),

                                            template = c("ImageButton", {
                                                AutoButtonColor = false,
                                                BackgroundColor3 = Color3.new(1, 1, 1),
                                                BorderColor3 = Color3.fromRGB(27, 42, 53),
                                                BorderSizePixel = 0,
                                                Size = UDim2.fromScale(1, 1),
                                                Visible = false,
                                            }, {
                                                textLabel = c("TextLabel", {
                                                    BackgroundTransparency = 1,
                                                    FontFace = Font.new(
                                                        "rbxasset://fonts/families/GothamSSm.json",
                                                        Enum.FontWeight.Heavy,
                                                        Enum.FontStyle.Normal
                                                    ),
                                                    Position = UDim2.fromScale(0.1, 0.2),
                                                    Size = UDim2.fromScale(0.8, 0.6),
                                                    Text = "Small",
                                                    TextColor3 = Color3.new(1, 1, 1),
                                                    TextScaled = true,
                                                }),
                                            }),
                                        }),

                                        barsFrame = c("Frame", {
                                            BackgroundTransparency = 1,
                                            Size = UDim2.fromScale(1, 1),
                                        }, {
                                            template = c("Frame", {
                                                BackgroundColor3 = Color3.fromRGB(204, 204, 204),
                                                BorderColor3 = Color3.fromRGB(27, 42, 53),
                                                BorderSizePixel = 0,
                                                Position = UDim2.new(0.5, -1, 0, 0),
                                                Size = UDim2.new(0, 2, 1, 0),
                                                Visible = false,
                                            }),
                                        }),
                                    }),
                                }),
                            }),

                            optionsTemplate = c("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, 30),
                                Visible = false,
                            }, {
                                itemInfo = c("ImageButton", {
                                    BackgroundTransparency = 1,
                                    Image = "http://www.roblox.com/asset/?id=5150445362",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = 0.8,
                                    ScaleType = Enum.ScaleType.Slice,
                                    Size = UDim2.fromOffset(30, 30),
                                    SliceCenter = Rect.new(256, 256, 256, 256),
                                    SliceScale = 0.02,
                                }, {
                                    frame = c("Frame", {
                                        BackgroundColor3 = Color3.new(1, 1, 1),
                                        BorderColor3 = Color3.fromRGB(27, 42, 53),
                                        BorderSizePixel = 0,
                                        Position = UDim2.fromOffset(5, 5),
                                        Size = UDim2.new(1, -10, 1, -10),
                                    }, {
                                        frame = c("Frame", {
                                            BackgroundColor3 = Color3.fromRGB(204, 204, 204),
                                            BorderColor3 = Color3.fromRGB(27, 42, 53),
                                            BorderSizePixel = 0,
                                            Position = UDim2.fromOffset(2, 2),
                                            Size = UDim2.new(1, -4, 1, -4),
                                        }),
                                    }),
                                }),

                                textLabel = c("TextLabel", {
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/GothamSSm.json",
                                        Enum.FontWeight.Heavy,
                                        Enum.FontStyle.Normal
                                    ),
                                    Position = UDim2.new(0, 35, 0.2, 0),
                                    Size = UDim2.new(1, -40, 0.6, 0),
                                    Text = "Ice",
                                    TextColor3 = Color3.fromRGB(255, 104, 5),
                                    TextScaled = true,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),
                            }),
                        }),

                        button = c("ImageButton", {
                            BackgroundColor3 = Color3.fromRGB(136, 170, 122),
                            Position = UDim2.new(0, 5, 0.85, 0),
                            Size = UDim2.new(1, -10, 0.15, -5),
                        }, {
                            uICorner = c("UICorner", {
                                BottomLeftRadius = UDim.new(0.2, 0),
                                BottomRightRadius = UDim.new(0.2, 0),
                                TopLeftRadius = UDim.new(0.2, 0),
                                TopRightRadius = UDim.new(0.2, 0),
                            }),

                            textLabel = c("TextLabel", {
                                BackgroundTransparency = 1,
                                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                                Position = UDim2.fromScale(0.1, 0.1),
                                Size = UDim2.fromScale(0.8, 0.8),
                                Text = "Add Item",
                                TextColor3 = Color3.new(1, 1, 1),
                                TextScaled = true,
                            }),
                        }),
                    }),

                    selectList = c("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.9, 0.5),
                        Visible = false,
                    }, {
                        uICorner = c("UICorner", {
                            BottomLeftRadius = UDim.new(0.05, 0),
                            BottomRightRadius = UDim.new(0.05, 0),
                            TopLeftRadius = UDim.new(0.05, 0),
                            TopRightRadius = UDim.new(0.05, 0),
                        }),

                        scrollingFrame = c("ScrollingFrame", {
                            Active = true,
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            BackgroundTransparency = 1,
                            BottomImage = "http://www.roblox.com/asset/?id=4983877983",
                            MidImage = "http://www.roblox.com/asset/?id=4983877983",
                            Position = UDim2.fromOffset(5, 5),
                            ScrollBarImageColor3 = Color3.fromRGB(204, 204, 204),
                            ScrollBarThickness = 5,
                            Size = UDim2.new(1, -10, 1, -10),
                            TopImage = "http://www.roblox.com/asset/?id=4983877983",
                            VerticalScrollBarInset = Enum.ScrollBarInset.Always,
                        }, {
                            uIListLayout = c("UIListLayout", {
                                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),

                            template = c("ImageButton", {
                                BackgroundTransparency = 1,
                                Image = "http://www.roblox.com/asset/?id=5150445362",
                                ImageColor3 = Color3.new(),
                                ImageTransparency = 0.8,
                                Position = UDim2.fromOffset(0, 40),
                                ScaleType = Enum.ScaleType.Slice,
                                Size = UDim2.new(1, 0, 0, 40),
                                SliceCenter = Rect.new(256, 256, 256, 256),
                                SliceScale = 0.02,
                                Visible = false,
                            }, {
                                frame = c("Frame", {
                                    BackgroundColor3 = Color3.new(1, 1, 1),
                                    BorderColor3 = Color3.fromRGB(27, 42, 53),
                                    BorderSizePixel = 0,
                                    Position = UDim2.fromOffset(5, 5),
                                    Size = UDim2.new(1, -10, 1, -10),
                                }, {
                                    imageLabel = c("ImageLabel", {
                                        BackgroundTransparency = 1,
                                        Position = UDim2.fromScale(0.1, 0.1),
                                        Size = UDim2.fromScale(0.8, 0.8),
                                    }),

                                    textLabel = c("TextLabel", {
                                        BackgroundTransparency = 1,
                                        FontFace = Font.new(
                                            "rbxasset://fonts/families/GothamSSm.json",
                                            Enum.FontWeight.Heavy,
                                            Enum.FontStyle.Normal
                                        ),
                                        Position = UDim2.fromScale(0.1, 0.1),
                                        Size = UDim2.fromScale(0.8, 0.8),
                                        Text = "Template",
                                        TextColor3 = Color3.new(1, 1, 1),
                                        TextSize = 12,
                                        TextStrokeTransparency = 0,
                                        TextWrapped = true,
                                    }),
                                }),
                            }),
                        }),
                    }),
                }),
            }),
        }),
