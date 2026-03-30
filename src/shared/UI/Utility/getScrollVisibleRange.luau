--!strict

return function(scrollingFrame: ScrollingFrame, uiGridLayout: UIGridLayout, totalSlots: number, numBufferRows: number?)
	local scrollY = scrollingFrame.CanvasPosition.Y
	local viewHeight = scrollingFrame.AbsoluteWindowSize.Y
	local containerWidth = scrollingFrame.AbsoluteSize.X
	local cellHeight = uiGridLayout.AbsoluteCellSize.Y
	local cellWidth = uiGridLayout.AbsoluteCellSize.X
	local visibleSlotBuffer = numBufferRows or 0

	local columns = math.floor(containerWidth / cellWidth)
	if columns < 1 then
		columns = 1
	end

	local totalRows = math.ceil(totalSlots / columns)

	local startRow = math.floor(scrollY / cellHeight) - visibleSlotBuffer
	local endRow = math.ceil((scrollY + viewHeight) / cellHeight) + visibleSlotBuffer

	if numBufferRows then
		startRow -= numBufferRows
		endRow += numBufferRows
	end

	startRow = math.max(1, startRow)
	endRow = math.min(totalRows, endRow)

	return (startRow - 1) * columns + 1, math.min(totalSlots, endRow * columns)
end
