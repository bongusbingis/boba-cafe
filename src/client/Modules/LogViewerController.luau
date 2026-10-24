--!strict
--[[
	LogViewerController.luau
	Knit controller managing interactive server log windows (client side).
	Supports individual, draggable, side-by-side floating windows for:
	- Admin logs (Cmdr commands and moderation events)
	- Chat logs (in-game player messages)
	- Join logs (connect/disconnect events)
	Designed to adhere strictly to docs/STYLE.md.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local Styles = require(Shared.UI.Styles)
local UiSfx = require(Shared.UI.Utility.UiSfx)

---> types
export type LogEntry = {
	Timestamp: number,
	TimeFormatted: string,
	Author: string,
	UserId: number,
	Text: string,
	Category: string?,
}

type WindowState = {
	Frame: Frame,
	LogList: ScrollingFrame,
	StatusLabel: TextLabel,
	SearchBox: TextBox,
	FilterQuery: string,
	Tab: string,
	IsVisible: boolean,
}

type TabConfig = {
	Title: string,
	Icon: string,
	DefaultPos: UDim2,
	SmallPos: UDim2,
}

---> controller declaration
local LogViewerController = Knit.CreateController({
	Name = "LogViewerController",
})

---> constants
local WINDOW_WIDTH = 360
local WINDOW_HEIGHT = 420

local TAB_CONFIGS: { [string]: TabConfig } = {
	Admin = {
		Title = "ADMIN LOGS",
		Icon = "📋",
		DefaultPos = UDim2.new(0.5, -375, 0.5, -210),
		SmallPos = UDim2.new(0.5, -180, 0.5, -220),
	},
	Chat = {
		Title = "CHAT LOGS",
		Icon = "💬",
		DefaultPos = UDim2.new(0.5, 5, 0.5, -210),
		SmallPos = UDim2.new(0.5, -170, 0.5, -180),
	},
	Join = {
		Title = "JOIN LOGS",
		Icon = "🚪",
		DefaultPos = UDim2.new(0.5, -185, 0.5, -90),
		SmallPos = UDim2.new(0.5, -160, 0.5, -140),
	},
}

---> state
local screenGui: ScreenGui? = nil
local windows: { [string]: WindowState } = {}
local cachedLogs: { [string]: { LogEntry } } = {
	Admin = {},
	Chat = {},
	Join = {},
}
local focusHistory: { string } = {}

---> private helpers
local function playSfx(name: string)
	pcall(function()
		UiSfx.Play(name)
	end)
end

local function normalizeTabName(name: string?): string
	if not name then
		return "Admin"
	end
	local lower = string.lower(name)
	if lower == "chat" or lower == "chatlogs" then
		return "Chat"
	elseif lower == "join" or lower == "joinlogs" or lower == "joins" then
		return "Join"
	else
		return "Admin"
	end
end

local function bringToFront(tab: string)
	local state = windows[tab]
	if state and screenGui then
		state.Frame.Parent = screenGui
		for i = #focusHistory, 1, -1 do
			if focusHistory[i] == tab then
				table.remove(focusHistory, i)
			end
		end
		table.insert(focusHistory, tab)
	end
end

local function makeDraggable(handle: GuiObject, windowFrame: Frame, tab: string)
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector3? = nil
	local startPos: UDim2? = nil

	handle.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = windowFrame.Position
			bringToFront(tab)

			local endConn: RBXScriptConnection?
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if endConn then
						endConn:Disconnect()
						endConn = nil
					end
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging and dragStart and startPos then
			local delta = input.Position - dragStart
			windowFrame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

function LogViewerController:RenderWindow(tab: string)
	local state = windows[tab]
	if not state or not state.IsVisible then
		return
	end

	local listScroll = state.LogList
	local statusLabel = state.StatusLabel

	-- Clear previous log rows
	for _, child in listScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local rawList = cachedLogs[tab] or {}
	local query = string.lower(state.FilterQuery)

	local filteredCount = 0
	for _, entry in rawList do
		if typeof(entry) ~= "table" then
			continue
		end

		local author = entry.Author or "Unknown"
		local text = entry.Text or ""
		local timeFormatted = entry.TimeFormatted or ""
		local userIdStr = tostring(entry.UserId or 0)

		local matches = false
		if query == "" then
			matches = true
		else
			local authorMatch = string.find(string.lower(author), query, 1, true) ~= nil
			local textMatch = string.find(string.lower(text), query, 1, true) ~= nil
			local idMatch = string.find(userIdStr, query, 1, true) ~= nil
			local timeMatch = string.find(string.lower(timeFormatted), query, 1, true) ~= nil
			if authorMatch or textMatch or idMatch or timeMatch then
				matches = true
			end
		end

		if matches then
			filteredCount += 1

			local row = Instance.new("Frame")
			row.Name = "LogRow"
			row.Size = UDim2.new(1, -4, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.BackgroundColor3 = if filteredCount % 2 == 1
				then Color3.fromRGB(244, 247, 242)
				else Color3.fromRGB(255, 255, 255)
			row.BorderSizePixel = 0
			row.Parent = listScroll

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 5)
			rowCorner.Parent = row

			local rowPadding = Instance.new("UIPadding")
			rowPadding.PaddingTop = UDim.new(0, 5)
			rowPadding.PaddingBottom = UDim.new(0, 5)
			rowPadding.PaddingLeft = UDim.new(0, 6)
			rowPadding.PaddingRight = UDim.new(0, 6)
			rowPadding.Parent = row

			local contentLabel = Instance.new("TextLabel")
			contentLabel.Name = "Content"
			contentLabel.Size = UDim2.fromScale(1, 0)
			contentLabel.AutomaticSize = Enum.AutomaticSize.Y
			contentLabel.BackgroundTransparency = 1
			contentLabel.Font = Enum.Font.FredokaOne
			contentLabel.TextSize = 12
			contentLabel.TextColor3 = Color3.fromRGB(45, 45, 45)
			contentLabel.TextXAlignment = Enum.TextXAlignment.Left
			contentLabel.TextYAlignment = Enum.TextYAlignment.Top
			contentLabel.TextWrapped = true
			contentLabel.RichText = true

			local headerPart = string.format(
				"<font color='#63815B'><b>[%s]</b></font> <font color='#447039'><b>%s:</b></font>",
				timeFormatted,
				author
			)
			contentLabel.Text = string.format("%s %s", headerPart, text)
			contentLabel.Parent = row
		end
	end

	if filteredCount > 0 then
		local spacer = Instance.new("Frame")
		spacer.Name = "BottomSpacer"
		spacer.Size = UDim2.new(1, 0, 0, 16)
		spacer.BackgroundTransparency = 1
		spacer.Visible = true
		spacer.LayoutOrder = 999999
		spacer.Parent = listScroll
	end

	statusLabel.Text = string.format("Showing %d of %d %s logs", filteredCount, #rawList, tab)
end

function LogViewerController:FetchLogs(tab: string)
	local state = windows[tab]
	if state and state.StatusLabel then
		state.StatusLabel.Text = string.format("Loading %s logs...", tab)
	end

	local LogService = Knit.GetService("LogService")
	LogService:GetLogs(tab)
		:andThen(function(logs: any)
			if typeof(logs) == "table" then
				cachedLogs[tab] = logs
				self:RenderWindow(tab)
			end
		end)
		:catch(function(err)
			warn(string.format("[LogViewerController] Failed to fetch %s logs: %s", tab, tostring(err)))
			if state and state.StatusLabel then
				state.StatusLabel.Text = string.format("Failed to load %s logs.", tab)
			end
		end)
end

local function buildWindow(self: any, tab: string): WindowState
	local config = TAB_CONFIGS[tab] or TAB_CONFIGS.Admin

	local window = Instance.new("Frame")
	window.Name = tab .. "LogsWindow"
	window.Size = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT)

	local cam = workspace.CurrentCamera
	local isSmallScreen = cam and cam.ViewportSize.X < 780
	window.Position = if isSmallScreen then config.SmallPos else config.DefaultPos

	window.BackgroundColor3 = Styles.OFFWHITE
	window.Active = true
	window.Visible = false
	window.Parent = screenGui

	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 10)
	windowCorner.Parent = window

	local windowStroke = Instance.new("UIStroke")
	windowStroke.Color = Styles.GREEN_LIGHT
	windowStroke.Thickness = 1.5
	windowStroke.Parent = window

	-- Bring to front when clicking inside window
	window.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			bringToFront(tab)
		end
	end)

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Styles.GREEN
	header.BorderSizePixel = 0
	header.Parent = window

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 10)
	headerCorner.Parent = header

	local headerPatch = Instance.new("Frame")
	headerPatch.Name = "Patch"
	headerPatch.Size = UDim2.new(1, 0, 0, 8)
	headerPatch.Position = UDim2.new(0, 0, 1, -8)
	headerPatch.BackgroundColor3 = Styles.GREEN
	headerPatch.BorderSizePixel = 0
	headerPatch.Parent = header

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(1, -70, 1, 0)
	headerTitle.Position = UDim2.fromOffset(10, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = string.format("%s %s", config.Icon, config.Title)
	headerTitle.FontFace = Styles.FONT_FREDOKA
	headerTitle.TextSize = 14
	headerTitle.TextColor3 = Styles.OFFWHITE
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = header

	-- Header Action: Refresh
	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Name = "RefreshBtn"
	refreshBtn.Size = UDim2.fromOffset(24, 24)
	refreshBtn.Position = UDim2.new(1, -58, 0.5, -12)
	refreshBtn.BackgroundColor3 = Styles.GREEN_MID
	refreshBtn.Text = "🔄"
	refreshBtn.TextColor3 = Styles.OFFWHITE
	refreshBtn.TextSize = 12
	refreshBtn.AutoButtonColor = true
	refreshBtn.Parent = header

	local refreshCorner = Instance.new("UICorner")
	refreshCorner.CornerRadius = UDim.new(0, 6)
	refreshCorner.Parent = refreshBtn

	refreshBtn.Activated:Connect(function()
		playSfx("Pop1")
		self:FetchLogs(tab)
	end)

	-- Header Action: Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.fromOffset(24, 24)
	closeBtn.Position = UDim2.new(1, -28, 0.5, -12)
	closeBtn.BackgroundColor3 = Styles.RED
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Styles.OFFWHITE
	closeBtn.FontFace = Styles.FONT_FREDOKA
	closeBtn.TextSize = 13
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.Activated:Connect(function()
		self:Close(tab)
	end)

	makeDraggable(header, window, tab)

	-- Quick launch bar: allows opening other log windows side-by-side
	local quickBar = Instance.new("Frame")
	quickBar.Name = "QuickBar"
	quickBar.Size = UDim2.new(1, -16, 0, 24)
	quickBar.Position = UDim2.fromOffset(8, 42)
	quickBar.BackgroundTransparency = 1
	quickBar.Parent = window

	local quickLayout = Instance.new("UIListLayout")
	quickLayout.FillDirection = Enum.FillDirection.Horizontal
	quickLayout.Padding = UDim.new(0, 6)
	quickLayout.Parent = quickBar

	local tabList = { "Admin", "Chat", "Join" }
	for _, otherTab in tabList do
		local otherConfig = TAB_CONFIGS[otherTab]
		local btn = Instance.new("TextButton")
		btn.Name = otherTab .. "Button"
		btn.Size = UDim2.new(0.333, -4, 1, 0)
		btn.FontFace = Styles.FONT_FREDOKA
		btn.TextSize = 11
		btn.AutoButtonColor = true
		btn.Parent = quickBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 5)
		btnCorner.Parent = btn

		if otherTab == tab then
			btn.BackgroundColor3 = Styles.GREEN_MID
			btn.TextColor3 = Styles.OFFWHITE
			btn.Text = string.format("%s %s", otherConfig.Icon, otherTab)
		else
			btn.BackgroundColor3 = Color3.fromRGB(232, 238, 230)
			btn.TextColor3 = Styles.GREEN_DEEP
			btn.Text = string.format("+ %s %s", otherConfig.Icon, otherTab)

			local btnStroke = Instance.new("UIStroke")
			btnStroke.Color = Styles.GRAY
			btnStroke.Thickness = 1
			btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			btnStroke.Parent = btn

			btn.Activated:Connect(function()
				self:Open(otherTab)
			end)
		end
	end

	-- Search Bar
	local search = Instance.new("TextBox")
	search.Name = "SearchBox"
	search.Size = UDim2.new(1, -16, 0, 28)
	search.Position = UDim2.fromOffset(8, 72)
	search.BackgroundColor3 = Color3.fromRGB(244, 246, 243)
	search.PlaceholderText = "Search by player, keyword, or action..."
	search.PlaceholderColor3 = Styles.GRAY
	search.Text = ""
	search.TextColor3 = Color3.fromRGB(40, 40, 40)
	search.FontFace = Styles.FONT_FREDOKA
	search.TextSize = 12
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.ClearTextOnFocus = false
	search.Parent = window

	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 8)
	searchPad.PaddingRight = UDim.new(0, 8)
	searchPad.Parent = search

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 6)
	searchCorner.Parent = search

	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = Styles.GRAY
	searchStroke.Thickness = 1
	searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	searchStroke.Parent = search

	-- Status label
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -16, 0, 16)
	status.Position = UDim2.fromOffset(8, 104)
	status.BackgroundTransparency = 1
	status.Text = "Loading logs..."
	status.TextColor3 = Styles.GREEN_DEEP
	status.FontFace = Styles.FONT_FREDOKA
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = window

	-- Scrolling frame for logs
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "LogList"
	scroll.Size = UDim2.new(1, -16, 1, -128)
	scroll.Position = UDim2.fromOffset(8, 122)
	scroll.BackgroundColor3 = Color3.fromRGB(248, 250, 247)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Styles.GREEN_MID
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = window

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 8)
	scrollCorner.Parent = scroll

	local scrollStroke = Instance.new("UIStroke")
	scrollStroke.Color = Styles.GREEN_LIGHT
	scrollStroke.Thickness = 1
	scrollStroke.Parent = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = scroll

	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, 5)
	scrollPadding.PaddingBottom = UDim.new(0, 5)
	scrollPadding.PaddingLeft = UDim.new(0, 5)
	scrollPadding.PaddingRight = UDim.new(0, 5)
	scrollPadding.Parent = scroll

	local state: WindowState = {
		Frame = window,
		LogList = scroll,
		StatusLabel = status,
		SearchBox = search,
		FilterQuery = "",
		Tab = tab,
		IsVisible = false,
	}

	search:GetPropertyChangedSignal("Text"):Connect(function()
		state.FilterQuery = search.Text
		self:RenderWindow(tab)
	end)

	windows[tab] = state
	return state
