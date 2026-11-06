-- Run from the repository root: lua spec/catalog_start_test.lua.
-- Reuse the host Vita mocks, then exercise the real connection/parser handoff.
dofile('spec/ui_test.lua')
local function noop() end
SCE_CTRL_SELECT = 2 ^ 10
local now = 0
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
Timer.reset = function(timer) timer.start = now end
Console = { write = noop, error = function(message) error(message) end }
Settings.SiteProfiles = false
SiteProfile, VitaSurf = nil, nil
Browser = { getCookies = function() return {} end }
Threads.insertTask = function(_, task) task.Table[task.Index] = '<html><a href="/series">Titles</a></html>' end
local calls, empty = {}, false
local function readList(mode, page, list)
	calls[#calls + 1] = { mode = mode, page = page }
	list.NoPages = true
	if not empty then
		list[1] = { ID = 'catalog-title', Name = 'Catalog title', ImageDownload = true }
	end
end
local parser = {
	ID = 'TEST', Name = 'Test source', Link = 'https://example.invalid',
	getLatestManga = function(_, page, list) readList('Latest', page, list) end,
	getPopularManga = function(_, page, list) readList('Popular', page, list) end
}
GetParserList = function() return { parser } end
Language.English.MESSAGE.NO_CATALOG_MANGA = 'No manga found'
Language.English.PANEL = { FOLLOW = 'Follow' }
Language.English.PARSERS = {}
Settings.FavouriteParsers = {}
EaseInOutCubic = function(t) return t end
dofile('source/assets/libs/parserhandler.lua')
dofile('source/assets/libs/catalogmodes.lua')
dofile('source/assets/libs/cfcheck.lua')
dofile('source/assets/libs/catalogs.lua')
local function openSource(check)
	Settings.CFCheck = check
	Catalogs.setStatus('CATALOGS')
	Panels.CATALOGS = {}
	Catalogs.update()
	Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
	local focus
	local oldFocus, oldOutline = UI.focusBorder, Graphics.fillEmptyRect
	UI.focusBorder = function(left, right, top, bottom, radius)
		focus = { left, right, top, bottom, radius }
		oldFocus(left, right, top, bottom, radius)
	end
	Graphics.fillEmptyRect = function() error('catalog must use rounded focus borders') end
	Catalogs.draw()
	UI.focusBorder, Graphics.fillEmptyRect = oldFocus, oldOutline
	assert(focus and focus[1] == 215 and focus[2] == 945 and focus[4] - focus[3] == 67 and focus[5] == 10, 'catalog cards must share the rounded focus style')
	local touch = { x = 300, y = 40 }
	Catalogs.input(0, 0, {}, touch)
	Catalogs.input(0, 0, touch, touch)
	Catalogs.input(0, 0, touch, {})
end
local function finishList()
	for _ = 1, 5 do ParserManager.update() end
end
openSource(true)
assert(CFCheck.isActive(), 'source must enter the connection check')
for _ = 1, 6 do
	now = now + 800
	CFCheck.update()
end
assert(not CFCheck.isActive(), 'successful check must open the catalog automatically')
assert(#calls == 1 and calls[1].mode == 'Latest', 'connection check must read the source list')
Catalogs.update()
-- Previously no request was made here: the zero scroll limit hid an empty catalog.
assert(#calls == 1, 'first page must be queued asynchronously')
finishList()
assert(#calls == 2 and calls[2].mode == 'Popular' and calls[2].page == 1, 'opening must request page one without scrolling')
local drawn, coverX, coverY
DrawManga = function(x, y, manga) drawn, coverX, coverY = manga, x, y end
Catalogs.draw()
assert(drawn and drawn.ID == 'catalog-title', 'connected source must render its titles')
assert(coverX == 301 and coverY == 199, 'source manga grid must share the library header and cover layout')
local openedTitle
Details.setManga = function(manga) openedTitle = manga end
local coverTouch = { x = 213, y = 100 }
Catalogs.input(0, 0, {}, coverTouch)
Catalogs.input(0, 0, coverTouch, coverTouch)
Catalogs.input(0, 0, coverTouch, {})
assert(openedTitle == drawn, 'source cover taps must match the new grid layout')
for _, mode in ipairs({'Comfortable grid', 'Cover-only', 'Compact grid'}) do
	Settings.GridDisplay = mode
	Catalogs.update()
	Catalogs.draw()
	local layout = Grid.layout()
	assert(coverX == Grid.x(1) + layout.width / 2 and coverY == 64 + layout.height / 2, 'source grid must apply ' .. mode)
end
Catalogs.update()
finishList()
assert(#calls == 2, 'completed first page must not be requested every frame')

CatalogModes.selectMode('Latest')
Catalogs.terminate()
Catalogs.update()
finishList()
assert(#calls == 3 and calls[3].mode == 'Latest' and calls[3].page == 1, 'mode change must restart at page one')

empty = true
openSource(false)
assert(not CFCheck.isActive(), 'disabled connection check must open immediately')
Catalogs.update()
finishList()
assert(#calls == 4 and calls[4].page == 1, 'unchecked source must still request its first page')
local message
Font.print = function(_, _, _, text) if text == 'No manga found' then message = text end end
Catalogs.draw()
assert(message, 'empty completed source must show a message instead of a blank screen')
print('Catalog startup checks passed: successful connection, first-page request, rendering, mode change, disabled check, empty result.')
