-- Run from the repository root: lua spec/grid_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
local entries, tiles, opened = {}, {}, nil
local titleInHeader = false
Font.print = function(_, _, _, text)
	if tostring(text):match('^Manga %d+$') then titleInHeader = true end
end
for i = 1, 12 do entries[i] = { ID = i, Name = 'Manga ' .. i, Counter = 2, ImageDownload = true } end
Database.getMangaList = function() return entries end
Cache = { getHistory = function() return entries end }
Details.setManga = function(manga) opened = manga end
DrawManga = function(x, y, manga, width, height, coverOnly, titlesBelow)
	tiles[manga.ID] = { x = x, y = y, width = width, height = height, coverOnly = coverOnly, titlesBelow = titlesBelow }
end
local function tap(x, y)
	local touch = { x = x, y = y }
	Catalogs.input(0, 0, {}, touch)
	Catalogs.input(0, 0, touch, touch)
	Catalogs.input(0, 0, touch, {})
end
for _, mode in ipairs({'Compact grid', 'Comfortable grid', 'Cover-only'}) do
	for _, columns in ipairs({3, 4, 5}) do
	Settings.GridColumns = columns
	for _, status in ipairs({'LIBRARY', 'HISTORY'}) do
		Settings.GridDisplay = mode
		Catalogs.setStatus(status)
		Catalogs.update()
		Catalogs.update()
		tiles, opened = {}, nil
		Catalogs.draw()
		local layout = Grid.layout()
		assert(tiles[1].width == layout.width and tiles[1].height == layout.height)
		assert(tiles[1].x - layout.width / 2 == layout.left)
		assert(tiles[layout.columns].x + layout.width / 2 <= 952, 'last column must fit')
		assert(tiles[1].coverOnly == layout.coverOnly)
		assert(layout.columns == columns and tiles[1].titlesBelow == (mode == 'Comfortable grid'), 'style and column count must be independent')
		tap(300, 40)
		assert(not opened, 'header must not activate a cover')
		tap(layout.left + 2, 100)
		assert(opened == entries[1], 'touch target must match ' .. mode)
		if layout.titlesBelow then
			opened = nil
			tap(layout.left + 2, 64 + layout.height + 10)
			assert(opened == entries[1], 'caption must activate its own cover')
		end
		Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
		Catalogs.input(SCE_CTRL_DOWN, 0, {}, {})
		Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
		Catalogs.input(0, SCE_CTRL_CROSS, {}, {})
		assert(opened == entries[1 + layout.columns], 'D-pad must use the active column count')
		titleInHeader = false
		Catalogs.draw()
		assert(not titleInHeader, 'cover-only must not reveal a focused manga title in the header')
		Catalogs.input(0, 0, {x = 300, y = 400}, {x = 300, y = 400})
		Catalogs.input(0, 0, {x = 300, y = 400}, {x = 300, y = -5000})
		Catalogs.input(0, 0, {x = 300, y = -5000}, {})
		Catalogs.update()
		Catalogs.draw()
		assert(tiles[12].y + layout.height / 2 + layout.itemHeight - layout.height == 524, 'scroll limit must reveal final row including captions')
	end
	end
end
-- Exercise the actual cover renderer without needing the Vita-only globals setup.
local file = assert(io.open('source/assets/libs/globals.lua', 'r'))
local source = file:read('*a'); file:close()
local renderer = assert(source:match('(local function drawMangaName.-)function DrawDetailsManga'))
local gradients, titles, covers = 0, 0, 0
LUA_GRADIENT = { e = 'gradient' }
isCJK = function() return false end
Graphics.drawScaleImage = function() gradients = gradients + 1 end
Font.print = function() titles = titles + 1 end
DrawDetailsManga = function() covers = covers + 1 end
assert(load(renderer))()
local manga = { Name = 'Sample title' }
DrawManga(340, 229, manga, 220, 330, false)
assert(covers == 1 and gradients == 1 and titles > 0 and manga.PrintNameWidth == 220)
assert(manga.PrintName.f == nil and manga.PrintName.s == 'Sample title', 'short titles must stay on one line')
DrawManga(301, 199, manga, 180, 270, false)
assert(manga.PrintNameWidth == 180, 'title cache must reflow when tile width changes')
local oldTitles, oldGradients = titles, gradients
DrawManga(301, 199, manga, 180, 270, true)
assert(covers == 3 and titles == oldTitles and gradients == oldGradients, 'cover-only must hide title and gradient overlays')
local captionLines = {}
Font.print = function(_, _, y, text)
	captionLines[#captionLines + 1] = { y = y, text = text }
end
local long = { Name = ('A longer title with many words '):rep(8) }
local before = gradients
DrawManga(301, 199, long, 180, 270, false, true)
assert(gradients == before and #captionLines == 2, 'comfortable mode must put at most two lines below the cover without a gradient')
for _, line in ipairs(captionLines) do
	assert(line.y > 334 and line.y < 382, 'caption must be below the card within reserved space')
	assert(Font.getTextWidth(BONT16, line.text) <= 164, 'caption must fit the card width')
end
assert(captionLines[2].text:match('…$'), 'overflowing titles must end with an ellipsis')
print('Grid checks passed: all layouts, Library/History geometry, touch, D-pad columns, scroll bounds, title reflow and cover-only rendering.')
