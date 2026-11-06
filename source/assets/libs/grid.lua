-- One geometry shared by drawing, touch targets, navigation and cover loading.
Grid = {}
local layouts = {}
local sizes = {
	[3] = {width = 220, gap = 20, left = 230},
	[4] = {width = 180, gap = 6, left = 211},
	[5] = {width = 140, gap = 8, left = 214}
}
for _, style in ipairs({"Compact grid", "Comfortable grid", "Cover-only"}) do
	layouts[style] = {}
	for columns, size in pairs(sizes) do
		local caption = style == "Comfortable grid" and 48 or 0
		local height = size.width * 1.5
		layouts[style][columns] = { columns = columns, width = size.width, height = height,
			gap = size.gap, left = size.left, coverOnly = style == "Cover-only",
			titlesBelow = style == "Comfortable grid", itemHeight = height + caption,
			stride = height + caption + size.gap }
	end
end

function Grid.layout()
	local style = layouts[Settings.GridDisplay] or layouts["Compact grid"]
	return style[Settings.GridColumns] or style[4]
end

function Grid.x(index)
	local layout = Grid.layout()
	return layout.left + ((index - 1) % layout.columns) * (layout.width + layout.gap)
end

function Grid.first(offset)
	local layout = Grid.layout()
	return math.max(1, math.floor(offset / layout.stride) * layout.columns + 1)
end

function Grid.capacity()
	local layout = Grid.layout()
	return layout.columns * (math.ceil(460 / layout.stride) + 1)
end
