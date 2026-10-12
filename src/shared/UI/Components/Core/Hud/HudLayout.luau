--[[
    Module: HudLayout
    Description: Shared geometry for the bottom-left and bottom-right HUD columns.

    The two columns are visual mirrors of each other, but they are built differently:
    BottomLeft is a horizontal ButtonRow (currency panel + capsule) that also has to grow
    vertically when a notification springs in, so it relies on AutomaticSize.Y; BottomRight
    is a plain vertical stack. Because the structures differ, the values that make them
    look symmetrical are easy to let drift apart — so they live here rather than being
    written out twice.

    All pixel values are pre-scale: pass them through usePx at the call site.
--]]

local HudLayout = {}

--- Width of each column, as a fraction of screen width. Both sides must match or the
--- buttons end up different sizes, since NormalButton derives its height from its width
--- via a 7:1 aspect ratio.
HudLayout.COLUMN_WIDTH = 0.3

--- Horizontal inset from the screen edge, in pre-scale pixels. Applied as +x on the left
--- and -x on the right.
HudLayout.EDGE_INSET = 10

--- Distance from the bottom of the screen, as a scale.
HudLayout.BOTTOM_ANCHOR = 0.985

--- Height of a row of buttons, in pre-scale pixels.
HudLayout.ROW_HEIGHT = 60

--- Gap between stacked entries, in pre-scale pixels.
HudLayout.STACK_PADDING = 7

--- Size for a NormalButton inside a fixed-height row (BottomLeft): half the row.
HudLayout.ROW_BUTTON_SIZE = UDim2.fromScale(1, 0.5)

--- Height of a single stacked button, in pre-scale pixels. Half of ROW_HEIGHT so the
--- right column's buttons match the left column's.
---
--- This has to be an explicit height, not a scale of 0 relying on NormalButton's 7:1
--- UIAspectRatioConstraint: the parent uses AutomaticSize.Y, which measures children
--- before the constraint resolves, sees zero-height children, and collapses the whole
--- column. Build it at the call site with usePx.
HudLayout.BUTTON_HEIGHT = HudLayout.ROW_HEIGHT * 0.5

---> quest panel

--- Geometry for the expandable quest panel above the bottom-right buttons. All
--- pre-scale pixels. Fixed rather than content-driven so BottomRight can compute an
--- exact column height (see the aspect-ratio note above).
HudLayout.QUEST_SLOT_HEIGHT = 46
HudLayout.QUEST_SLOT_PADDING = 5
HudLayout.QUEST_HEADER_HEIGHT = 20
HudLayout.QUEST_FOOTER_HEIGHT = 16

--- Number of quest slots the panel draws. Kept here so the height maths and the panel
--- agree; QuestConfig.SLOTS is the source of truth for how many are assigned.
HudLayout.QUEST_SLOT_COUNT = 4

--- Total pre-scale height of the quest panel, including its own padding.
function HudLayout.questPanelHeight(): number
	local slots = HudLayout.QUEST_SLOT_COUNT
		* (HudLayout.QUEST_SLOT_HEIGHT + HudLayout.QUEST_SLOT_PADDING)

	return HudLayout.QUEST_HEADER_HEIGHT + 4 + slots + HudLayout.QUEST_FOOTER_HEIGHT + 12
end

--- Total pre-scale height needed to stack `count` buttons with padding between them.
--- BottomRight uses this instead of AutomaticSize: it has a fixed set of buttons, so an
--- explicit height is deterministic and cannot be collapsed by the aspect-ratio
--- interaction described above. BottomLeft still needs AutomaticSize because a
--- notification card can appear above its row.
function HudLayout.stackHeight(count: number): number
	if count <= 0 then
		return 0
	end
	return (count * HudLayout.BUTTON_HEIGHT) + ((count - 1) * HudLayout.STACK_PADDING)
end

return HudLayout