end

function LogViewerController:Open(rawTab: string?)
	local tab = normalizeTabName(rawTab)
	local state = windows[tab]
	if not state then
		state = buildWindow(self, tab)
	end

	state.Frame.Visible = true
	state.IsVisible = true
	bringToFront(tab)
	playSfx("Pop1")

	self:FetchLogs(tab)
end

function LogViewerController:Close(rawTab: string?)
	if rawTab then
		local tab = normalizeTabName(rawTab)
		local state = windows[tab]
		if state then
			state.Frame.Visible = false
			state.IsVisible = false
			playSfx("Pop2")
			for i = #focusHistory, 1, -1 do
				if focusHistory[i] == tab then
					table.remove(focusHistory, i)
				end
			end
		end
	else
		-- Close all open windows
		for _, state in windows do
			if state.IsVisible then
				state.Frame.Visible = false
				state.IsVisible = false
			end
		end
		focusHistory = {}
		playSfx("Pop2")
	end
end

function LogViewerController:Toggle(rawTab: string?)
	if rawTab then
		local tab = normalizeTabName(rawTab)
		local state = windows[tab]
		if state and state.IsVisible then
			self:Close(tab)
		else
			self:Open(tab)
		end
	else
		-- If any window is visible, close top or all; else open Admin
		local anyOpen = false
		for _, state in windows do
			if state.IsVisible then
				anyOpen = true
				break
			end
		end

		if anyOpen then
			self:Close()
		else
			self:Open("Admin")
		end
	end
end

---> lifecycle
function LogViewerController:KnitStart()
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("LogViewerGui")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LogViewerGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 96
	gui.Parent = playerGui
	screenGui = gui

	local LogService = Knit.GetService("LogService")
	LogService.OpenLogsSignal:Connect(function(defaultTab: string?)
		self:Open(defaultTab)
	end)

	-- Escape key closes the top-most focused log window
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.Escape then
			if #focusHistory > 0 then
				local topTab = focusHistory[#focusHistory]
				self:Close(topTab)
			end
		end
	end)
end

return LogViewerController
