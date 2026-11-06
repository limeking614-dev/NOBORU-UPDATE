-- Run from the repository root: lua spec/ui_test.lua (Lua 5.2+ or LuaJIT).
-- Host-side checks for layout/input agreement; actual rendering needs a Vita.
local function noop() end
local time = 0
Timer = {
	new = function() return { start = time } end,
	getTime = function(t) return time - t.start end,
	reset = function(t) t.start = time end
}
GlobalTimer = Timer.new()
Color = {
	new = function(r, g, b, a) return { r, g, b, a or 255 } end,
	getR = function(c) return c[1] end, getG = function(c) return c[2] end,
	getB = function(c) return c[3] end, getA = function(c) return c[4] end
}
function COLOR_GRADIENT(a, b, t)
	return Color.new(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
end
COLOR_BACK, COLOR_FONT = Color.new(250, 250, 250), Color.new(10, 10, 10)
COLOR_WHITE, COLOR_BLACK = Color.new(255, 255, 255), Color.new(0, 0, 0)
COLOR_SELECTED, COLOR_SUBFONT, COLOR_ROYAL_BLUE = Color.new(220, 220, 220), Color.new(128, 128, 128), Color.new(65, 105, 226)
local rectangles, covers = {}, {}
Graphics = {
	loadImage = function(path) return path end,
	drawImage = noop,
	fillRect = function(x1, x2, y1, y2, color)
		assert(x2 >= x1 and y2 >= y1, "inverted rectangle")
		rectangles[#rectangles + 1] = { x1, x2, y1, y2, color }
	end,
	fillEmptyRect = noop
}
Screen = { clear = noop }
Image = { new = function(_, image) return { e = image, Width = 24, Height = 24 } end }
StarIcon = { e = 'star' }
Font = {
	getTextWidth = function(_, text) return #tostring(text) * 8 end,
	getTextHeight = function() return 16 end, print = noop
}
function FitText(_, text) return text end
function ToLines(text) return { text } end
FONT16, FONT20, FONT26, BONT16 = 16, 20, 26, 16
MANGA_WIDTH, MANGA_HEIGHT = 180, 270
function CreateSlider() return { Y = 0, V = 0, TouchY = 0, ItemID = 0 } end
TOUCH_MODES = { NONE = 0, READ = 1, SLIDE = 2, MODE = 0 }
local names = { 'UP', 'DOWN', 'LEFT', 'RIGHT', 'CROSS', 'CIRCLE', 'SQUARE', 'TRIANGLE', 'LTRIGGER', 'RTRIGGER' }
for i, name in ipairs(names) do _G['SCE_CTRL_' .. name] = 2 ^ (i - 1) end
Controls = {
	check = function(pad, mask)
		for i = 0, 15 do
			local bit = 2 ^ i
			if pad % (bit * 2) >= bit and mask % (bit * 2) >= bit then return true end
		end
		return false
	end,
	readLeftAnalog = function() return 127, 127 end
}
Settings = { Theme = 'Light', Language = 'English', KeyType = 'EU' }
Language = { English = {
	APP = { LIBRARY = 'Library', CATALOGS = 'Catalogs', HISTORY = 'History', IMPORT = 'Import', DOWNLOAD = 'Downloads', SETTINGS = 'Settings' },
	MESSAGE = { NO_LIBRARY_MANGA = 'Your library is empty' }
} }
Themes = { Light = { COLOR_SUBFONT = COLOR_SUBFONT, COLOR_SELECTOR = COLOR_ROYAL_BLUE } }
System = setmetatable({}, { __index = function() return noop end })
local opened
Details = { getStatus = function() return 'END' end, getFade = function() return 0 end,
	setManga = function(manga) opened = manga end, update = noop, draw = noop }
CatalogModes = { getStatus = function() return 'END' end, update = noop, draw = noop }
Extra = { getStatus = function() return 'END' end }
ChapterSaver = { is_download_running = function() return false end }
ParserManager = { check = function() return false end, remove = noop }
Threads = { check = function() return false end, remove = noop }
Loading = { setStatus = noop }
Keyboard = { getState = function() return 0 end }
RUNNING = 1
Panel = { set = noop }
local library = {}
Database = { getMangaList = function() return library end }
function DrawManga(x, y, manga) covers[manga.ID] = { x = x, y = y } end

dofile('source/assets/libs/ui.lua')
-- Equal elapsed time must produce equal motion across refresh rates.
local function approachAt(dt, count)
	UI.dt = dt
	local value = 0
	for _ = 1, count do value = UI.approach(value, 100, 90) end
	return value
end
assert(math.abs(approachAt(1000 / 60, 12) - approachAt(1000 / 30, 6)) < 0.0001)
time = 1000
UI.update()
assert(UI.dt == 50, 'resume delta must be bounded')
UI.dt = 1000 / 60

dofile('source/assets/libs/selector.lua')
dofile('source/assets/libs/grid.lua')
dofile('source/assets/libs/catalogs.lua')
for i = 1, 12 do library[i] = { ID = i, Name = 'Manga ' .. i, ImageDownload = true, Counter = i } end
Catalogs.setStatus('LIBRARY')
Catalogs.update()
Catalogs.update()
Catalogs.draw()
assert(covers[1].x == 301 and covers[1].y == 199, 'first cover must start at 211,64')
assert(covers[4].x == 859, 'four-column layout must stay inside the viewport')
Catalogs.input(0, SCE_CTRL_DOWN, {}, {})
local function focusAlpha(at)
	time, rectangles = at, {}
	Catalogs.draw()
	for _, rect in ipairs(rectangles) do
		local color = rect[5]
		local accent = UI.color('SELECTOR')
		if rect[1] == 218 and rect[2] == 384 and rect[3] == 64 and color and color[1] == Color.getR(accent) and color[2] == Color.getG(accent) then return color[4] end
	end
	error('selected cover must draw a rounded focus border')
end
assert(focusAlpha(0) == 165 and focusAlpha(900) == 255, 'focus glow must pulse with elapsed time')
assert(focusAlpha(1800) == 165, 'focus glow must loop smoothly')
time = 1000
local function tap(x, y)
	local touch = { x = x, y = y }
	Catalogs.input(0, 0, {}, touch)
	Catalogs.input(0, 0, touch, touch)
	Catalogs.input(0, 0, touch, {})
end
tap(213, 100)
assert(opened == library[1], 'left edge of first cover must be tappable')
opened = nil
tap(300, 40)
assert(opened == nil, 'fixed header must not open a cover')
tap(940, 100)
assert(opened == library[4], 'rightmost cover must have matching touch geometry')
-- A large fling must stop with the final row aligned to the footer.
Catalogs.input(0, 0, { x = 300, y = 400 }, { x = 300, y = 400 })
Catalogs.input(0, 0, { x = 300, y = 400 }, { x = 300, y = -1000 })
Catalogs.input(0, 0, { x = 300, y = -1000 }, {})
Catalogs.update()
Catalogs.draw()
assert(covers[12].y + MANGA_HEIGHT / 2 == 524, 'scroll limit must reveal final cover')
opened = nil
tap(940, 510)
assert(opened == library[12], 'scrolled last cover must be tappable')
-- Compare real library inertia over the same elapsed time at 30 and 60 fps.
local function flingAt(dt, steps)
	Catalogs.setStatus('LIBRARY')
	Catalogs.update()
	UI.dt = 1000 / 60
	Catalogs.input(0, 0, { x = 300, y = 400 }, { x = 300, y = 400 })
	Catalogs.input(0, 0, { x = 300, y = 400 }, { x = 300, y = 390 })
	Catalogs.input(0, 0, { x = 300, y = 390 }, {})
	UI.dt = dt
	for _ = 1, steps do Catalogs.update() end
	Catalogs.draw()
	return covers[1].y
end
assert(math.abs(flingAt(1000 / 60, 12) - flingAt(1000 / 30, 6)) < 0.001, 'inertia must preserve travel across refresh rates')
UI.dt = 1000 / 60
library = {}
Catalogs.update()
Catalogs.update()
Catalogs.draw()

-- Isolate navigation from catalog/network side effects.
local realCatalogs = Catalogs
local selected
Catalogs = { setStatus = function(mode) selected = mode end, input = noop, update = noop, draw = noop }
dofile('source/assets/libs/menu.lua')
Menu.setMode('LIBRARY')
Menu.input(0, 0, {}, { x = 30, y = 30 })
assert(selected == 'LIBRARY', 'logo tap must not switch sections')
Menu.input(0, 0, {}, { x = 30, y = 200 })
assert(selected == 'HISTORY')
Menu.input(0, SCE_CTRL_RTRIGGER, {}, {})
assert(selected == 'PCSOURCES')
Menu.input(0, 0, {}, { x = 30, y = 490 })
assert(selected == 'SETTINGS')
Menu.update()
local function highlightY()
	rectangles = {}
	Menu.draw()
	for _, r in ipairs(rectangles) do if r[1] == 10 and r[2] == 13 then return r[3] end end
end
assert(highlightY() == highlightY(), 'drawing must not advance animations')
Menu.setMode('LIBRARY')
for _ = 1, 60 do Menu.update() end
assert(math.abs(highlightY() - 100) < 0.1, 'highlight must settle on the selected section')
local function checkSidebarAlignment()
	local icons, labels = {}, {}
	local oldImage, oldPrint = Graphics.drawImage, Font.print
	Graphics.drawImage = function(x, y, image) icons[image] = { x = x, y = y } end
	Font.print = function(_, x, y, label) labels[label] = { x = x, y = y } end
	Menu.draw()
	Graphics.drawImage, Font.print = oldImage, oldPrint
	local icon = icons['app0:assets/icons/star.png']
	local label = labels.Library
	assert(math.abs(label.x - icon.x - 36) < 0.001, 'icon and label must move together')
	assert(icon.y + 12 == label.y + 8, 'icon and label must share a vertical center')
end
checkSidebarAlignment()
Menu.setMode('HISTORY')
Menu.update()
checkSidebarAlignment()
Catalogs = realCatalogs
MENU, READER, AppMode = 0, 1, 0
dofile('source/assets/libs/panel.lua')
Panel.show()
for _ = 1, 60 do Panel.update() end
Panel.draw()
Panel.hide()
for _ = 1, 60 do Panel.update() end
rectangles = {}
Panel.draw()
assert(#rectangles == 0, 'hidden footer must stop drawing')
print('UI checks passed: timing, cover taps, header exclusion, scroll bounds, empty library, section navigation, footer.')
