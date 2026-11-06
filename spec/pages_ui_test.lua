-- Run from the repository root: lua spec/pages_ui_test.lua.
dofile('spec/ui_test.lua')
local function noop() end
dofile('source/assets/libs/language.lua')
local focus, opened, imported, navigated
local originalFocus = UI.focusBorder
UI.focusBorder = function(left, right, top, bottom, radius)
	focus = { left, right, top, bottom, radius }
	return originalFocus(left, right, top, bottom, radius)
end
Graphics.fillEmptyRect = function() error('updated pages must use rounded focus borders') end
Details.setManga = function(manga) opened = manga end
local history = {}
for i = 1, 12 do history[i] = { ID = i, Name = 'History ' .. i, ImageDownload = true } end
Cache = { getHistory = function() return history end }
local tiles = {}
DrawManga = function(x, y, manga) tiles[manga.ID] = { x, y } end
Catalogs.setStatus('HISTORY')
Catalogs.update()
Catalogs.update()
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.draw()
assert(tiles[1][1] == 301 and tiles[1][2] == 199, 'history must share the library header and cover geometry')
assert(focus and focus[5] == 10, 'history must use rounded focus')
local function tap(x, y)
	local touch = { x = x, y = y }
	Catalogs.input(0, 0, {}, touch)
	Catalogs.input(0, 0, touch, touch)
	Catalogs.input(0, 0, touch, {})
end
tap(300, 40)
assert(not opened, 'history header must not open a manga')
tap(213, 100)
assert(opened == history[1], 'history cover touch targets must match their new position')
local files = {
	{ name = 'Folder', active = true, directory = true },
	{ name = 'Book.cbz', active = true },
	{ name = 'Unsupported.txt', active = false },
	{ name = '...', active = true, directory = true }
}
Import = {
	listDir = function() return files end,
	canImport = function(item) return item.active and item.name ~= '...' end,
	canBack = function() return true end,
	getPath = function(item) return 'import/' .. item.name end,
	go = function(item) navigated = item end
}
ChapterSaver.importManga = function(path) imported = path end
Catalogs.setStatus('IMPORT')
Panels.IMPORT = {}
Catalogs.update()
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.draw()
assert(focus[4] - focus[3] == 67 and focus[5] == 10, 'import must use rounded source-style cards')
tap(300, 40)
assert(navigated == files[1], 'import name area must keep directory navigation')
tap(900, 40)
assert(imported == 'import/Folder', 'import action area must keep the import shortcut')
local settingsList = { 'Controls', 'FastImages', 'Translators' }
Settings.list = function() return settingsList end
local tab = 'Main'
Settings.getTab = function() return tab end
Settings.inTab = function() return false end
Settings.isTab = function(task) return task == 'Controls' end
Settings.setTab = function(value) tab = value end
Catalogs.setStatus('SETTINGS')
Panels.SETTINGS = {}
Catalogs.update()
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.draw()
assert(focus[4] - focus[3] == 71 and focus[5] == 10, 'settings must keep enough space for three lines')
tap(300, 40)
assert(tab == 'Controls', 'settings cards must keep submenu navigation')
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.input(SCE_CTRL_DOWN, 0, {}, {})
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.input(SCE_CTRL_DOWN, 0, {}, {})
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
Catalogs.draw()
assert(focus[4] - focus[3] == 216, 'translator focus must include the full credits card')
print('Page checks passed: history geometry and taps, rounded focus, import navigation and shortcut, settings submenu and credits.')
