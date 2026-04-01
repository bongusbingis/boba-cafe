local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(ReplicatedStorage.Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)
local PageTitle = require(UI.Components.PageTitle)
local SideButtons = require(UI.Components.SideButtons)
local HudTabButton = require(UI.Components.Buttons.HudTabButton)
local CloseButton = require(UI.Components.Buttons.CloseButton)

---> private
local c = React.createElement

---> types
export type SideButtonsProps = {
	Image: string?,
	ImageColor3: Color3?,
	Position: UDim2?,
	Size: UDim2?,
	ListLayout: {
		HorizontalAlignment: Enum.HorizontalAlignment?,
		VerticalAlignment: Enum.VerticalAlignment?,
		Padding: UDim?,
		SortOrder: Enum.SortOrder?,
		[string]: any,
	}?,
}

export type Page = {
	--- Unique identifier used to track the active page
	Key: string,
	--- Text shown on the side navigation button
	Label: string,
	--- React element rendered in the content area when this page is active
	Content: any,
	--- Controls button ordering in the side panel (defaults to insertion order)
	LayoutOrder: number?,
	--- Background color of the side button (defaults to white)
	ButtonColor: Color3?,
	--- Text color of the side button label (defaults to white)
	ButtonTextColor: Color3?,
}

export type Props = {
	--- Wrapper frame name, defaults to "MenuWrapper"
	Name: string?,
	--- Aspect ratio for the outer Pane constraint, defaults to 1.347
	AspectRatio: number?,
	--- Title banner text, defaults to "Menu"
	TitleText: string?,
	--- Title banner accent color, defaults to Styles.GREEN
	TitleColor: Color3?,
	--- When true, hides the background pattern image
	HidePattern: boolean?,
	--- Pages available for navigation; side buttons are generated automatically
	Pages: { Page }?,
	--- Key of the page shown on first render; defaults to the first page
	DefaultPage: string?,
	--- Props forwarded to the SideButtons panel (image, size, layout, etc.)
	SideButtonsProps: SideButtonsProps?,
	--- Called when the close button is clicked
	OnClose: (() -> ())?,
}

---> public
return function(props: Props)
	local defaultKey = props.DefaultPage
		or (props.Pages and props.Pages[1] and props.Pages[1].Key)
		or nil

	local currentPage, setCurrentPage = React.useState(defaultKey)

	local sideButtonChildren: { [string]: any } = {}
	if props.Pages then
		for i, page in ipairs(props.Pages) do
			local key = page.Key
			sideButtonChildren[key] = c(HudTabButton, {
				Text = page.Label,
				LayoutOrder = page.LayoutOrder or i,
				Size = UDim2.fromScale(0.85, 0.095),
				BackgroundColor = page.ButtonColor or Styles.OFFWHITE,
				TextColor3 = page.ButtonTextColor or Styles.GREEN_LIGHT,
				OnClick = function()
					setCurrentPage(key)
				end,
				Selected = currentPage == key,
			})
		end
	end

	-- Find the content for the active page
	local activeContent = nil
	if props.Pages then
		for _, page in ipairs(props.Pages) do
			if page.Key == currentPage then
				activeContent = page.Content
				break
			end
		end
	end

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = props.AspectRatio or 1.347,
		Native = {
			Name = props.Name or "MenuWrapper",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		},
	}, {
		Title = c(PageTitle, {
			Text = props.TitleText or "Menu",
			Color = props.TitleColor or Styles.GREEN,
		}),

		CloseButton = c(CloseButton, {
			OnClick = props.OnClose,
		}),

		Base = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13438173851",
				Position = UDim2.fromScale(0.5, 1),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 0.880631),
			},
		}, {
			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=13438184024",
					ImageColor3 = Styles.GREEN_LIGHT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.971, 0.955),
				},
			}),

			Container = c(Pane, {
				ClassName = "Frame",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.949833, 0.923274),
				},
			}, {
				Pattern = if props.HidePattern then nil else c(Pane, {
					ClassName = "ImageLabel",
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=13438518368",
						ImageTransparency = 0.9,
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromScale(1, 1.01108),
					},
				}),

				Frames = c(Pane, {
					ClassName = "Frame",
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.272521, 0.5),
						Size = UDim2.fromScale(0.707747, 0.939058),
					},
				}, activeContent),

				SideButtons = c(SideButtons, props.SideButtonsProps, sideButtonChildren),
			}),
		}),
	})
end
