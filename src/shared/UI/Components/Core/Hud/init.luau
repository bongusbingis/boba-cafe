local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)

local LocalPlayer = Players.LocalPlayer

---> components
local Pane = require(UI.Components.Pane)
local usePx = require(UI.Hooks.usePx)
local TopBar = require(script.TopBar)
local BottomLeft = require(script.BottomLeft)
local OrderTicket = require(script.OrderTicket)
local ShiftCard = require(script.ShiftCard)
local QuestCard = require(script.QuestCard)
local LevelUpCelebration = require(script.LevelUpCelebration)
local PaycheckCard = require(script.PaycheckCard)
local EventIntro = require(script.EventIntro)

---> private
local c = React.createElement

local TICKET_WIDTH = 220
local TICKET_SCALE = 1.6 -- Jack Q27 A (DEC-052): ticket size only

return function(props: {
	CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
	local px = usePx()
	local ticketScale = px.scale(TICKET_SCALE)

	-- Quests is a closed-by-default pop-up card, not a page (DEC-048).
	local questsOpen, setQuestsOpen = React.useState(false)
	local questsCloseRef = React.useRef(nil)
	local questsOpenRef = React.useRef(false)
	questsOpenRef.current = questsOpen

	local closeQuests = React.useCallback(function()
		setQuestsOpen(false)
	end, {})

	-- Shop / Inventory / Menu and the card are never stacked.
	React.useEffect(function()
		if props.CurrentPage ~= nil and questsOpenRef.current then
			if questsCloseRef.current then
				questsCloseRef.current()
			else
				setQuestsOpen(false)
			end
		end
	end, { props.CurrentPage })

	local questsFirstShiftOpened = React.useRef(false)
	React.useEffect(function()
		if not RunService:IsRunning() then
			return nil
		end
		local conn = Knit.GetService("ShiftService").ShiftEnded:Connect(function(summary)
			if summary and summary.First == true and not questsFirstShiftOpened.current then
				questsFirstShiftOpened.current = true
				task.spawn(function()
					task.wait((summary.Seconds or 8) + 2)
					local waited = 0
					while LocalPlayer and LocalPlayer:GetAttribute("NicknamePending") == true and waited < 30 do
						task.wait(0.5)
						waited += 0.5
					end
					setQuestsOpen(true)
				end)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	return c(Pane, {
		Native = {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		},
	}, {
		TopBar = c(TopBar, {
			CurrentPage = props.CurrentPage,
			SetCurrentPage = props.SetCurrentPage,
		}),

		BottomLeft = c(BottomLeft, {
			CurrentPage = props.CurrentPage,
			SetCurrentPage = props.SetCurrentPage,
		}),

		-- No HUD Quests button (DEC-057); quests open from the Menu's Quests tab, which carries the claim dot.

		-- Ticket column, middle right. Bottom edge is fixed, so it grows upward as tickets are added.
		TicketColumn = c("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.99, 0.65),
			Size = UDim2.fromOffset(math.ceil(TICKET_WIDTH * ticketScale), 0),
			ZIndex = 10,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			TicketStack = c(Pane, {
				AutomaticSize = Enum.AutomaticSize.Y,
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 10),
				},
				Scale = ticketScale,
				Native = {
					LayoutOrder = 1,
					Size = UDim2.fromOffset(TICKET_WIDTH, 0),
					ZIndex = 10,
				},
			}, {
				OrderTicket = c(
					OrderTicket,
					{ stacked = true, slot = 1, layoutOrder = 1, SetCurrentPage = props.SetCurrentPage }
				),
				OrderTicket2 = c(
					OrderTicket,
					{ stacked = true, slot = 2, layoutOrder = 2, SetCurrentPage = props.SetCurrentPage }
				),
			}),
		}),
		ShiftCard = c(ShiftCard, {}),

		-- Always mounted; renders only while a Rush Hour / Boba Party intro plays (EVENT-FX).
		EventIntro = c(EventIntro, {}),

		-- Last sibling, ZIndex 20 on its single outer Frame (above TicketStack 10).
		QuestPopup = if questsOpen then c(QuestCard, { OnClose = closeQuests, CloseRef = questsCloseRef }) else nil,

		-- Always mounted; renders only while a level-up payload is active.
		LevelUp = c(LevelUpCelebration, {}),

		-- Always mounted; renders only while a paycheck payload is active.
		Paycheck = c(PaycheckCard, {}),
	})
end
