-- Run from the repository root: lua spec/extra_menu_test.lua.
dofile('spec/ui_test.lua')
dofile('source/assets/libs/utils.lua')
dofile('source/assets/libs/language.lua')
local function noop() end
SCE_CTRL_START, SCE_CTRL_SELECT = 2048, 1024
local now, downloads, clears = 0, 0, 0
Timer.new = function() return { start = now } end
Timer.getTime = function(timer) return now - timer.start end
Timer.reset = function(timer) timer.start = now end
Cache = { addManga = noop, makeHistory = noop, clearBookmarks = function() clears = clears + 1 end }
ChapterSaver.check = function() return false end
ChapterSaver.is_downloading = function() return false end
ChapterSaver.downloadChapter = function() downloads = downloads + 1 end
Settings.save, GenPanels = noop, noop
local labels, focus = {}, nil
Font.print = function(_, _, _, text) labels[text] = true end
Graphics.fillEmptyRect = function() error('options menu must use rounded focus') end
local originalFocus = UI.focusBorder
UI.focusBorder = function(...)
	focus = { ... }
	return originalFocus(...)
end
dofile('source/assets/libs/extra.lua')
local function open(parser)
	Extra.setChapters({Name = 'Test manga', ParserID = parser or 'TEST'}, {{Name = 'Chapter 1'}, {Name = 'Chapter 2'}})
	now = now + 250
	Extra.update()
	Extra.draw()
end
local function tap(x, y)
	local touch = { x = x, y = y }
	Extra.input(0, 0, {}, touch)
	Extra.input(0, 0, touch, touch)
	Extra.input(0, 0, touch, {})
end
open()
assert(labels['chapter options'] and labels['test manga'], 'Start menu must have a lowercase header and manga subtitle')
tap(300, 82)
assert(Extra.getStatus() == 'START', 'tapping the menu header must not dismiss it')
Extra.input(0, SCE_CTRL_DOWN, {}, {})
Extra.draw()
assert(focus and focus[4] - focus[3] == 54 and focus[5] == 10, 'options must have compact rounded focus rows')
Extra.input(0, SCE_CTRL_CROSS, {}, {})
assert(downloads == 2, 'first option must still download all chapters')
tap(300, 460)
assert(Extra.getStatus() == 'WAIT', 'footer tap must close the menu')
now = now + 250
Extra.update(); Extra.update()
assert(Extra.getStatus() == 'END')
open()
Extra.input(0, SCE_CTRL_START, {}, {})
assert(Extra.getStatus() == 'WAIT', 'Start must still close its menu')
open('IMPORTED')
tap(300, 280)
assert(clears == 1 and Extra.doesBookmarksUpdate(), 'imported manga menu must preserve its bookmark action')
Extra.setLanguage()
now = now + 250
Extra.update()
Extra.input(0, SCE_CTRL_DOWN, {}, {})
Extra.input(0, SCE_CTRL_CROSS, {}, {})
assert(Settings.Language == 'Default', 'shared menu changes must preserve language selection')
print('Options menu checks passed: rounded rows, header taps, download action, footer/Start closing, imported actions and language picker.')
