-- Run from the repository root: lua spec/remaining_pages_test.lua.
dofile('spec/pages_ui_test.lua')
SCE_CTRL_SELECT = 2 ^ 10
local realDofile = dofile
System.doesFileExist = function(path) return path == 'ux0:data/noboru/pcsources.lua' end
dofile = function(path)
	if path == 'ux0:data/noboru/pcsources.lua' then return { { Site = 'example.invalid', Count = 3 } } end
	return realDofile(path)
end
realDofile('source/assets/libs/catalogs.lua')
local focused, labels = nil, {}
local oldFocus = UI.focusBorder
UI.focusBorder = function(...)
	focused = { ... }
	return oldFocus(...)
end
Font.print = function(_, _, _, text) labels[tostring(text)] = true end
local tasks = {
	{ MangaName = 'Active', ChapterName = 'Chapter 1', page = 12, page_count = 10 },
	{ MangaName = 'Queued', ChapterName = 'Chapter 2' },
	{ MangaName = 'Saved', ChapterName = 'Chapter 3', Saved = true }
}
local cancelled, opened
ChapterSaver.getDownloadingList = function() return tasks end
ChapterSaver.openSaved = function(task) opened = task end
ChapterSaver.stopByListItem = function(task) cancelled = task end
Panels.DOWNLOAD = {}
Catalogs.setStatus('DOWNLOAD')
Catalogs.update()
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.draw()
assert(focused and focused[4] - focused[3] == 67 and focused[5] == 10, 'downloads must use rounded focus')
assert(labels['12/10'] and labels.Queued and labels.Downloaded, 'progress, queued and saved labels must render')
local function tap(x, y)
	local touch = { x = x, y = y }
	Catalogs.input(0, 0, {}, touch)
	Catalogs.input(0, 0, touch, touch)
	Catalogs.input(0, 0, touch, {})
end
tap(300, 40)
assert(cancelled == tasks[1], 'active download must retain cancel action')
tap(300, 190)
assert(opened == tasks[3], 'saved chapter must retain open action')
tasks = {}
Catalogs.update()
Catalogs.draw()
Panels.PCSOURCES = {}
Catalogs.setStatus('PCSOURCES')
Catalogs.update()
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.draw()
assert(focused[4] - focused[3] == 67 and labels['example.invalid'], 'PC sources must render saved sources with rounded focus')
local source
local parser = { ID = 'PC-TEST', Name = 'PC source' }
GetParserForHost = function(host) assert(host == 'example.invalid'); return parser end
CFCheck = nil
CatalogModes.load = function(value) source = value end
CatalogModes.selectMode = function(mode) assert(mode == 'Latest') end
tap(300, 40)
assert(source == parser, 'PC source cards must still open their site')
dofile = realDofile
print('Remaining page checks passed: downloads progress bounds, queued/saved labels, cancel/open actions, PC source styling and navigation.')
