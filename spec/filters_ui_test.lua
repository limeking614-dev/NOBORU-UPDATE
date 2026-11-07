-- Run from the repository root: lua spec/filters_ui_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
dofile('source/assets/libs/language.lua')
local function noop() end
local now, keyboardState, query, reloads = 0, 0, '', 0
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
Timer.reset = function(timer) timer.start = now end
FINISHED, RUNNING = 2, 1
Keyboard = {
	getState = function() return keyboardState end,
	show = function() keyboardState = RUNNING end,
	getInput = function() return query end,
	clear = function() keyboardState = 0 end
}
Console, Notifications = {write = noop}, {push = noop}
local labels, focus = {}, nil
Font.print = function(_, x, y, text) labels[text] = {x = x, y = y} end
Graphics.fillEmptyRect = function() error('filters must use rounded focus borders') end
local originalFocus = UI.focusBorder
UI.focusBorder = function(...)
	focus = { ... }
	return originalFocus(...)
end
Catalogs.terminate = function() reloads = reloads + 1 end
EaseInOutCubic = function(t) return t end
dofile('source/assets/libs/catalogmodes.lua')
local function settle()
	for _ = 1, 30 do now = now + 17; CatalogModes.update() end
	labels = {}
	CatalogModes.draw()
end
local function open(filters, options)
	local parser = {ID = 'TEST', Name = 'Test source', getPopularManga = noop, Filters = filters or {}}
	for key, value in pairs(options or {}) do parser[key] = value end
	CatalogModes.load(parser)
	CatalogModes.show()
	CatalogModes.update()
	CatalogModes.draw() -- exercise the first animation frame too
	settle()
end
local function tap(x, y)
	local touch = {x = x, y = y}
	CatalogModes.input(0, 0, touch, {})
	CatalogModes.input(0, 0, touch, touch)
	CatalogModes.input(0, 0, {}, touch)
	settle()
end
local function key(button)
	CatalogModes.input(button, 0, {}, {})
	CatalogModes.input(0, button, {}, {})
	settle()
end
open({{Name = 'Genres', Type = 'checkcross', Tags = {'Action', 'Drama'}}})
assert(labels.Filters and labels['Test source'], 'panel must show the filters heading and source')
assert(focus and focus[5] == 9, 'panel must share the rounded pulsing focus')
tap(650, 40)
assert(CatalogModes.getStatus() == 'START', 'header taps must not activate or dismiss filters')
tap(650, 163) -- Genres group after Popular
assert(labels.Action and labels.Drama, 'group must expand')
tap(670, 213)
assert(CatalogModes.getTagsData().Genres.include[1] == 'Action', 'tag must cycle to included')
tap(670, 213)
assert(CatalogModes.getTagsData().Genres.exclude[1] == 'Action', 'tag must cycle to excluded')
tap(670, 213)
assert(#CatalogModes.getTagsData().Genres.include == 0 and #CatalogModes.getTagsData().Genres.exclude == 0, 'tag must cycle back to neutral')
open({{Name = 'Format', Type = 'radio', Tags = {'All', 'Complete'}}})
tap(650, 163); tap(670, 263)
assert(CatalogModes.getTagsData().Format == 'Complete', 'radio choice must update')
open({{Name = 'Availability', Type = 'check', Tags = {'Downloaded'}}})
tap(650, 163); tap(670, 213)
assert(CatalogModes.getTagsData().Availability[1] == 'Downloaded', 'checkbox must update')
open({}, {getLetterManga = noop, Letters = {'A', 'B'}, getTagManga = noop, Tags = {'Action', 'Drama'}})
key(SCE_CTRL_DOWN); key(SCE_CTRL_RIGHT); key(SCE_CTRL_CROSS)
assert(CatalogModes.getMangaMode() == 'ByLetter' and CatalogModes.getLetter() == 'B', 'letter navigation must keep its selected value')
CatalogModes.show(); settle()
key(SCE_CTRL_DOWN); key(SCE_CTRL_RIGHT); key(SCE_CTRL_CROSS)
assert(CatalogModes.getMangaMode() == 'ByTag' and CatalogModes.getTag() == 'Drama', 'tag navigation must keep its selected value')
open({}, {searchManga = noop})
key(SCE_CTRL_DOWN); key(SCE_CTRL_CROSS)
assert(keyboardState == RUNNING, 'search must open the keyboard')
query, keyboardState = 'one piece', FINISHED
CatalogModes.update()
assert(CatalogModes.getMangaMode() == 'Search' and CatalogModes.getSearchData() == query, 'search must hand its text to the catalog')
local tags = {}
for i = 1, 30 do tags[i] = 'Tag' .. i end
open({{Name = 'Long group', Type = 'check', Tags = tags}})
tap(650, 163)
CatalogModes.input(0, 0, {x = 680, y = 450}, {})
CatalogModes.input(0, 0, {x = 680, y = 100}, {x = 680, y = 450})
CatalogModes.input(0, 0, {}, {x = 680, y = 100})
settle()
assert(labels.Tag30 and labels.Tag30.y < 504, 'last tag must be reachable without leaving the content viewport')
tap(680, labels.Tag30.y + 8)
assert(CatalogModes.getTagsData()['Long group'][1] == 'Tag30', 'scrolled touch targets must match their rows')
key(SCE_CTRL_SQUARE)
assert(CatalogModes.getStatus() == 'END', 'Square must close the panel')
open()
tap(400, 200)
assert(CatalogModes.getStatus() == 'END', 'outside tap must close the panel')
assert(Language.English.PANEL.MODE == 'filters' and Language.English.PANEL.FILTERS == 'filters', 'legacy Mode label must be renamed')
print('Filters checks passed: styling, expansion, checkbox/radio/include-exclude choices, letters/tags, search, scrolling and dismissal.')
